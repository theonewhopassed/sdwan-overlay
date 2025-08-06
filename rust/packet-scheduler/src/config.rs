use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use anyhow::Result;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub scheduler: SchedulerConfig,
    pub qos: QosConfig,
    pub links: Vec<LinkConfig>,
    pub failover: FailoverConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SchedulerConfig {
    pub algorithm: String,
    pub batch_size: usize,
    pub max_queue_size: usize,
    pub metrics_interval: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QosConfig {
    pub rules: Vec<QosRule>,
    pub default_priority: u8,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QosRule {
    pub name: String,
    pub priority: u8,
    pub match_criteria: MatchCriteria,
    pub action: QosAction,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MatchCriteria {
    pub source_ip: Option<String>,
    pub dest_ip: Option<String>,
    pub protocol: Option<String>,
    pub port_range: Option<PortRange>,
    pub dscp: Option<u8>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PortRange {
    pub start: u16,
    pub end: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QosAction {
    pub link_preference: Vec<String>,
    pub bandwidth_limit: Option<u64>,
    pub latency_threshold: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LinkConfig {
    pub name: String,
    pub interface: String,
    pub weight: f64,
    pub max_bandwidth: u64,
    pub min_latency: u64,
    pub failover_group: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FailoverConfig {
    pub enabled: bool,
    pub health_check_interval: u64,
    pub failover_threshold: u64,
    pub recovery_threshold: u64,
}

impl Config {
    pub fn from_file<P: AsRef<Path>>(path: P) -> Result<Self> {
        let content = fs::read_to_string(path)?;
        let config: Config = serde_yaml::from_str(&content)?;
        Ok(config)
    }

    pub fn default() -> Self {
        Config {
            scheduler: SchedulerConfig {
                algorithm: "weighted_round_robin".to_string(),
                batch_size: 64,
                max_queue_size: 10000,
                metrics_interval: 1000,
            },
            qos: QosConfig {
                rules: vec![],
                default_priority: 5,
            },
            links: vec![],
            failover: FailoverConfig {
                enabled: true,
                health_check_interval: 5000,
                failover_threshold: 3,
                recovery_threshold: 5,
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
        assert_eq!(config.scheduler.algorithm, deserialized.scheduler.algorithm);
    }
} 