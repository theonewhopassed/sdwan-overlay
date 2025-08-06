use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LinkMetrics {
    pub latency_ms: f64,
    pub jitter_ms: f64,
    pub packet_loss: f64,
    pub bandwidth_mbps: f64,
    pub timestamp: DateTime<Utc>,
}

impl LinkMetrics {
    pub fn new() -> Self {
        Self {
            latency_ms: 0.0,
            jitter_ms: 0.0,
            packet_loss: 0.0,
            bandwidth_mbps: 0.0,
            timestamp: Utc::now(),
        }
    }
    
    pub fn health_score(&self) -> f64 {
        let latency_score = 1.0 / (1.0 + self.latency_ms);
        let bandwidth_score = (self.bandwidth_mbps / 1000.0).min(1.0);
        let loss_score = 1.0 - self.packet_loss;
        
        (latency_score + bandwidth_score + loss_score) / 3.0
    }
    
    pub fn is_healthy(&self, threshold: f64) -> bool {
        self.health_score() >= threshold
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricsSnapshot {
    pub link_metrics: std::collections::HashMap<String, LinkMetrics>,
    pub timestamp: DateTime<Utc>,
}

impl MetricsSnapshot {
    pub fn new() -> Self {
        Self {
            link_metrics: std::collections::HashMap::new(),
            timestamp: Utc::now(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_link_metrics_health_score() {
        let mut metrics = LinkMetrics::new();
        metrics.latency_ms = 10.0;
        metrics.bandwidth_mbps = 100.0;
        metrics.packet_loss = 0.001;
        
        let score = metrics.health_score();
        assert!(score > 0.0 && score <= 1.0);
    }
    
    #[test]
    fn test_link_metrics_health_check() {
        let mut metrics = LinkMetrics::new();
        metrics.latency_ms = 5.0;
        metrics.bandwidth_mbps = 500.0;
        metrics.packet_loss = 0.0001;
        
        assert!(metrics.is_healthy(0.5));
    }
} 