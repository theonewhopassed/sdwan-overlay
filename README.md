# SpeedFusion-Style SD-WAN Overlay System

A fully customizable, per-packet bonded SD-WAN overlay system built for Ubuntu Server 20.04+ with enterprise-grade features including real-time link monitoring, intelligent packet scheduling, FEC, encryption, and zero-touch provisioning.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Management    │    │   Edge Device   │    │   Edge Device   │
│     Plane       │    │   (Site A)      │    │   (Site B)      │
│                 │    │                 │    │                 │
│ • Go Controller │◄──►│ • Device Agent  │◄──►│ • Device Agent  │
│ • Etcd Store    │    │ • Underlay Mgr  │    │ • Underlay Mgr  │
│ • Grafana       │    │ • Packet Sched  │    │ • Packet Sched  │
│ • Prometheus    │    │ • FEC Engine    │    │ • FEC Engine    │
└─────────────────┘    │ • Encryption    │    │ • Encryption    │
                       │ • Reassembly    │    │ • Reassembly    │
                       └─────────────────┘    └─────────────────┘
```

## Core Components

### 1. Underlay Manager
- ICMP/UDP probes for latency, jitter, packet loss, bandwidth
- Real-time metrics via gRPC API
- Multi-interface monitoring

### 2. Packet Scheduler (Rust)
- Per-packet link assignment based on real-time metrics
- YAML-driven QoS rules
- Dynamic load balancing

### 3. FEC Engine (C++)
- Reed-Solomon and XOR-based FEC
- Packet recovery without retransmits
- Configurable redundancy levels

### 4. Encryption & Encapsulation
- AES-256-GCM encryption
- Sequence numbers and timestamps
- UDP transport

### 5. Reassembly & Jitter Buffer (C++)
- Out-of-order packet reordering
- Configurable jitter buffer
- TUN/TAP interface delivery

### 6. Failover Logic
- Automatic make-before-break failover
- Session continuity preservation
- Link quality monitoring

### 7. Management Plane (Go)
- Zero-touch provisioning
- Policy distribution via Etcd
- Telemetry aggregation for Grafana

### 8. Device Agent (Python)
- Configuration updates
- Telemetry streaming
- Prometheus exporter

## Quick Start

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
cd speedfusion-like

# Setup environment
./scripts/setup.sh

# Build all components
make build

# Start the system
make start
```

### Two-VM Proof of Concept

```bash
# On VM1 (Site A)
./scripts/deploy-edge.sh --site-id=site-a --wan-interfaces=eth1,eth2

# On VM2 (Site B)  
./scripts/deploy-edge.sh --site-id=site-b --wan-interfaces=eth1,eth2

# Verify connectivity
./scripts/test-connectivity.sh
```

## Development

### Building Individual Components

```bash
# Build Rust components
cargo build --release

# Build C++ components
make -C cpp/

# Build Go components
go build ./cmd/...

# Build Python components
pip install -e python/
```

### Testing

```bash
# Run all tests
make test

# Run network simulation tests
./scripts/test-netem.sh

# Run performance benchmarks
make benchmark
```

## Configuration

See `docs/configuration.md` for detailed configuration options for each component.

## Monitoring

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Etcd**: http://localhost:2379

## License

MIT License - see LICENSE file for details. 