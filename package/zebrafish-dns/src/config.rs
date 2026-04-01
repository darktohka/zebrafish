use std::collections::HashMap;

use serde::Deserialize;

#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    pub server: ServerConfig,
    pub upstream: UpstreamConfig,
    pub cache: CacheConfig,
    pub logging: LoggingConfig,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ServerConfig {
    pub listen_address: String,
    pub listen_port: u16,
    #[serde(default = "default_listen_v6")]
    pub listen_address_v6: String,
    #[serde(default)]
    pub workers: usize,
}

fn default_listen_v6() -> String {
    "::".to_string()
}

#[derive(Debug, Deserialize, Clone)]
pub struct UpstreamConfig {
    pub provider: String,
    pub custom_url: Option<String>,
    #[serde(default)]
    pub providers: HashMap<String, ProviderConfig>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ProviderConfig {
    pub url: String,
    pub bootstrap: Vec<String>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct CacheConfig {
    #[serde(default = "default_max_entries")]
    pub max_entries: usize,
    #[serde(default = "default_min_ttl")]
    pub min_ttl: u32,
    #[serde(default = "default_max_ttl")]
    pub max_ttl: u32,
}

fn default_max_entries() -> usize {
    10000
}

fn default_min_ttl() -> u32 {
    60
}

fn default_max_ttl() -> u32 {
    86400
}

#[derive(Debug, Deserialize, Clone)]
pub struct LoggingConfig {
    #[serde(default = "default_log_level")]
    pub level: String,
}

fn default_log_level() -> String {
    "info".to_string()
}

impl Config {
    pub fn load(path: &str) -> Result<Self, Box<dyn std::error::Error>> {
        let content = std::fs::read_to_string(path)?;
        let config: Config = toml::from_str(&content)?;
        Ok(config)
    }

    pub fn doh_url(&self) -> String {
        if self.upstream.provider == "custom" {
            return self
                .upstream
                .custom_url
                .clone()
                .unwrap_or_else(|| "https://cloudflare-dns.com/dns-query".to_string());
        }

        self.upstream
            .providers
            .get(&self.upstream.provider)
            .map(|p| p.url.clone())
            .unwrap_or_else(|| "https://cloudflare-dns.com/dns-query".to_string())
    }

    pub fn bootstrap_addrs(&self) -> Vec<String> {
        if self.upstream.provider == "custom" {
            return vec!["1.1.1.1".to_string()];
        }

        self.upstream
            .providers
            .get(&self.upstream.provider)
            .map(|p| p.bootstrap.clone())
            .unwrap_or_else(|| vec!["1.1.1.1".to_string()])
    }
}

impl Default for Config {
    fn default() -> Self {
        let mut providers = HashMap::new();
        providers.insert(
            "cloudflare".to_string(),
            ProviderConfig {
                url: "https://cloudflare-dns.com/dns-query".to_string(),
                bootstrap: vec![
                    "1.1.1.1".to_string(),
                    "1.0.0.1".to_string(),
                    "2606:4700:4700::1111".to_string(),
                    "2606:4700:4700::1001".to_string(),
                ],
            },
        );

        Config {
            server: ServerConfig {
                listen_address: "0.0.0.0".to_string(),
                listen_port: 53,
                listen_address_v6: "::".to_string(),
                workers: 0,
            },
            upstream: UpstreamConfig {
                provider: "cloudflare".to_string(),
                custom_url: None,
                providers,
            },
            cache: CacheConfig {
                max_entries: 10000,
                min_ttl: 60,
                max_ttl: 86400,
            },
            logging: LoggingConfig {
                level: "info".to_string(),
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = Config::default();
        assert_eq!(config.server.listen_address, "0.0.0.0");
        assert_eq!(config.server.listen_port, 53);
        assert_eq!(config.upstream.provider, "cloudflare");
        assert_eq!(config.cache.max_entries, 10000);
        assert_eq!(config.cache.min_ttl, 60);
        assert_eq!(config.cache.max_ttl, 86400);
        assert_eq!(config.logging.level, "info");
    }

    #[test]
    fn test_doh_url_cloudflare() {
        let config = Config::default();
        assert_eq!(config.doh_url(), "https://cloudflare-dns.com/dns-query");
    }

    #[test]
    fn test_doh_url_custom() {
        let mut config = Config::default();
        config.upstream.provider = "custom".to_string();
        config.upstream.custom_url = Some("https://my-doh.example.com/dns-query".to_string());
        assert_eq!(config.doh_url(), "https://my-doh.example.com/dns-query");
    }

    #[test]
    fn test_doh_url_custom_fallback() {
        let mut config = Config::default();
        config.upstream.provider = "custom".to_string();
        config.upstream.custom_url = None;
        // Should fall back to cloudflare
        assert_eq!(config.doh_url(), "https://cloudflare-dns.com/dns-query");
    }

    #[test]
    fn test_doh_url_unknown_provider_fallback() {
        let mut config = Config::default();
        config.upstream.provider = "nonexistent".to_string();
        // Should fall back to cloudflare
        assert_eq!(config.doh_url(), "https://cloudflare-dns.com/dns-query");
    }

    #[test]
    fn test_bootstrap_addrs_cloudflare() {
        let config = Config::default();
        let addrs = config.bootstrap_addrs();
        assert!(addrs.contains(&"1.1.1.1".to_string()));
        assert!(addrs.contains(&"1.0.0.1".to_string()));
    }

    #[test]
    fn test_bootstrap_addrs_custom_fallback() {
        let mut config = Config::default();
        config.upstream.provider = "custom".to_string();
        let addrs = config.bootstrap_addrs();
        assert_eq!(addrs, vec!["1.1.1.1".to_string()]);
    }

    #[test]
    fn test_load_toml_config() {
        let toml_str = r#"
[server]
listen_address = "127.0.0.1"
listen_port = 5353
workers = 4

[upstream]
provider = "google"

[upstream.providers.google]
url = "https://dns.google/dns-query"
bootstrap = ["8.8.8.8", "8.8.4.4"]

[cache]
max_entries = 5000
min_ttl = 30
max_ttl = 3600

[logging]
level = "debug"
"#;
        let config: Config = toml::from_str(toml_str).unwrap();
        assert_eq!(config.server.listen_address, "127.0.0.1");
        assert_eq!(config.server.listen_port, 5353);
        assert_eq!(config.server.workers, 4);
        assert_eq!(config.upstream.provider, "google");
        assert_eq!(config.cache.max_entries, 5000);
        assert_eq!(config.cache.min_ttl, 30);
        assert_eq!(config.cache.max_ttl, 3600);
        assert_eq!(config.logging.level, "debug");
        assert_eq!(config.doh_url(), "https://dns.google/dns-query");
    }

    #[test]
    fn test_load_from_file() {
        let config = Config::load("config/zebrafish-dns.toml").unwrap();
        assert_eq!(config.upstream.provider, "cloudflare");
        assert!(config.upstream.providers.contains_key("cloudflare"));
        assert!(config.upstream.providers.contains_key("google"));
        assert!(config.upstream.providers.contains_key("quad9"));
    }
}
