use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use anyhow::Result;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub interfaces: Vec<InterfaceConfig>,
    pub probes: ProbeConfig,
    pub server: ServerConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InterfaceConfig {
    pub name: String,
    pub enabled: bool,
    pub probe_interval: u64,
    pub icmp_enabled: bool,
    pub udp_enabled: bool,
    pub bandwidth_test_enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProbeConfig {
    pub icmp_timeout: u64,
    pub udp_timeout: u64,
    pub bandwidth_test_duration: u64,
    pub packet_size: usize,
    pub probe_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConfig {
    pub grpc_port: u16,
    pub metrics_interval: u64,
    pub max_connections: usize,
}

impl Config {
    pub fn from_file<P: AsRef<Path>>(path: P) -> Result<Self> {
        let content = fs::read_to_string(path)?;
        let config: Config = serde_yaml::from_str(&content)?;
        Ok(config)
    }

    pub fn default() -> Self {
        Config {
            interfaces: vec![
                InterfaceConfig {
                    name: "eth0".to_string(),
                    enabled: true,
                    probe_interval: 5000,
                    icmp_enabled: true,
                    udp_enabled: true,
                    bandwidth_test_enabled: true,
                },
                InterfaceConfig {
                    name: "eth1".to_string(),
                    enabled: true,
                    probe_interval: 5000,
                    icmp_enabled: true,
                    udp_enabled: true,
                    bandwidth_test_enabled: true,
                },
            ],
            probes: ProbeConfig {
                icmp_timeout: 1000,
                udp_timeout: 2000,
                bandwidth_test_duration: 10000,
                packet_size: 1500,
                probe_count: 10,
            },
            server: ServerConfig {
                grpc_port: 9093,
                metrics_interval: 1000,
                max_connections: 100,
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_serialization() {
        let config = Config::default();
        let yaml = serde_yaml::to_string(&config).unwrap();
        let deserialized: Config = serde_yaml::from_str(&yaml).unwrap();
        assert_eq!(config.server.grpc_port, deserialized.server.grpc_port);
    }
} 