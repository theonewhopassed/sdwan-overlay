use crate::{Config, NetworkProbe, LinkMetrics};
use anyhow::Result;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tonic::{Request, Response, Status};
use tracing::{debug, error, info};

pub struct UnderlayManagerServer {
    config: Config,
    probe: Arc<NetworkProbe>,
    metrics_cache: Arc<RwLock<HashMap<String, LinkMetrics>>>,
}

impl UnderlayManagerServer {
    pub fn new(config: Config) -> Self {
        let probe = Arc::new(NetworkProbe::new(config.clone()));
        let metrics_cache = Arc::new(RwLock::new(HashMap::new()));
        
        Self {
            config,
            probe,
            metrics_cache,
        }
    }

    pub async fn start(&self, addr: String) -> Result<()> {
        info!("Starting Underlay Manager server on {}", addr);
        
        // Start metrics collection in background
        let probe = self.probe.clone();
        let metrics_cache = self.metrics_cache.clone();
        
        tokio::spawn(async move {
            loop {
                match probe.probe_all_interfaces().await {
                    Ok(metrics) => {
                        let mut cache = metrics_cache.write().await;
                        *cache = metrics;
                        debug!("Updated metrics cache with {} interfaces", cache.len());
                    }
                    Err(e) => {
                        error!("Failed to collect metrics: {}", e);
                    }
                }
                
                tokio::time::sleep(tokio::time::Duration::from_secs(30)).await;
            }
        });

        // TODO: Implement actual gRPC server
        // For now, just keep the server running
        loop {
            tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
        }
    }

    pub async fn get_metrics(&self) -> Result<HashMap<String, LinkMetrics>> {
        let cache = self.metrics_cache.read().await;
        Ok(cache.clone())
    }

    pub async fn probe_interface(&self, interface_name: &str) -> Result<LinkMetrics> {
        self.probe.probe_interface(interface_name).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_server_creation() {
        let config = Config::default();
        let server = UnderlayManagerServer::new(config);
        assert!(server.get_metrics().await.is_ok());
    }
} 