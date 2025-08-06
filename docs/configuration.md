# SD-WAN Configuration Guide

This document describes the configuration options for all SD-WAN components.

## Table of Contents

1. [Packet Scheduler Configuration](#packet-scheduler-configuration)
2. [Underlay Manager Configuration](#underlay-manager-configuration)
3. [FEC Engine Configuration](#fec-engine-configuration)
4. [Reassembly Engine Configuration](#reassembly-engine-configuration)
5. [Controller Configuration](#controller-configuration)
6. [Device Agent Configuration](#device-agent-configuration)
7. [System Configuration](#system-configuration)

## Packet Scheduler Configuration

The packet scheduler is configured via YAML files. Here's the complete configuration structure:

```yaml
scheduler:
  algorithm: "weighted_round_robin"  # or "round_robin", "least_loaded"
  batch_size: 64
  max_queue_size: 10000
  metrics_interval: 1000

qos:
  rules:
    - name: "voip"
      priority: 7
      match_criteria:
        source_ip: "192.168.1.100"
        dest_ip: "192.168.1.200"
        protocol: "UDP"
        port_range:
          start: 10000
          end: 20000
        dscp: 46
      action:
        link_preference: ["eth0"]
        bandwidth_limit: 1000000  # 1 Mbps
        latency_threshold: 20     # 20ms

    - name: "video"
      priority: 6
      match_criteria:
        protocol: "UDP"
        port_range:
          start: 20000
          end: 30000
      action:
        link_preference: ["eth0", "eth1"]
        bandwidth_limit: 5000000  # 5 Mbps
        latency_threshold: 50     # 50ms

links:
  - name: "eth0"
    interface: "eth0"
    weight: 1.0
    max_bandwidth: 100000000  # 100 Mbps
    min_latency: 10
    failover_group: "primary"

  - name: "eth1"
    interface: "eth1"
    weight: 0.8
    max_bandwidth: 50000000   # 50 Mbps
    min_latency: 15
    failover_group: "backup"

failover:
  enabled: true
  health_check_interval: 5000  # 5 seconds
  failover_threshold: 3        # 3 consecutive failures
  recovery_threshold: 5        # 5 consecutive successes
```

### QoS Rule Matching

The packet scheduler supports the following match criteria:

- **source_ip**: Source IP address (CIDR notation supported)
- **dest_ip**: Destination IP address (CIDR notation supported)
- **protocol**: IP protocol (TCP, UDP, ICMP, etc.)
- **port_range**: Port range for TCP/UDP
- **dscp**: Differentiated Services Code Point

### Link Selection Algorithms

1. **weighted_round_robin**: Selects links based on weights and current health
2. **round_robin**: Simple round-robin selection
3. **least_loaded**: Selects the link with lowest utilization

## Underlay Manager Configuration

```yaml
interfaces:
  - name: "eth0"
    enabled: true
    probe_interval: 5000        # 5 seconds
    icmp_enabled: true
    udp_enabled: true
    bandwidth_test_enabled: true

  - name: "eth1"
    enabled: true
    probe_interval: 5000
    icmp_enabled: true
    udp_enabled: true
    bandwidth_test_enabled: true

probes:
  icmp_timeout: 1000            # 1 second
  udp_timeout: 2000             # 2 seconds
  bandwidth_test_duration: 10000 # 10 seconds
  packet_size: 1500
  probe_count: 10

server:
  grpc_port: 9093
  metrics_interval: 1000
  max_connections: 100
```

### Probe Types

1. **ICMP Probes**: Measure basic connectivity and latency
2. **UDP Probes**: Measure jitter and packet loss
3. **Bandwidth Tests**: Measure available bandwidth

## FEC Engine Configuration

The FEC engine supports two types of forward error correction:

### Reed-Solomon FEC

```yaml
fec:
  type: "reed-solomon"
  data_shards: 4
  parity_shards: 2
  block_size: 4096
  enable_optimization: true
```

### XOR-based FEC

```yaml
fec:
  type: "xor"
  data_shards: 4
  parity_shards: 1
  block_size: 4096
```

### FEC Parameters

- **data_shards**: Number of data packets
- **parity_shards**: Number of parity packets
- **block_size**: Size of each FEC block in bytes
- **enable_optimization**: Enable performance optimizations

## Reassembly Engine Configuration

```yaml
reassembly:
  jitter_buffer_size: 1000      # Number of packets
  max_reorder_delay: 100        # Maximum reorder delay in ms
  tun_interface: "sdwan0"
  encryption:
    enabled: true
    algorithm: "aes-256-gcm"
    key_file: "/etc/sdwan/keys/encryption.key"
  
  compression:
    enabled: true
    algorithm: "lz4"
    level: 1
```

### Jitter Buffer Configuration

- **jitter_buffer_size**: Maximum number of packets in buffer
- **max_reorder_delay**: Maximum delay for packet reordering
- **tun_interface**: TUN interface name for packet delivery

## Controller Configuration

```yaml
server:
  http_port: 8080
  grpc_port: 9091
  metrics_port: 9091

etcd:
  endpoints:
    - "http://localhost:2379"
  dial_timeout: 5000
  request_timeout: 10000

policy:
  default_qos: "best_effort"
  failover_enabled: true
  load_balancing: "weighted"

monitoring:
  prometheus_endpoint: "http://localhost:9090"
  grafana_endpoint: "http://localhost:3000"
  alerting:
    enabled: true
    webhook_url: "http://localhost:8080/alerts"
```

## Device Agent Configuration

```yaml
site_id: "site-a"
controller_endpoint: "http://localhost:8080"
log_level: "info"
metrics_port: 9092

components:
  packet_scheduler:
    enabled: true
    config_file: "/etc/sdwan/scheduler.yml"
  
  underlay_manager:
    enabled: true
    config_file: "/etc/sdwan/underlay.yml"
  
  fec_engine:
    enabled: true
    type: "reed-solomon"
    data_shards: 4
    parity_shards: 2
  
  reassembly_engine:
    enabled: true
    jitter_buffer_size: 1000
    tun_interface: "sdwan0"

telemetry:
  collection_interval: 30       # 30 seconds
  retention_days: 7
  compression: true

failover:
  enabled: true
  health_check_interval: 5000
  failover_threshold: 3
  recovery_threshold: 5
```

## System Configuration

### Network Configuration

```bash
# Create TUN interface
sudo ip tuntap add mode tun sdwan0
sudo ip link set sdwan0 up
sudo ip addr add 10.0.0.1/24 dev sdwan0

# Setup routing
sudo ip route add 10.0.0.0/24 dev sdwan0

# Setup iptables
sudo iptables -t nat -A POSTROUTING -o sdwan0 -j MASQUERADE
sudo iptables -A FORWARD -i sdwan0 -j ACCEPT
sudo iptables -A FORWARD -o sdwan0 -j ACCEPT
```

### Systemd Services

The SD-WAN components are managed as systemd services:

```bash
# Start all services
sudo systemctl start sdwan-*

# Check status
sudo systemctl status sdwan-*

# View logs
sudo journalctl -u sdwan-packet-scheduler -f
sudo journalctl -u sdwan-underlay-manager -f
sudo journalctl -u sdwan-fec-engine -f
sudo journalctl -u sdwan-reassembly-engine -f
sudo journalctl -u sdwan-device-agent -f
```

### Logging Configuration

Log levels can be configured for each component:

- **debug**: Detailed debug information
- **info**: General information (default)
- **warn**: Warning messages
- **error**: Error messages only

### Performance Tuning

For optimal performance, consider these settings:

```bash
# Increase file descriptor limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Enable huge pages for DPDK
echo 1024 | sudo tee /proc/sys/vm/nr_hugepages

# Optimize network settings
echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_rmem = 4096 87380 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_wmem = 4096 65536 134217728' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## Security Configuration

### Encryption

All SD-WAN traffic is encrypted using AES-256-GCM:

```yaml
encryption:
  algorithm: "aes-256-gcm"
  key_rotation_interval: 86400  # 24 hours
  key_file: "/etc/sdwan/keys/encryption.key"
```

### Authentication

Components authenticate using mutual TLS:

```yaml
tls:
  enabled: true
  cert_file: "/etc/sdwan/certs/server.crt"
  key_file: "/etc/sdwan/certs/server.key"
  ca_file: "/etc/sdwan/certs/ca.crt"
```

### Access Control

```yaml
access_control:
  allowed_ips:
    - "192.168.1.0/24"
    - "10.0.0.0/8"
  require_authentication: true
  max_connections_per_ip: 10
```

## Monitoring and Alerting

### Prometheus Metrics

Key metrics to monitor:

- **sdwan_packets_scheduled_total**: Total packets scheduled
- **sdwan_link_latency_ms**: Link latency in milliseconds
- **sdwan_link_bandwidth_mbps**: Link bandwidth in Mbps
- **sdwan_packet_loss_ratio**: Packet loss ratio
- **sdwan_failover_events_total**: Number of failover events

### Grafana Dashboards

Pre-configured dashboards are available for:

- Link performance monitoring
- QoS rule effectiveness
- Failover events
- System resource usage
- Network topology

### Alerting Rules

```yaml
alerts:
  - name: "High Latency"
    condition: "sdwan_link_latency_ms > 100"
    duration: "5m"
    
  - name: "High Packet Loss"
    condition: "sdwan_packet_loss_ratio > 0.05"
    duration: "2m"
    
  - name: "Link Down"
    condition: "up == 0"
    duration: "1m"
```

## Troubleshooting

### Common Issues

1. **TUN interface not working**: Check kernel module loading
2. **High latency**: Verify link quality and QoS settings
3. **Packet loss**: Check FEC configuration and link health
4. **Service not starting**: Check configuration files and permissions

### Debug Commands

```bash
# Check TUN interface
ip link show sdwan0

# Check routing
ip route show

# Check iptables
sudo iptables -L -n -v

# Check service logs
sudo journalctl -u sdwan-* --since "1 hour ago"

# Test connectivity
ping -I sdwan0 10.0.0.1

# Monitor traffic
sudo tcpdump -i sdwan0 -w capture.pcap
```

### Performance Analysis

```bash
# Monitor system resources
htop
iotop
iftop

# Analyze network performance
iperf3 -c <remote_host>
mtr <remote_host>

# Check kernel statistics
cat /proc/net/dev
cat /proc/net/snmp
``` 