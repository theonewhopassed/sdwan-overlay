# SpeedFusion-Style SD-WAN Overlay System

A fully customizable, per-packet bonded SD-WAN overlay system built for Ubuntu Server 20.04+ with enterprise-grade features including real-time link monitoring, intelligent packet scheduling, FEC, encryption, and zero-touch provisioning.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                CENTRAL CONTROLLER                      │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐     │
│  │   Grafana   │ │ Prometheus  │ │  Etcd DB    │     │
│  │  Dashboard  │ │  Metrics    │ │  Config     │     │
│  └─────────────┘ └─────────────┘ └─────────────┘     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐     │
│  │ Controller  │ │Device Agent │ │Management   │     │
│  │   (Go)      │ │  (Python)   │ │   API       │     │
│  └─────────────┘ └─────────────┘ └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│                EDGE DEVICE SOFTWARE                    │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐     │
│  │ Underlay    │ │   Packet    │ │   FEC       │     │
│  │ Manager     │ │ Scheduler   │ │  Engine     │     │
│  │  (Rust)     │ │   (Rust)    │ │   (C++)     │     │
│  └─────────────┘ └─────────────┘ └─────────────┘     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐     │
│  │Reassembly   │ │   Device    │ │   TUN/TAP   │     │
│  │  Engine     │ │   Agent     │ │  Interface  │     │
│  │   (C++)     │ │ (Python)    │ │             │     │
│  └─────────────┘ └─────────────┘ └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Core Components

### **Management Plane (Central Controller)**
- **Go Controller**: REST API for network management and orchestration
- **Etcd Store**: Distributed configuration and state management
- **Grafana Dashboard**: Real-time monitoring and visualization
- **Prometheus**: Metrics collection and alerting
- **Python Device Agent**: Central telemetry and configuration management

### **Data Plane (Edge Devices)**
- **Underlay Manager (Rust)**: ICMP/UDP probes for latency, jitter, packet loss, bandwidth
- **Packet Scheduler (Rust)**: Per-packet link assignment with YAML-driven QoS rules
- **FEC Engine (C++)**: Reed-Solomon and XOR-based forward error correction
- **Reassembly Engine (C++)**: Out-of-order packet reordering and jitter buffer
- **Device Agent (Python)**: Local telemetry and configuration updates
- **TUN/TAP Interface**: Virtual network interface for applications

## 🎯 Key Features

### **Intelligent Traffic Management**
- **Per-packet bonding** across multiple WAN connections
- **Real-time link monitoring** with ICMP/UDP probes
- **Dynamic load balancing** based on link quality
- **Automatic failover** with session continuity
- **QoS rules** for traffic prioritization

### **Enterprise-Grade Reliability**
- **Forward Error Correction (FEC)** for packet recovery
- **AES-256-GCM encryption** for secure transport
- **Jitter buffer** for out-of-order packet handling
- **Health monitoring** with Prometheus metrics
- **Zero-touch provisioning** via central controller

### **Comprehensive Deployment System**
- **Single edge deployment** with `deploy-edge.sh`
- **Bulk deployment** for multiple sites via YAML configuration
- **Cluster management** with health monitoring and backup/restore
- **Docker-based** deployment with systemd integration
- **Dynamic configuration** per edge device

## 🚀 Quick Start

### Prerequisites
- Ubuntu Server 20.04+
- Docker and Docker Compose
- Rust toolchain
- Go 1.19+
- Python 3.8+
- C++ build tools

### Installation

```bash
# Clone the repository
git clone https://github.com/theonewhopassed/sdwan-overlay.git
cd sdwan-overlay

# Setup environment
./scripts/setup.sh

# Build all components
make build

# Start the central controller
make start
```

### Deploy Edge Devices

#### Single Edge Deployment
```bash
# Deploy a single edge device
./scripts/deploy-edge.sh edge-01 192.168.1.100

# With custom configuration
./scripts/deploy-edge.sh edge-02 192.168.1.100 \
  --site-id=branch-office-2 \
  --interfaces=eth0,eth1,wlan0 \
  --prometheus-port=9093
```

#### Bulk Deployment
```bash
# Deploy multiple edge devices from configuration
make deploy-bulk

# Or directly
./scripts/deploy-bulk.sh config/edges.yml
```

#### Cluster Management
```bash
# Check cluster status
make cluster-status

# Monitor cluster health
make cluster-health

# View cluster logs
make cluster-logs

# Restart cluster services
make cluster-restart

# Create cluster backup
make cluster-backup

# Update cluster components
make cluster-update

# Open monitoring dashboard
make cluster-monitor

# Run connectivity tests
make cluster-test
```

## 📊 Configuration

### Edge Device Configuration (`config/edges.yml`)
```yaml
# Central controller IP address
controller_ip: 192.168.1.100

# Edge devices configuration
edges:
  - id: edge-01
    hostname: edge-01.example.com
    site_id: branch-office-1
    interfaces: eth0,eth1
    prometheus_port: 9092
    log_level: info
    description: "Main branch office with dual WAN"

# Deployment settings
deployment:
  mode: docker
  docker_registry: ""
  pull_images: true
  health_check_timeout: 300
  retry_attempts: 3

# Network settings
network:
  tun_interface_prefix: sdwan
  default_gateway: 10.0.0.1
  subnet_mask: 255.255.255.0
  mtu: 1500

# Monitoring settings
monitoring:
  metrics_interval: 30s
  health_check_interval: 60s
  alert_threshold_latency: 100ms
  alert_threshold_packet_loss: 0.05
  alert_threshold_bandwidth: 0.8
```

### Component-Specific Configuration
- **Controller**: `config/controller/controller.yml`
- **Device Agent**: `config/device-agent/config.yml`
- **Underlay Manager**: `config/underlay-manager/config.yml`
- **Packet Scheduler**: `config/packet-scheduler/config.yml`
- **FEC Engine**: `config/fec-engine/config.yml`
- **Reassembly Engine**: `config/reassembly-engine/config.yml`

## 🔧 Development

### Building Individual Components

```bash
# Build Rust components
make build-rust

# Build C++ components
make build-cpp

# Build Go components
make build-go

# Build Python components
make build-python

# Build Docker images
make build-docker
```

### Testing

```bash
# Run all tests
make test

# Run specific component tests
make test-rust
make test-cpp
make test-go
make test-python

# Run integration tests
make test-integration

# Run performance benchmarks
make benchmark
```

### Code Quality

```bash
# Format code
make format

# Lint code
make lint

# Security scan
make security

# Generate documentation
make docs
```

## 📈 Monitoring & Observability

### **Grafana Dashboard**
- **URL**: http://localhost:3000
- **Credentials**: admin/admin
- **Features**: Real-time SD-WAN metrics, link quality, traffic patterns

### **Prometheus Metrics**
- **URL**: http://localhost:9090
- **Metrics**: Link latency, bandwidth, packet loss, FEC statistics

### **Etcd Configuration Store**
- **URL**: http://localhost:2379
- **Purpose**: Distributed configuration and state management

### **Management API**
- **URL**: http://localhost:8080
- **Endpoints**: Edge device management, configuration updates, health checks

## 🛠️ Available Make Targets

```bash
# Core operations
make build          # Build all components
make test           # Run all tests
make start          # Start the system
make stop           # Stop the system
make clean          # Clean build artifacts

# Deployment
make deploy-edge    # Deploy single edge device
make deploy-bulk    # Deploy multiple edge devices
make deploy-cluster # Deploy complete cluster

# Cluster management
make cluster-status  # Show cluster status
make cluster-health  # Check cluster health
make cluster-logs    # View cluster logs
make cluster-restart # Restart cluster services
make cluster-backup  # Create cluster backup
make cluster-restore # Restore from backup
make cluster-update  # Update cluster components
make cluster-monitor # Open monitoring dashboard
make cluster-test    # Run connectivity tests

# Development
make setup          # Setup environment
make install-deps   # Install dependencies
make docs           # Generate documentation
make format         # Format code
make lint           # Lint code
make security       # Security scan
make help           # Show all targets
```

## 🌐 Network Architecture

### **Traffic Flow**
```
User Application
       ↓
   TUN Interface (sdwan01)
       ↓
   Edge Device Software
   ├── Packet Scheduler (routes traffic)
   ├── FEC Engine (adds redundancy)
   └── Underlay Manager (monitors links)
       ↓
   Multiple WAN Links
   ├── Primary: Fiber (eth0)
   ├── Backup: 4G LTE (eth1)
   └── Wireless: WiFi (wlan0)
       ↓
   Internet
       ↓
   Central Controller (monitoring only)
```

### **Edge Device Features**
- **Multi-WAN bonding** with intelligent failover
- **Per-packet load balancing** based on real-time metrics
- **Forward Error Correction** for packet recovery
- **Encrypted transport** with AES-256-GCM
- **TUN interface** for seamless application integration
- **Prometheus metrics** for monitoring
- **Zero-touch provisioning** via central controller

## 🔒 Security Features

- **AES-256-GCM encryption** for all overlay traffic
- **Sequence numbers and timestamps** for replay protection
- **Secure configuration management** via Etcd
- **Prometheus metrics** for security monitoring
- **Docker containerization** for isolation

## 📚 Documentation

- **Configuration Guide**: See individual config files in `config/`
- **Deployment Guide**: See `scripts/` directory for deployment scripts
- **API Documentation**: Available via Swagger at controller endpoint
- **Monitoring Guide**: See Grafana dashboards for metrics

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

For issues and questions:
- Check the documentation in `docs/`
- Review configuration examples in `config/`
- Run `make help` for available commands
- Use `make cluster-logs` for troubleshooting 
