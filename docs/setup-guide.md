# SD-WAN Setup Guide

This guide provides step-by-step instructions for setting up the SD-WAN overlay system on Ubuntu Server 20.04+ for a two-VM proof of concept.

## Prerequisites

- Two Ubuntu Server 20.04+ VMs with at least 2GB RAM and 2 CPU cores each
- Network connectivity between VMs
- Root or sudo access on both VMs
- Internet access for downloading dependencies

## VM Setup

### VM1 (Site A)
- **Hostname**: site-a
- **IP Address**: 192.168.1.10
- **WAN Interfaces**: eth0, eth1
- **Role**: Edge device

### VM2 (Site B)
- **Hostname**: site-b
- **IP Address**: 192.168.1.11
- **WAN Interfaces**: eth0, eth1
- **Role**: Edge device

## Step 1: Initial System Setup

### On both VMs, run the setup script:

```bash
# Clone the repository
git clone <repository-url>
cd speedfusion-like

# Make scripts executable
chmod +x scripts/*.sh

# Run the setup script
./scripts/setup.sh
```

This script will:
- Update the system
- Install all required dependencies
- Set up Rust, Go, and Python toolchains
- Install development tools
- Configure kernel modules for TUN/TAP
- Create necessary directories

## Step 2: Build All Components

### On both VMs:

```bash
# Build all components
make build

# Verify builds
ls -la bin/
ls -la rust/packet-scheduler/target/release/
ls -la rust/underlay-manager/target/release/
ls -la cpp/fec-engine/bin/
ls -la cpp/reassembly-engine/bin/
```

## Step 3: Deploy Edge Devices

### On VM1 (Site A):

```bash
# Deploy as site-a
./scripts/deploy-edge.sh --site-id=site-a --wan-interfaces=eth0,eth1
```

### On VM2 (Site B):

```bash
# Deploy as site-b
./scripts/deploy-edge.sh --site-id=site-b --wan-interfaces=eth0,eth1
```

## Step 4: Start Management Plane

### On VM1 (management server):

```bash
# Start the management plane services
docker-compose up -d

# Verify services are running
docker-compose ps

# Check service logs
docker-compose logs -f
```

## Step 5: Start Edge Services

### On both VMs:

```bash
# Start all SD-WAN services
sudo systemctl start sdwan-*

# Check service status
sudo systemctl status sdwan-*

# View logs
sudo journalctl -u sdwan-packet-scheduler -f
sudo journalctl -u sdwan-underlay-manager -f
sudo journalctl -u sdwan-fec-engine -f
sudo journalctl -u sdwan-reassembly-engine -f
sudo journalctl -u sdwan-device-agent -f
```

## Step 6: Verify Configuration

### Check TUN interface:

```bash
# Verify TUN interface exists
ip link show sdwan0

# Check IP configuration
ip addr show sdwan0

# Test connectivity
ping -I sdwan0 10.0.0.1
```

### Check routing:

```bash
# View routing table
ip route show

# Check iptables rules
sudo iptables -L -n -v
```

## Step 7: Test Connectivity

### Run the connectivity test:

```bash
# Test basic connectivity
./scripts/test-connectivity.sh
```

This will test:
- Basic network connectivity
- SD-WAN tunnel connectivity
- Service health
- Metrics endpoints
- Network performance
- Failover functionality

## Step 8: Access Monitoring

### Access Grafana:
- URL: http://192.168.1.10:3000
- Username: admin
- Password: admin

### Access Prometheus:
- URL: http://192.168.1.10:9090

### Access Etcd:
- URL: http://192.168.1.10:2379

## Step 9: Configure Network Simulation

### For testing with network impairments:

```bash
# Install netem tools
sudo apt-get install iproute2

# Create network namespaces for testing
sudo ip netns add test-ns1
sudo ip netns add test-ns2

# Simulate network conditions
sudo tc qdisc add dev eth0 root netem delay 50ms 10ms loss 1%
sudo tc qdisc add dev eth1 root netem delay 100ms 20ms loss 2%
```

## Step 10: Performance Testing

### Run performance benchmarks:

```bash
# Run all benchmarks
make benchmark

# Test specific components
cargo bench --manifest-path rust/packet-scheduler/Cargo.toml
cargo bench --manifest-path rust/underlay-manager/Cargo.toml
```

## Troubleshooting

### Common Issues and Solutions

#### 1. TUN Interface Not Working

```bash
# Check if tun module is loaded
lsmod | grep tun

# Load tun module if not loaded
sudo modprobe tun

# Check device permissions
ls -la /dev/net/tun
```

#### 2. Services Not Starting

```bash
# Check service status
sudo systemctl status sdwan-*

# View detailed logs
sudo journalctl -u sdwan-packet-scheduler --since "10 minutes ago"

# Check configuration files
sudo cat /etc/sdwan/scheduler.yml
sudo cat /etc/sdwan/underlay.yml
```

#### 3. Network Connectivity Issues

```bash
# Check network interfaces
ip addr show

# Test basic connectivity
ping -c 3 8.8.8.8

# Check routing
ip route show

# Test DNS resolution
nslookup google.com
```

#### 4. Docker Issues

```bash
# Check Docker status
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Check Docker logs
sudo journalctl -u docker -f
```

#### 5. Permission Issues

```bash
# Check file permissions
ls -la /usr/local/bin/sdwan-*

# Fix permissions if needed
sudo chmod +x /usr/local/bin/sdwan-*

# Check user groups
groups $USER
```

### Debug Commands

```bash
# Monitor system resources
htop
iotop
iftop

# Monitor network traffic
sudo tcpdump -i any -w capture.pcap

# Check kernel messages
dmesg | tail -20

# Monitor system calls
sudo strace -p <pid>
```

### Performance Optimization

```bash
# Increase file descriptor limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize network settings
echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Enable huge pages
echo 1024 | sudo tee /proc/sys/vm/nr_hugepages
```

## Monitoring and Alerting

### Key Metrics to Monitor

1. **Link Performance**:
   - Latency (should be < 100ms)
   - Jitter (should be < 20ms)
   - Packet loss (should be < 1%)
   - Bandwidth utilization

2. **System Resources**:
   - CPU usage
   - Memory usage
   - Disk I/O
   - Network I/O

3. **SD-WAN Metrics**:
   - Packets scheduled per second
   - FEC recovery rate
   - Failover events
   - QoS rule matches

### Setting Up Alerts

```bash
# Create alerting rules
cat > /etc/prometheus/alerts.yml << EOF
groups:
  - name: sdwan_alerts
    rules:
      - alert: HighLatency
        expr: sdwan_link_latency_ms > 100
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency detected"
          
      - alert: HighPacketLoss
        expr: sdwan_packet_loss_ratio > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High packet loss detected"
EOF
```

## Scaling the Deployment

### Adding More Sites

1. **Deploy additional edge devices**:
   ```bash
   ./scripts/deploy-edge.sh --site-id=site-c --wan-interfaces=eth0,eth1
   ```

2. **Update controller configuration**:
   ```yaml
   sites:
     - id: site-a
       ip: 192.168.1.10
     - id: site-b
       ip: 192.168.1.11
     - id: site-c
       ip: 192.168.1.12
   ```

3. **Configure site-to-site policies**:
   ```yaml
   policies:
     - name: site-a-to-site-b
       source: site-a
       destination: site-b
       qos: voip
     - name: site-a-to-site-c
       source: site-a
       destination: site-c
       qos: best-effort
   ```

### High Availability

1. **Deploy multiple controllers**:
   ```bash
   # Start controller cluster
   docker-compose -f docker-compose.ha.yml up -d
   ```

2. **Configure load balancing**:
   ```yaml
   load_balancer:
     algorithm: round_robin
     health_check_interval: 30s
     failover_threshold: 3
   ```

## Security Considerations

### Network Security

1. **Firewall Configuration**:
   ```bash
   # Allow SD-WAN traffic
   sudo ufw allow 9090:9093/tcp
   sudo ufw allow 2379/tcp
   sudo ufw allow 3000/tcp
   ```

2. **Encryption**:
   - All SD-WAN traffic is encrypted with AES-256-GCM
   - Keys are rotated every 24 hours
   - TLS is used for management traffic

3. **Access Control**:
   - API endpoints require authentication
   - IP-based access control
   - Rate limiting on all endpoints

### System Security

1. **Regular Updates**:
   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   ```

2. **Security Monitoring**:
   ```bash
   # Install security tools
   sudo apt-get install fail2ban rkhunter
   
   # Configure fail2ban
   sudo systemctl enable fail2ban
   sudo systemctl start fail2ban
   ```

## Backup and Recovery

### Configuration Backup

```bash
# Backup configuration
sudo tar -czf sdwan-config-$(date +%Y%m%d).tar.gz /etc/sdwan/

# Backup certificates and keys
sudo tar -czf sdwan-keys-$(date +%Y%m%d).tar.gz /etc/sdwan/keys/ /etc/sdwan/certs/
```

### Disaster Recovery

1. **Restore configuration**:
   ```bash
   sudo tar -xzf sdwan-config-YYYYMMDD.tar.gz -C /
   sudo tar -xzf sdwan-keys-YYYYMMDD.tar.gz -C /
   ```

2. **Restart services**:
   ```bash
   sudo systemctl restart sdwan-*
   ```

## Support and Maintenance

### Log Management

```bash
# Configure log rotation
sudo cat > /etc/logrotate.d/sdwan << EOF
/var/log/sdwan/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF
```

### Performance Monitoring

```bash
# Install monitoring tools
sudo apt-get install htop iotop iftop nethogs

# Monitor system performance
htop
iotop
iftop
```

### Regular Maintenance

1. **Weekly**:
   - Check service logs
   - Monitor system resources
   - Review alert history

2. **Monthly**:
   - Update system packages
   - Review security logs
   - Test failover procedures

3. **Quarterly**:
   - Performance testing
   - Security audit
   - Configuration review

## Conclusion

This setup provides a complete SD-WAN overlay system with:
- Per-packet load balancing
- Real-time link monitoring
- Forward error correction
- Automatic failover
- Comprehensive monitoring
- Zero-touch provisioning

The system is production-ready and can be scaled to support multiple sites and high availability deployments. 