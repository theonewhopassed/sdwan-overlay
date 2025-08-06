#!/usr/bin/env python3
"""
SD-WAN Device Agent
"""

import time
import logging
import requests
from typing import Dict, Any

class DeviceAgent:
    """SD-WAN Device Agent for managing edge device operations."""
    
    def __init__(self, config: Dict[str, Any]):
        """Initialize the device agent."""
        self.config = config
        self.site_id = config.get('site_id', 'unknown')
        self.controller_endpoint = config.get('controller_endpoint', 'http://localhost:8080')
        self.logger = logging.getLogger(__name__)
        self.running = False
        
    def start(self):
        """Start the device agent."""
        self.logger.info(f"Starting SD-WAN Device Agent for site: {self.site_id}")
        self.running = True
        
        try:
            while self.running:
                # Send heartbeat to controller
                self._send_heartbeat()
                
                # Collect and send metrics
                self._collect_metrics()
                
                # Sleep for the configured interval
                time.sleep(self.config.get('metrics_interval', 30))
                
        except KeyboardInterrupt:
            self.logger.info("Device agent stopped by user")
        except Exception as e:
            self.logger.error(f"Device agent error: {e}")
            raise
    
    def stop(self):
        """Stop the device agent."""
        self.logger.info("Stopping device agent")
        self.running = False
    
    def _send_heartbeat(self):
        """Send heartbeat to the controller."""
        try:
            response = requests.post(
                f"{self.controller_endpoint}/api/v1/devices/{self.site_id}/heartbeat",
                json={
                    "site_id": self.site_id,
                    "timestamp": time.time(),
                    "status": "healthy"
                },
                timeout=5
            )
            if response.status_code == 200:
                self.logger.debug("Heartbeat sent successfully")
            else:
                self.logger.warning(f"Heartbeat failed: {response.status_code}")
        except Exception as e:
            self.logger.error(f"Failed to send heartbeat: {e}")
    
    def _collect_metrics(self):
        """Collect and send metrics to the controller."""
        try:
            metrics = {
                "site_id": self.site_id,
                "timestamp": time.time(),
                "cpu_usage": self._get_cpu_usage(),
                "memory_usage": self._get_memory_usage(),
                "network_interfaces": self._get_network_interfaces()
            }
            
            response = requests.post(
                f"{self.controller_endpoint}/api/v1/devices/{self.site_id}/metrics",
                json=metrics,
                timeout=5
            )
            
            if response.status_code == 200:
                self.logger.debug("Metrics sent successfully")
            else:
                self.logger.warning(f"Metrics failed: {response.status_code}")
                
        except Exception as e:
            self.logger.error(f"Failed to collect metrics: {e}")
    
    def _get_cpu_usage(self):
        """Get CPU usage percentage."""
        try:
            with open('/proc/loadavg', 'r') as f:
                load = f.read().split()[0]
                return float(load)
        except:
            return 0.0
    
    def _get_memory_usage(self):
        """Get memory usage percentage."""
        try:
            with open('/proc/meminfo', 'r') as f:
                lines = f.readlines()
                total = int(lines[0].split()[1])
                available = int(lines[2].split()[1])
                used = total - available
                return (used / total) * 100
        except:
            return 0.0
    
    def _get_network_interfaces(self):
        """Get network interface information."""
        try:
            with open('/proc/net/dev', 'r') as f:
                lines = f.readlines()[2:]  # Skip header lines
                interfaces = {}
                for line in lines:
                    parts = line.split()
                    if len(parts) >= 10:
                        name = parts[0].rstrip(':')
                        rx_bytes = int(parts[1])
                        tx_bytes = int(parts[9])
                        interfaces[name] = {
                            "rx_bytes": rx_bytes,
                            "tx_bytes": tx_bytes
                        }
                return interfaces
        except:
            return {}
