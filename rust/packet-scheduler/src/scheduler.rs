use crate::{Config, LinkMetrics, QosRule};
use anyhow::Result;
use async_trait::async_trait;
use crossbeam_channel::{bounded, Receiver, Sender};
use dashmap::DashMap;
use parking_lot::RwLock;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::time::Duration;
use chrono::{DateTime, Utc};
use tracing::{debug, error, info};

pub struct Packet {
    pub id: u64,
    pub data: Vec<u8>,
    pub priority: u8,
    pub source_ip: String,
    pub dest_ip: String,
    pub protocol: String,
    pub timestamp: DateTime<Utc>,
}

pub struct ScheduledPacket {
    pub packet: Packet,
    pub link_name: String,
    pub sequence_number: u64,
}

#[async_trait]
pub trait LinkSelector {
    async fn select_link(&self, packet: &Packet, metrics: &HashMap<String, LinkMetrics>) -> Result<String>;
}

pub struct WeightedRoundRobinSelector {
    current_weights: Arc<RwLock<HashMap<String, f64>>>,
}

impl WeightedRoundRobinSelector {
    pub fn new() -> Self {
        Self {
            current_weights: Arc::new(RwLock::new(HashMap::new())),
        }
    }
}

#[async_trait]
impl LinkSelector for WeightedRoundRobinSelector {
    async fn select_link(&self, _packet: &Packet, metrics: &HashMap<String, LinkMetrics>) -> Result<String> {
        let mut weights = self.current_weights.write();
        
        // Update weights based on current metrics
        for (link_name, metric) in metrics {
            let health_score = self.calculate_health_score(metric);
            weights.insert(link_name.clone(), health_score);
        }
        
        // Select link with highest weight
        let selected = weights.iter()
            .max_by(|a, b| a.1.partial_cmp(b.1).unwrap_or(std::cmp::Ordering::Equal))
            .map(|(name, _)| name.clone())
            .ok_or_else(|| anyhow::anyhow!("No available links"))?;
            
        Ok(selected)
    }
}

impl WeightedRoundRobinSelector {
    fn calculate_health_score(&self, metric: &LinkMetrics) -> f64 {
        let latency_score = 1.0 / (1.0 + metric.latency_ms as f64);
        let bandwidth_score = metric.bandwidth_mbps / 1000.0; // Normalize to 1Gbps
        let loss_score = 1.0 - metric.packet_loss;
        
        (latency_score + bandwidth_score + loss_score) / 3.0
    }
}

pub struct PacketScheduler {
    config: Config,
    link_selector: Box<dyn LinkSelector + Send + Sync>,
    metrics_receiver: Receiver<HashMap<String, LinkMetrics>>,
    packet_sender: Sender<ScheduledPacket>,
    qos_rules: Arc<DashMap<String, QosRule>>,
    sequence_counter: Arc<RwLock<u64>>,
    running: Arc<RwLock<bool>>,
}

impl PacketScheduler {
    pub async fn new(
        config: Config,
        underlay_endpoint: String,
    ) -> Result<Self> {
        let (metrics_sender, metrics_receiver) = bounded(100);
        let (packet_sender, _packet_receiver) = bounded(config.scheduler.max_queue_size);
        
        // Initialize QoS rules
        let qos_rules = Arc::new(DashMap::new());
        for rule in &config.qos.rules {
            qos_rules.insert(rule.name.clone(), rule.clone());
        }
        
        // Start metrics collection
        Self::start_metrics_collection(underlay_endpoint, metrics_sender).await?;
        
        let link_selector: Box<dyn LinkSelector + Send + Sync> = match config.scheduler.algorithm.as_str() {
            "weighted_round_robin" => Box::new(WeightedRoundRobinSelector::new()),
            _ => return Err(anyhow::anyhow!("Unknown scheduler algorithm: {}", config.scheduler.algorithm)),
        };
        
        Ok(Self {
            config,
            link_selector,
            metrics_receiver,
            packet_sender,
            qos_rules,
            sequence_counter: Arc::new(RwLock::new(0)),
            running: Arc::new(RwLock::new(true)),
        })
    }
    
    async fn start_metrics_collection(
        _endpoint: String,
        sender: Sender<HashMap<String, LinkMetrics>>,
    ) -> Result<()> {
        // TODO: Implement gRPC client to underlay manager
        tokio::spawn(async move {
            loop {
                // Simulate metrics collection
                let mut metrics = HashMap::new();
                metrics.insert("eth0".to_string(), LinkMetrics {
                    latency_ms: 10.0,
                    jitter_ms: 2.0,
                    packet_loss: 0.001,
                    bandwidth_mbps: 100.0,
                    timestamp: Utc::now(),
                });
                metrics.insert("eth1".to_string(), LinkMetrics {
                    latency_ms: 15.0,
                    jitter_ms: 3.0,
                    packet_loss: 0.002,
                    bandwidth_mbps: 50.0,
                    timestamp: Utc::now(),
                });
                
                if let Err(e) = sender.send(metrics) {
                    error!("Failed to send metrics: {}", e);
                }
                
                tokio::time::sleep(Duration::from_millis(1000)).await;
            }
        });
        
        Ok(())
    }
    
    pub async fn run(&mut self) -> Result<()> {
        info!("Starting packet scheduler with algorithm: {}", self.config.scheduler.algorithm);
        
        let mut current_metrics = HashMap::new();
        
        loop {
            if !*self.running.read() {
                break;
            }
            
            // Update metrics
            if let Ok(metrics) = self.metrics_receiver.try_recv() {
                current_metrics = metrics;
                debug!("Updated link metrics: {:?}", current_metrics);
            }
            
            // Process packets (simulated)
            self.process_packet_batch(&current_metrics).await?;
            
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
        
        Ok(())
    }
    
    async fn process_packet_batch(&self, metrics: &HashMap<String, LinkMetrics>) -> Result<()> {
        // Simulate packet processing
        let packet = Packet {
            id: 1,
            data: vec![0u8; 1500],
            priority: 5,
            source_ip: "192.168.1.100".to_string(),
            dest_ip: "192.168.1.200".to_string(),
            protocol: "TCP".to_string(),
            timestamp: Utc::now(),
        };
        
        // Apply QoS rules
        let _qos_rule = self.apply_qos_rules(&packet);
        
        // Select link
        let link_name = self.link_selector.select_link(&packet, metrics).await?;
        
        // Create scheduled packet
        let sequence_number = {
            let mut counter = self.sequence_counter.write();
            *counter += 1;
            *counter
        };
        
        let scheduled_packet = ScheduledPacket {
            packet,
            link_name,
            sequence_number,
        };
        
        // Send to next stage
        if let Err(e) = self.packet_sender.send(scheduled_packet) {
            error!("Failed to send scheduled packet: {}", e);
        }
        
        Ok(())
    }
    
    fn apply_qos_rules(&self, packet: &Packet) -> Option<QosRule> {
        for rule in self.qos_rules.iter() {
            if self.matches_rule(packet, rule.value()) {
                return Some(rule.value().clone());
            }
        }
        None
    }
    
    fn matches_rule(&self, packet: &Packet, rule: &QosRule) -> bool {
        if let Some(ref source_ip) = rule.match_criteria.source_ip {
            if packet.source_ip != *source_ip {
                return false;
            }
        }
        
        if let Some(ref dest_ip) = rule.match_criteria.dest_ip {
            if packet.dest_ip != *dest_ip {
                return false;
            }
        }
        
        if let Some(ref protocol) = rule.match_criteria.protocol {
            if packet.protocol != *protocol {
                return false;
            }
        }
        
        true
    }
    
    pub fn stop(&self) {
        *self.running.write() = false;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_packet_scheduler_creation() {
        let config = Config::default();
        let scheduler = PacketScheduler::new(config, "http://localhost:9093".to_string()).await;
        assert!(scheduler.is_ok());
    }
} 