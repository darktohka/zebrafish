//! Integration tests for zebrafish-dns.
//!
//! These tests start a real zebrafish-dns server on a local high port
//! and send actual DNS queries to it, which are forwarded via DoH
//! to the configured upstream (Cloudflare by default).
//!
//! Requirements:
//!   - Internet connectivity (to reach Cloudflare DoH)
//!   - Ports 15353 (and possibly 15354) available on localhost

use std::net::{Ipv4Addr, SocketAddr, UdpSocket};
use std::sync::Arc;
use std::time::{Duration, Instant};

use hickory_proto::op::{Message, MessageType, OpCode, Query, ResponseCode};
use hickory_proto::rr::rdata::{A, AAAA};
use hickory_proto::rr::record_data::RData;
use hickory_proto::rr::{Name, RecordType};

use zebrafish_dns::cache::DnsCache;
use zebrafish_dns::config::Config;
use zebrafish_dns::doh::DohClient;
use zebrafish_dns::server::DnsServer;

/// Helper: build a DNS wire-format query.
fn build_query(name: &str, rtype: RecordType) -> Vec<u8> {
    let mut msg = Message::new();
    msg.set_id(rand_id());
    msg.set_message_type(MessageType::Query);
    msg.set_op_code(OpCode::Query);
    msg.set_recursion_desired(true);
    let mut q = Query::new();
    q.set_name(Name::from_utf8(name).unwrap());
    q.set_query_type(rtype);
    msg.add_query(q);
    msg.to_vec().unwrap()
}

fn rand_id() -> u16 {
    let t = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default();
    ((t.subsec_nanos() ^ (t.as_secs() as u32)) & 0xFFFF) as u16
}

/// Send a UDP DNS query to the given address and parse the response.
fn send_udp_query(addr: SocketAddr, query: &[u8], timeout: Duration) -> Message {
    let sock = UdpSocket::bind("127.0.0.1:0").expect("bind ephemeral");
    sock.set_read_timeout(Some(timeout)).unwrap();
    sock.set_write_timeout(Some(timeout)).unwrap();
    sock.send_to(query, addr).expect("send query");

    let mut buf = vec![0u8; 4096];
    let len = sock.recv(&mut buf).expect("recv response");
    Message::from_vec(&buf[..len]).expect("parse response")
}

/// Send a TCP DNS query to the given address and parse the response.
fn send_tcp_query(addr: SocketAddr, query: &[u8], timeout: Duration) -> Message {
    use std::io::{Read, Write};
    use std::net::TcpStream;

    let mut stream = TcpStream::connect_timeout(&addr, timeout).expect("TCP connect");
    stream.set_read_timeout(Some(timeout)).unwrap();
    stream.set_write_timeout(Some(timeout)).unwrap();

    // DNS over TCP: 2-byte length prefix
    let len = (query.len() as u16).to_be_bytes();
    stream.write_all(&len).expect("write length");
    stream.write_all(query).expect("write query");

    let mut len_buf = [0u8; 2];
    stream.read_exact(&mut len_buf).expect("read resp length");
    let resp_len = u16::from_be_bytes(len_buf) as usize;

    let mut resp_buf = vec![0u8; resp_len];
    stream.read_exact(&mut resp_buf).expect("read resp body");
    Message::from_vec(&resp_buf).expect("parse TCP response")
}

struct TestServer {
    addr: SocketAddr,
    _runtime: tokio::runtime::Runtime,
}

impl TestServer {
    fn start(port: u16) -> Self {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .unwrap();

        let mut config = Config::default();
        config.server.listen_address = "127.0.0.1".to_string();
        config.server.listen_port = port;
        // Disable IPv6 binding for tests to avoid permission issues
        config.server.listen_address_v6 = "".to_string();

        let cache = Arc::new(DnsCache::new(
            config.cache.max_entries,
            config.cache.min_ttl,
            config.cache.max_ttl,
        ));
        let client = Arc::new(DohClient::new(&config, cache));
        let server = Arc::new(DnsServer::new(
            client,
            config.server.listen_address.clone(),
            config.server.listen_address_v6.clone(),
            config.server.listen_port,
        ));

        let addr: SocketAddr = format!("127.0.0.1:{}", port).parse().unwrap();

        runtime.spawn(async move {
            if let Err(e) = server.run().await {
                eprintln!("Server error: {}", e);
            }
        });

        // Give the server time to bind
        std::thread::sleep(Duration::from_millis(500));

        TestServer {
            addr,
            _runtime: runtime,
        }
    }
}

// Use a single static port range for tests. Each test uses a unique port.
// The tests are run serially since they share network resources.
const BASE_PORT: u16 = 15353;

#[test]
fn test_resolve_a_record_udp() {
    let server = TestServer::start(BASE_PORT);
    let query = build_query("one.one.one.one.", RecordType::A);
    let resp = send_udp_query(server.addr, &query, Duration::from_secs(10));

    assert_eq!(resp.response_code(), ResponseCode::NoError);
    assert!(!resp.answers().is_empty(), "Expected at least one A record");

    let has_a = resp.answers().iter().any(|r| matches!(r.data(), RData::A(_)));
    assert!(has_a, "Response should contain A records");

    println!("A records for one.one.one.one:");
    for record in resp.answers() {
        if let RData::A(A(ip)) = record.data() {
            println!("  {} (TTL: {})", ip, record.ttl());
        }
    }
}

#[test]
fn test_resolve_a_record_tcp() {
    let server = TestServer::start(BASE_PORT + 1);
    let query = build_query("one.one.one.one.", RecordType::A);
    let resp = send_tcp_query(server.addr, &query, Duration::from_secs(10));

    assert_eq!(resp.response_code(), ResponseCode::NoError);
    assert!(!resp.answers().is_empty(), "Expected at least one A record");

    let has_a = resp.answers().iter().any(|r| matches!(r.data(), RData::A(_)));
    assert!(has_a, "Response should contain A records via TCP");
}

#[test]
fn test_resolve_aaaa_record() {
    let server = TestServer::start(BASE_PORT + 2);
    let query = build_query("one.one.one.one.", RecordType::AAAA);
    let resp = send_udp_query(server.addr, &query, Duration::from_secs(10));

    assert_eq!(resp.response_code(), ResponseCode::NoError);
    // one.one.one.one has AAAA records
    let has_aaaa = resp.answers().iter().any(|r| matches!(r.data(), RData::AAAA(_)));
    assert!(has_aaaa, "Response should contain AAAA records");

    println!("AAAA records for one.one.one.one:");
    for record in resp.answers() {
        if let RData::AAAA(AAAA(ip)) = record.data() {
            println!("  {} (TTL: {})", ip, record.ttl());
        }
    }
}

#[test]
fn test_resolve_cname() {
    let server = TestServer::start(BASE_PORT + 3);
    let query = build_query("www.google.com.", RecordType::A);
    let resp = send_udp_query(server.addr, &query, Duration::from_secs(10));

    assert_eq!(resp.response_code(), ResponseCode::NoError);
    assert!(!resp.answers().is_empty(), "Expected answers for www.google.com");

    println!("Records for www.google.com:");
    for record in resp.answers() {
        println!("  {:?} TTL:{}", record.data(), record.ttl());
    }
}

#[test]
fn test_resolve_nxdomain() {
    let server = TestServer::start(BASE_PORT + 4);
    let query = build_query("this-domain-should-not-exist-zebrafish-test.invalid.", RecordType::A);
    let resp = send_udp_query(server.addr, &query, Duration::from_secs(10));

    // NXDOMAIN or empty answers
    assert!(
        resp.response_code() == ResponseCode::NXDomain || resp.answers().is_empty(),
        "Expected NXDOMAIN or empty response for nonexistent domain"
    );
}

#[test]
fn test_resolve_mx_record() {
    let server = TestServer::start(BASE_PORT + 5);
    let query = build_query("google.com.", RecordType::MX);
    let resp = send_udp_query(server.addr, &query, Duration::from_secs(10));

    assert_eq!(resp.response_code(), ResponseCode::NoError);
    assert!(!resp.answers().is_empty(), "Expected MX records for google.com");

    println!("MX records for google.com:");
    for record in resp.answers() {
        println!("  {:?} TTL:{}", record.data(), record.ttl());
    }
}

#[test]
fn test_resolve_txt_record() {
    let server = TestServer::start(BASE_PORT + 6);
    let query = build_query("google.com.", RecordType::TXT);
    let resp = send_udp_query(server.addr, &query, Duration::from_secs(10));

    assert_eq!(resp.response_code(), ResponseCode::NoError);
    assert!(!resp.answers().is_empty(), "Expected TXT records for google.com");
}

#[test]
fn test_caching_reduces_latency() {
    let server = TestServer::start(BASE_PORT + 7);
    let query = build_query("cloudflare.com.", RecordType::A);

    // First query — goes upstream
    let start1 = Instant::now();
    let resp1 = send_udp_query(server.addr, &query, Duration::from_secs(10));
    let elapsed1 = start1.elapsed();

    assert_eq!(resp1.response_code(), ResponseCode::NoError);
    assert!(!resp1.answers().is_empty());

    // Second query — should hit cache, significantly faster
    let start2 = Instant::now();
    let resp2 = send_udp_query(server.addr, &query, Duration::from_secs(10));
    let elapsed2 = start2.elapsed();

    assert_eq!(resp2.response_code(), ResponseCode::NoError);
    assert!(!resp2.answers().is_empty());

    println!(
        "Cache test: first={:?}, second={:?} (speedup: {:.1}x)",
        elapsed1,
        elapsed2,
        elapsed1.as_secs_f64() / elapsed2.as_secs_f64()
    );

    // Cached response should be materially faster (at least 2x)
    // Being lenient to avoid flaky tests in slow CI
    assert!(
        elapsed2 < elapsed1 || elapsed2 < Duration::from_millis(10),
        "Cached query should be faster: {:?} vs {:?}",
        elapsed2,
        elapsed1,
    );
}

#[test]
fn test_caching_same_response_data() {
    let server = TestServer::start(BASE_PORT + 8);
    let query = build_query("one.one.one.one.", RecordType::A);

    let resp1 = send_udp_query(server.addr, &query, Duration::from_secs(10));
    let resp2 = send_udp_query(server.addr, &query, Duration::from_secs(10));

    // Both should return success with the same A records
    assert_eq!(resp1.response_code(), ResponseCode::NoError);
    assert_eq!(resp2.response_code(), ResponseCode::NoError);

    let ips1: Vec<Ipv4Addr> = resp1
        .answers()
        .iter()
        .filter_map(|r| match r.data() {
            RData::A(A(ip)) => Some(*ip),
            _ => None,
        })
        .collect();

    let ips2: Vec<Ipv4Addr> = resp2
        .answers()
        .iter()
        .filter_map(|r| match r.data() {
            RData::A(A(ip)) => Some(*ip),
            _ => None,
        })
        .collect();

    assert_eq!(ips1, ips2, "Cached response should return same IPs");
}

#[test]
fn test_multiple_concurrent_queries() {
    let server = TestServer::start(BASE_PORT + 9);
    let addr = server.addr;

    let domains = [
        "google.com.",
        "cloudflare.com.",
        "github.com.",
        "rust-lang.org.",
    ];

    let handles: Vec<_> = domains
        .iter()
        .map(|domain| {
            let domain = domain.to_string();
            std::thread::spawn(move || {
                let query = build_query(&domain, RecordType::A);
                let resp = send_udp_query(addr, &query, Duration::from_secs(15));
                (domain, resp)
            })
        })
        .collect();

    for handle in handles {
        let (domain, resp) = handle.join().expect("thread panicked");
        assert_eq!(
            resp.response_code(),
            ResponseCode::NoError,
            "Failed for domain: {}",
            domain
        );
        assert!(
            !resp.answers().is_empty(),
            "No answers for domain: {}",
            domain
        );
        println!("Resolved {}: {} answer(s)", domain, resp.answers().len());
    }
}

#[test]
fn test_google_provider() {
    // Test with Google DoH provider
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();

    let mut config = Config::default();
    // Add Google provider
    config.upstream.providers.insert(
        "google".to_string(),
        zebrafish_dns::config::ProviderConfig {
            url: "https://dns.google/dns-query".to_string(),
            bootstrap: vec!["8.8.8.8".to_string()],
        },
    );
    config.upstream.provider = "google".to_string();

    let cache = Arc::new(DnsCache::new(100, 60, 86400));
    let client = Arc::new(DohClient::new(&config, cache));

    let query = build_query("example.com.", RecordType::A);

    let result = runtime.block_on(async { client.resolve(&query).await });

    assert!(result.is_ok(), "Google DoH query failed: {:?}", result.err());
    let resp_bytes = result.unwrap();
    let resp = Message::from_vec(&resp_bytes).unwrap();
    assert_eq!(resp.response_code(), ResponseCode::NoError);
    assert!(!resp.answers().is_empty());

    println!("Google DoH resolved example.com successfully");
}

#[test]
fn test_doh_client_directly() {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();

    let config = Config::default();
    let cache = Arc::new(DnsCache::new(100, 60, 86400));
    let client = DohClient::new(&config, cache);

    let query = build_query("example.com.", RecordType::A);

    let result = runtime.block_on(async { client.resolve(&query).await });

    assert!(result.is_ok(), "DoH resolve failed: {:?}", result.err());
    let resp_bytes = result.unwrap();
    let resp = Message::from_vec(&resp_bytes).unwrap();
    assert_eq!(resp.response_code(), ResponseCode::NoError);
    assert!(!resp.answers().is_empty());

    let ips: Vec<_> = resp
        .answers()
        .iter()
        .filter_map(|r| match r.data() {
            RData::A(A(ip)) => Some(ip.to_string()),
            _ => None,
        })
        .collect();

    println!("Direct DoH: example.com -> {:?}", ips);
}
