# SD-WAN Overlay Compiled Deployment Guide

This guide explains how to build and deploy the SD-WAN overlay system as compiled binaries for easy deployment across multiple VMs.

## 🏗️ **Build System Overview**

The compiled deployment system creates:
- **Standalone binaries** for all components
- **Systemd service files** for automatic startup
- **Installation scripts** for easy deployment
- **Docker images** for containerized deployment
- **Multi-platform support** (Linux AMD64, ARM64)

## 🚀 **Building Release Packages**

### **Prerequisites for Building**
```bash
# Install build dependencies
sudo apt update
sudo apt install -y \
    build-essential \
    git \
    curl \
    docker.io \
    docker-compose \
    rustc \
    cargo \
    golang-go \
    python3 \
    python3-pip \
    python3-venv
```

### **Build All Platforms**
```bash
# Build all release packages
make build-release

# Or build specific platform
make build-linux-amd64
make build-linux-arm64
```

### **Manual Build**
```bash
# Set version and build
VERSION=1.0.0 ./scripts/build-release.sh
```

## 📦 **Generated Packages**

After building, you'll find packages in the `dist/` directory:

```
dist/
├── sdwan-overlay-1.0.0-linux-amd64.tar.gz    # AMD64 binaries
├── sdwan-overlay-1.0.0-linux-arm64.tar.gz    # ARM64 binaries
├── sdwan-overlay-1.0.0-docker.tar.gz         # Docker deployment
└── SHA256SUMS                                 # Checksums
```

## 🖥️ **Deployment Options**

### **Option 1: Central Controller Only**

**Build the package:**
```bash
make build-linux-amd64
```

**Deploy to VM:**
```bash
# Extract package
tar -xzf dist/sdwan-overlay-1.0.0-linux-amd64.tar.gz
cd sdwan-overlay-1.0.0-linux-amd64

# Install as controller
sudo ./install.sh --type controller
```

**What you get:**
- Grafana dashboard (http://VM_IP:3000)
- Prometheus metrics (http://VM_IP:9090)
- Management API (http://VM_IP:8080)
- Etcd configuration store

### **Option 2: Edge Device Only**

**Deploy to VM:**
```bash
# Extract and install
tar -xzf dist/sdwan-overlay-1.0.0-linux-amd64.tar.gz
cd sdwan-overlay-1.0.0-linux-amd64

# Install as edge device
sudo ./install.sh --type edge \
    --controller 192.168.1.100 \
    --site-id branch-office-1 \
    --interfaces eth0,eth1 \
    --port 9092
```

**What you get:**
- TUN interface (`sdwan-hostname`)
- Multi-WAN bonding
- Local metrics (http://VM_IP:9092)
- Connection to central controller

### **Option 3: All-in-One (Controller + Edge)**

**Deploy to VM:**
```bash
# Extract and install
tar -xzf dist/sdwan-overlay-1.0.0-linux-amd64.tar.gz
cd sdwan-overlay-1.0.0-linux-amd64

# Install everything
sudo ./install.sh --type all
```

**What you get:**
- Complete SD-WAN system on single VM
- Controller + edge device functionality
- All dashboards and interfaces

## 🔧 **Installation Script Options**

```bash
./install.sh [OPTIONS]

Options:
  -t, --type TYPE       Installation type: controller, edge, or all (default: all)
  -c, --controller IP   Controller IP for edge devices
  -s, --site-id ID      Site ID for edge devices
  -i, --interfaces IF   Network interfaces (comma-separated)
  -p, --port PORT       Prometheus port (default: 9092)
  -h, --help           Show this help message

Examples:
  ./install.sh --type controller                    # Install as central controller
  ./install.sh --type edge --controller 192.168.1.100 --site-id branch-1
  ./install.sh --type all                          # Install controller + edge
```

## 🐳 **Docker Deployment**

### **Build Docker Package**
```bash
make build-release
```

### **Deploy with Docker**
```bash
# Extract Docker package
tar -xzf dist/sdwan-overlay-1.0.0-docker.tar.gz
cd sdwan-overlay-1.0.0-docker

# Install and start
sudo ./install-docker.sh
```

## 🌐 **Multi-VM Deployment Example**

### **VM1 (Central Controller)**
```bash
# Download and extract
wget https://github.com/theonewhopassed/sdwan-overlay/releases/download/v1.0.0/sdwan-overlay-1.0.0-linux-amd64.tar.gz
tar -xzf sdwan-overlay-1.0.0-linux-amd64.tar.gz
cd sdwan-overlay-1.0.0-linux-amd64

# Install as controller
sudo ./install.sh --type controller
```

### **VM2 (Edge Device)**
```bash
# Download and extract
wget https://github.com/theonewhopassed/sdwan-overlay/releases/download/v1.0.0/sdwan-overlay-1.0.0-linux-amd64.tar.gz
tar -xzf sdwan-overlay-1.0.0-linux-amd64.tar.gz
cd sdwan-overlay-1.0.0-linux-amd64

# Install as edge device
sudo ./install.sh --type edge \
    --controller 192.168.1.100 \
    --site-id branch-office-1 \
    --interfaces eth0,eth1
```

## 🔍 **Verification Commands**

### **Check Services**
```bash
# Check all SD-WAN services
sudo systemctl status sdwan-*

# Check specific service
sudo systemctl status sdwan-controller
sudo systemctl status sdwan-underlay-manager
```

### **Check Network**
```bash
# Check TUN interface
ip addr show sdwan*

# Check routing
ip route show

# Test connectivity
ping 8.8.8.8 -I sdwan-hostname
```

### **Check Logs**
```bash
# View service logs
sudo journalctl -u sdwan-controller -f
sudo journalctl -u sdwan-underlay-manager -f

# View recent logs
sudo journalctl -u sdwan-* --since "5 minutes ago"
```

### **Check Metrics**
```bash
# Controller metrics
curl http://localhost:8080/api/health

# Edge device metrics
curl http://localhost:9092/metrics

# Prometheus metrics
curl http://localhost:9090/metrics
```

## 🛠️ **Troubleshooting**

### **Service Won't Start**
```bash
# Check service status
sudo systemctl status sdwan-controller

# View detailed logs
sudo journalctl -u sdwan-controller --no-pager -l

# Check configuration
sudo cat /opt/sdwan/config/controller/controller.yml
```

### **Network Issues**
```bash
# Check TUN interface
ip addr show sdwan*

# Check iptables rules
sudo iptables -t nat -L

# Enable IP forwarding
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
```

### **Permission Issues**
```bash
# Check file permissions
ls -la /opt/sdwan/

# Fix permissions
sudo chown -R sdwan:sdwan /opt/sdwan/
sudo chmod +x /opt/sdwan/*
```

## 📊 **Monitoring**

### **Access Dashboards**
- **Grafana**: http://VM_IP:3000 (admin/admin)
- **Prometheus**: http://VM_IP:9090
- **Management API**: http://VM_IP:8080

### **Key Metrics**
- Link latency and packet loss
- Bandwidth utilization
- FEC statistics
- Service health status

## 🔒 **Security Considerations**

### **Firewall Configuration**
```bash
# Allow required ports
sudo ufw allow 3000/tcp  # Grafana
sudo ufw allow 9090/tcp  # Prometheus
sudo ufw allow 8080/tcp  # Management API
sudo ufw allow 2379/tcp  # Etcd
```

### **User Permissions**
```bash
# The installer creates a dedicated user
sudo id sdwan

# Services run as non-root user
sudo systemctl show sdwan-controller | grep User
```

## 🚀 **Performance Optimization**

### **System Tuning**
```bash
# Increase file descriptors
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize network settings
echo "net.core.rmem_max = 16777216" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### **Resource Limits**
```bash
# Check resource usage
sudo systemctl show sdwan-controller | grep -E "(Memory|CPU)"

# Adjust limits in service files if needed
sudo systemctl edit sdwan-controller
```

## 📝 **Configuration**

### **Controller Configuration**
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

### **Edge Device Configuration**
```yaml
# /opt/sdwan/config/device-agent/config.yml
site_id: branch-office-1
controller_ip: 192.168.1.100
prometheus_port: 9092
log_level: info
```

## 🔄 **Updates and Maintenance**

### **Update System**
```bash
# Stop services
sudo systemctl stop sdwan-*

# Backup configuration
sudo cp -r /opt/sdwan/config /opt/sdwan/config.backup

# Extract new version
tar -xzf sdwan-overlay-1.1.0-linux-amd64.tar.gz
cd sdwan-overlay-1.1.0-linux-amd64

# Install update
sudo ./install.sh --type all

# Restart services
sudo systemctl start sdwan-*
```

### **Backup and Restore**
```bash
# Backup
sudo tar -czf sdwan-backup-$(date +%Y%m%d).tar.gz /opt/sdwan/

# Restore
sudo systemctl stop sdwan-*
sudo tar -xzf sdwan-backup-20240101.tar.gz -C /
sudo systemctl start sdwan-*
```

## 📞 **Support**

For issues and questions:
- Check service logs: `sudo journalctl -u sdwan-*`
- Verify configuration: `/opt/sdwan/config/`
- Test connectivity: `ping 8.8.8.8 -I sdwan-hostname`
- Check metrics: `curl http://localhost:9090/metrics`
