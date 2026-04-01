use std::future::Future;
use std::net::SocketAddr;
use std::pin::Pin;
use std::sync::Arc;
use std::task::{Context, Poll};

use bytes::Bytes;
use hickory_proto::op::Message;
use http_body_util::{BodyExt, Full};
use hyper::Request;
use hyper::Uri;
use hyper_rustls::HttpsConnectorBuilder;
use hyper_util::client::legacy::connect::HttpConnector;
use hyper_util::client::legacy::Client;
use hyper_util::rt::TokioExecutor;
use tower_service::Service;
use tracing::{debug, error};

use crate::cache::DnsCache;
use crate::config::Config;

/// A custom HTTP connector that resolves the DoH hostname using bootstrap IPs
/// instead of the system DNS resolver (avoids chicken-and-egg problem).
#[derive(Clone)]
struct BootstrapConnector {
    inner: HttpConnector,
    /// (hostname, list of bootstrap IPs)
    bootstrap_host: String,
    bootstrap_addrs: Vec<SocketAddr>,
}

impl Service<Uri> for BootstrapConnector {
    type Response = <HttpConnector as Service<Uri>>::Response;
    type Error = <HttpConnector as Service<Uri>>::Error;
    type Future = Pin<Box<dyn Future<Output = Result<Self::Response, Self::Error>> + Send>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, uri: Uri) -> Self::Future {
        // If the URI host matches our DoH server, rewrite to use a bootstrap IP
        let host = uri.host().unwrap_or("").to_string();
        if host == self.bootstrap_host && !self.bootstrap_addrs.is_empty() {
            // Pick the first bootstrap address
            let bootstrap = self.bootstrap_addrs[0];
            let new_uri = Uri::builder()
                .scheme("http") // TLS is handled by the outer HTTPS layer
                .authority(format!("{}:{}", bootstrap.ip(), bootstrap.port()))
                .path_and_query(uri.path_and_query().map(|pq| pq.as_str()).unwrap_or("/"))
                .build();

            match new_uri {
                Ok(u) => {
                    debug!(original = %uri, rewritten = %u, "Bootstrap DNS resolution");
                    Box::pin(self.inner.call(u))
                }
                Err(_) => Box::pin(self.inner.call(uri)),
            }
        } else {
            Box::pin(self.inner.call(uri))
        }
    }
}

pub struct DohClient {
    url: String,
    client: Client<hyper_rustls::HttpsConnector<BootstrapConnector>, Full<Bytes>>,
    cache: Arc<DnsCache>,
}

impl DohClient {
    pub fn new(config: &Config, cache: Arc<DnsCache>) -> Self {
        let tls = rustls::ClientConfig::builder()
            .with_root_certificates(rustls::RootCertStore {
                roots: webpki_roots::TLS_SERVER_ROOTS.to_vec(),
            })
            .with_no_client_auth();

        let url = config.doh_url();

        // Extract the hostname and resolve bootstrap IPs
        let doh_host = url
            .strip_prefix("https://")
            .unwrap_or(&url)
            .split('/')
            .next()
            .unwrap_or("")
            .to_string();

        let bootstrap_ips = config.bootstrap_addrs();
        let bootstrap_addrs: Vec<SocketAddr> = bootstrap_ips
            .iter()
            .filter_map(|ip| {
                ip.parse::<std::net::IpAddr>()
                    .ok()
                    .map(|addr| SocketAddr::new(addr, 443))
            })
            .collect();

        debug!(host = %doh_host, bootstrap = ?bootstrap_addrs, "Bootstrap addresses configured");

        let mut http = HttpConnector::new();
        http.enforce_http(false);

        let connector = BootstrapConnector {
            inner: http,
            bootstrap_host: doh_host,
            bootstrap_addrs,
        };

        let https = HttpsConnectorBuilder::new()
            .with_tls_config(tls)
            .https_only()
            .enable_http2()
            .wrap_connector(connector);

        let client = Client::builder(TokioExecutor::new())
            .http2_only(true)
            .build(https);

        debug!(url = %url, "Initialized DoH client");

        Self { url, client, cache }
    }

    /// Resolve a DNS query by forwarding to the DoH upstream.
    /// Returns the raw DNS wire-format response.
    pub async fn resolve(&self, query_bytes: &[u8]) -> Result<Vec<u8>, Box<dyn std::error::Error + Send + Sync>> {
        // Parse the query for cache lookup
        let query_msg = Message::from_vec(query_bytes)?;
        let query_id = query_msg.id();

        if let Some(queries) = query_msg.queries().first() {
            debug!(
                name = %queries.name(),
                rtype = %queries.query_type(),
                "Processing DNS query"
            );
        }

        // Check cache
        if let Some(cached) = self.cache.get(&query_msg) {
            // Rewrite the response ID to match the query
            let mut response = cached;
            if response.len() >= 2 {
                response[0] = (query_id >> 8) as u8;
                response[1] = (query_id & 0xff) as u8;
            }
            debug!("Cache hit");
            return Ok(response);
        }

        debug!("Cache miss, forwarding to upstream");

        // Build the DoH request (POST with application/dns-message)
        let req = Request::builder()
            .method("POST")
            .uri(&self.url)
            .header("content-type", "application/dns-message")
            .header("accept", "application/dns-message")
            .body(Full::new(Bytes::copy_from_slice(query_bytes)))?;

        let resp = self.client.request(req).await?;

        if !resp.status().is_success() {
            let status = resp.status();
            error!(status = %status, "DoH upstream returned error");
            return Err(format!("DoH upstream error: {}", status).into());
        }

        let body = resp.into_body().collect().await?.to_bytes();
        let response_bytes = body.to_vec();

        // Cache the response (store with the original query ID normalized)
        self.cache.put(&query_msg, &response_bytes);

        // Ensure response ID matches the query ID
        let mut result = response_bytes;
        if result.len() >= 2 {
            result[0] = (query_id >> 8) as u8;
            result[1] = (query_id & 0xff) as u8;
        }

        Ok(result)
    }
}
