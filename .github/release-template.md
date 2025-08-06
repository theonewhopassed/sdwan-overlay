# SD-WAN Overlay v{{VERSION}}

## 🚀 What's New

### ✨ Features
- [ ] New feature 1
- [ ] New feature 2
- [ ] New feature 3

### 🔧 Improvements
- [ ] Performance improvements
- [ ] Better error handling
- [ ] Enhanced monitoring

### 🐛 Bug Fixes
- [ ] Fixed issue 1
- [ ] Fixed issue 2
- [ ] Fixed issue 3

### 🔒 Security
- [ ] Security update 1
- [ ] Security update 2

## 📦 Installation

### Quick Start
```bash
# Download the latest release
wget https://github.com/theonewhopassed/sdwan-overlay/releases/download/v{{VERSION}}/sdwan-overlay-{{VERSION}}-linux-amd64.tar.gz

# Extract and install
tar -xzf sdwan-overlay-{{VERSION}}-linux-amd64.tar.gz
cd sdwan-overlay-{{VERSION}}-linux-amd64

# Install as controller
sudo ./install.sh --type controller

# Or install as edge device
sudo ./install.sh --type edge --controller 192.168.1.100 --site-id branch-1
```

### Docker Installation
```bash
# Pull Docker images
docker pull theonewhopassed/sdwan-controller:{{VERSION}}
docker pull theonewhopassed/sdwan-underlay-manager:{{VERSION}}
docker pull theonewhopassed/sdwan-packet-scheduler:{{VERSION}}
docker pull theonewhopassed/sdwan-fec-engine:{{VERSION}}
docker pull theonewhopassed/sdwan-reassembly-engine:{{VERSION}}
docker pull theonewhopassed/sdwan-device-agent:{{VERSION}}

# Run with docker-compose
docker-compose up -d
```

## 📋 System Requirements

- **OS**: Ubuntu 20.04+ or compatible Linux distribution
- **Architecture**: AMD64, ARM64
- **Memory**: 2GB RAM minimum, 4GB recommended
- **Storage**: 10GB free space
- **Network**: Multiple network interfaces for WAN bonding

## 🔧 Configuration

### Controller Configuration
```yaml
# /opt/sdwan/config/controller/controller.yml
server:
  port: 8080
  host: 0.0.0.0

etcd:
  endpoints: ["http://localhost:2379"]

logging:
  level: info
```

### Edge Device Configuration
```yaml
# /opt/sdwan/config/device-agent/config.yml
site_id: branch-office-1
controller_ip: 192.168.1.100
prometheus_port: 9092
log_level: info
```

## 📊 Monitoring

### Access Points
- **Grafana Dashboard**: http://VM_IP:3000 (admin/admin)
- **Prometheus Metrics**: http://VM_IP:9090
- **Management API**: http://VM_IP:8080
- **Etcd Store**: http://VM_IP:2379

### Key Metrics
- Link latency and packet loss
- Bandwidth utilization
- FEC statistics
- Service health status

## 🛠️ Troubleshooting

### Common Issues
1. **Service won't start**: Check logs with `sudo journalctl -u sdwan-*`
2. **Network issues**: Verify TUN interface with `ip addr show sdwan*`
3. **Permission errors**: Fix with `sudo chown -R sdwan:sdwan /opt/sdwan/`

### Support
- **Documentation**: [docs/COMPILED_DEPLOYMENT.md](docs/COMPILED_DEPLOYMENT.md)
- **Issues**: [GitHub Issues](https://github.com/theonewhopassed/sdwan-overlay/issues)
- **Discussions**: [GitHub Discussions](https://github.com/theonewhopassed/sdwan-overlay/discussions)

## 🔄 Migration from Previous Versions

### From v1.0.0 to v{{VERSION}}
```bash
# Stop services
sudo systemctl stop sdwan-*

# Backup configuration
sudo cp -r /opt/sdwan/config /opt/sdwan/config.backup

# Install new version
tar -xzf sdwan-overlay-{{VERSION}}-linux-amd64.tar.gz
cd sdwan-overlay-{{VERSION}}-linux-amd64
sudo ./install.sh --type all

# Restart services
sudo systemctl start sdwan-*
```

## 📝 Changelog

### Breaking Changes
- [ ] Breaking change 1
- [ ] Breaking change 2

### Deprecations
- [ ] Deprecated feature 1
- [ ] Deprecated feature 2

## 🙏 Contributors

Thanks to all contributors who helped with this release:

- [Contributor 1](https://github.com/contributor1)
- [Contributor 2](https://github.com/contributor2)
- [Contributor 3](https://github.com/contributor3)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Download**: [sdwan-overlay-{{VERSION}}-linux-amd64.tar.gz](https://github.com/theonewhopassed/sdwan-overlay/releases/download/v{{VERSION}}/sdwan-overlay-{{VERSION}}-linux-amd64.tar.gz)

**Checksum**: `sha256:{{SHA256}}`

