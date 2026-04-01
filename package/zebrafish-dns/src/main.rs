use std::sync::Arc;

use tracing::info;
use tracing_subscriber::EnvFilter;

use zebrafish_dns::cache::DnsCache;
use zebrafish_dns::config::Config;
use zebrafish_dns::doh::DohClient;
use zebrafish_dns::server::DnsServer;

const DEFAULT_CONFIG_PATH: &str = "/etc/zebrafish-dns/zebrafish-dns.toml";

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config_path = std::env::args()
        .nth(1)
        .unwrap_or_else(|| DEFAULT_CONFIG_PATH.to_string());

    let config = match Config::load(&config_path) {
        Ok(c) => {
            eprintln!("Loaded config from {}", config_path);
            c
        }
        Err(e) => {
            eprintln!(
                "Warning: could not load config from {}: {}, using defaults",
                config_path, e
            );
            Config::default()
        }
    };

    // Initialize logging
    let filter = EnvFilter::try_new(&config.logging.level)
        .unwrap_or_else(|_| EnvFilter::new("info"));
    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(false)
        .init();

    info!(
        provider = %config.upstream.provider,
        url = %config.doh_url(),
        listen = %format!("{}:{}", config.server.listen_address, config.server.listen_port),
        "Starting zebrafish-dns"
    );

    let workers = if config.server.workers == 0 {
        std::thread::available_parallelism()
            .map(|n| n.get())
            .unwrap_or(2)
    } else {
        config.server.workers
    };

    let runtime = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(workers)
        .enable_all()
        .build()?;

    runtime.block_on(async {
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

        server.run().await
    })
}
