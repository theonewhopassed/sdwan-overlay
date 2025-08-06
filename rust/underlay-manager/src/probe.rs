use crate::{Config, LinkMetrics};
use anyhow::Result;
use std::collections::HashMap;
use std::time::Duration;
use chrono::Utc;
use tokio::time::Instant;
use tracing::{debug, error, info};

pub struct NetworkProbe {
    config: Config,
}

impl NetworkProbe {
    pub fn new(config: Config) -> Self {
        Self { config }
    }

    pub async fn probe_interface(&self, interface_name: &str) -> Result<LinkMetrics> {
        let mut metrics = LinkMetrics::new();
        
        // ICMP ping test
        if let Ok(latency) = self.icmp_probe(interface_name).await {
            metrics.latency_ms = latency;
        }
        
        // UDP probe test
        if let Ok((latency, jitter, loss)) = self.udp_probe(interface_name).await {
            metrics.latency_ms = latency;
            metrics.jitter_ms = jitter;
            metrics.packet_loss = loss;
        }
        
        // Bandwidth test
        if let Ok(bandwidth) = self.bandwidth_probe(interface_name).await {
            metrics.bandwidth_mbps = bandwidth;
        }
        
        metrics.timestamp = Utc::now();
        Ok(metrics)
    }

    async fn icmp_probe(&self, interface_name: &str) -> Result<f64> {
        // Simulate ICMP ping
        let start = Instant::now();
        
        // TODO: Implement actual ICMP ping using pnet
        tokio::time::sleep(Duration::from_millis(10)).await;
        
        let latency = start.elapsed().as_millis() as f64;
        debug!("ICMP probe for {}: {}ms", interface_name, latency);
        
        Ok(latency)
    }

    async fn udp_probe(&self, interface_name: &str) -> Result<(f64, f64, f64)> {
        let probe_config = &self.config.probes;
        let mut latencies = Vec::new();
        let mut lost_packets = 0;
        
        for i in 0..probe_config.probe_count {
            let start = Instant::now();
            
            // Simulate UDP probe
            tokio::time::sleep(Duration::from_millis(5 + (i % 3) as u64)).await;
            
            let latency = start.elapsed().as_millis() as f64;
            latencies.push(latency);
            
            // Simulate packet loss
            if i % 100 == 0 {
                lost_packets += 1;
            }
        }
        
        let avg_latency = latencies.iter().sum::<f64>() / latencies.len() as f64;
        let jitter = self.calculate_jitter(&latencies);
        let loss_rate = lost_packets as f64 / probe_config.probe_count as f64;
        
        debug!("UDP probe for {}: latency={}ms, jitter={}ms, loss={}%", 
               interface_name, avg_latency, jitter, loss_rate * 100.0);
        
        Ok((avg_latency, jitter, loss_rate))
    }

    async fn bandwidth_probe(&self, interface_name: &str) -> Result<f64> {
        // Simulate bandwidth test
        let start = Instant::now();
        
        // TODO: Implement actual bandwidth measurement
        tokio::time::sleep(Duration::from_millis(100)).await;
        
        let _duration = start.elapsed().as_millis() as f64;
        let bandwidth = 100.0 + (interface_name.len() as f64 * 10.0); // Simulated bandwidth
        
        debug!("Bandwidth probe for {}: {} Mbps", interface_name, bandwidth);
        
        Ok(bandwidth)
    }

    fn calculate_jitter(&self, latencies: &[f64]) -> f64 {
        if latencies.len() < 2 {
            return 0.0;
        }
        
        let mut jitter_sum = 0.0;
        for i in 1..latencies.len() {
            jitter_sum += (latencies[i] - latencies[i-1]).abs();
        }
        
        jitter_sum / (latencies.len() - 1) as f64
    }

    pub async fn probe_all_interfaces(&self) -> Result<HashMap<String, LinkMetrics>> {
        let mut metrics = HashMap::new();
        
        for interface in &self.config.interfaces {
            if !interface.enabled {
                continue;
            }
            
            match self.probe_interface(&interface.name).await {
                Ok(metric) => {
                    let latency = metric.latency_ms;
                    let bandwidth = metric.bandwidth_mbps;
                    metrics.insert(interface.name.clone(), metric);
                    info!("Probed interface {}: latency={}ms, bandwidth={}Mbps", 
                          interface.name, latency, bandwidth);
                }
                Err(e) => {
                    error!("Failed to probe interface {}: {}", interface.name, e);
                }
            }
        }
        
        Ok(metrics)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_network_probe_creation() {
        let config = Config::default();
        let probe = NetworkProbe::new(config);
        assert!(probe.probe_all_interfaces().await.is_ok());
    }
} 