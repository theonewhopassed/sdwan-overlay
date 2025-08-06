// Protocol buffer definitions for packet scheduler
// This will be used for gRPC communication with other components

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricsRequest {
    pub interface_name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricsResponse {
    pub interface_name: String,
    pub latency_ms: f64,
    pub jitter_ms: f64,
    pub packet_loss: f64,
    pub bandwidth_mbps: f64,
    pub timestamp: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PacketRequest {
    pub packet_id: u64,
    pub data: Vec<u8>,
    pub priority: u8,
    pub source_ip: String,
    pub dest_ip: String,
    pub protocol: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PacketResponse {
    pub packet_id: u64,
    pub link_name: String,
    pub sequence_number: u64,
    pub status: String,
}

// Service trait for gRPC communication
#[async_trait::async_trait]
pub trait MetricsService {
    async fn get_metrics(&self, request: MetricsRequest) -> Result<MetricsResponse, Box<dyn std::error::Error>>;
}

#[async_trait::async_trait]
pub trait PacketService {
    async fn schedule_packet(&self, request: PacketRequest) -> Result<PacketResponse, Box<dyn std::error::Error>>;
} 