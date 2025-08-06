// Protocol buffer definitions for underlay manager
// This will be used for gRPC communication with other components

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProbeRequest {
    pub interface_name: String,
    pub probe_type: String, // "icmp", "udp", "bandwidth"
    pub timeout_ms: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProbeResponse {
    pub interface_name: String,
    pub latency_ms: f64,
    pub jitter_ms: f64,
    pub packet_loss: f64,
    pub bandwidth_mbps: f64,
    pub timestamp: String,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricsRequest {
    pub interface_names: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricsResponse {
    pub metrics: Vec<ProbeResponse>,
    pub timestamp: String,
}

// Service trait for gRPC communication
#[async_trait::async_trait]
pub trait UnderlayService {
    async fn probe_interface(&self, request: ProbeRequest) -> Result<ProbeResponse, Box<dyn std::error::Error>>;
    async fn get_metrics(&self, request: MetricsRequest) -> Result<MetricsResponse, Box<dyn std::error::Error>>;
} 