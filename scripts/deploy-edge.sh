#!/bin/bash

# SD-WAN Edge Device Deployment Script
# Usage: ./scripts/deploy-edge.sh <edge-id> <controller-ip> [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
EDGE_ID=""
CONTROLLER_IP=""
DEPLOY_MODE="docker"
NETWORK_INTERFACES="eth0,eth1"
SITE_ID="edge-$(hostname)"
PROMETHEUS_PORT="9092"
LOG_LEVEL="info"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "SD-WAN Edge Device Deployment Script"
    echo ""
    echo "Usage: $0 <edge-id> <controller-ip> [options]"
    echo ""
    echo "Arguments:"
    echo "  edge-id        Unique identifier for this edge device"
    echo "  controller-ip  IP address of the central controller"
    echo ""
    echo "Options:"
    echo "  --mode <mode>              Deployment mode: docker|native (default: docker)"
    echo "  --interfaces <ifaces>      Network interfaces to monitor (default: eth0,eth1)"
    echo "  --site-id <site>           Site identifier (default: edge-$(hostname))"
    echo "  --prometheus-port <port>   Prometheus metrics port (default: 9092)"
    echo "  --log-level <level>        Log level: debug|info|warn|error (default: info)"
    echo "  --help                     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 edge-01 192.168.1.100"
    echo "  $0 edge-02 192.168.1.100 --mode native --interfaces eth0,eth1,wlan0"
    echo "  $0 edge-03 10.0.0.50 --site-id branch-office --log-level debug"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            DEPLOY_MODE="$2"
            shift 2
            ;;
        --interfaces)
            NETWORK_INTERFACES="$2"
            shift 2
            ;;
        --site-id)
            SITE_ID="$2"
            shift 2
            ;;
        --prometheus-port)
            PROMETHEUS_PORT="$2"
            shift 2
            ;;
        --log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            if [[ -z "$EDGE_ID" ]]; then
                EDGE_ID="$1"
            elif [[ -z "$CONTROLLER_IP" ]]; then
                CONTROLLER_IP="$1"
            else
                print_error "Unknown argument: $1"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$EDGE_ID" || -z "$CONTROLLER_IP" ]]; then
    print_error "Missing required arguments"
    show_usage
    exit 1
fi

print_status "Starting SD-WAN edge device deployment..."
print_status "Edge ID: $EDGE_ID"
print_status "Controller IP: $CONTROLLER_IP"
print_status "Deployment Mode: $DEPLOY_MODE"
print_status "Network Interfaces: $NETWORK_INTERFACES"
print_status "Site ID: $SITE_ID"

# Check if running as root for native mode
if [[ "$DEPLOY_MODE" == "native" && "$EUID" -ne 0 ]]; then
    print_error "Native mode requires root privileges"
    exit 1
fi

# Create deployment directory
DEPLOY_DIR="/opt/sdwan-edge-$EDGE_ID"
print_status "Creating deployment directory: $DEPLOY_DIR"
sudo mkdir -p "$DEPLOY_DIR"
sudo mkdir -p "$DEPLOY_DIR/config"
sudo mkdir -p "$DEPLOY_DIR/logs"
sudo mkdir -p "$DEPLOY_DIR/data"

# Generate edge-specific configuration
print_status "Generating edge device configuration..."

# Device Agent configuration
cat > /tmp/device-agent-config.yml << EOF
site_id: "$SITE_ID"
controller_endpoint: "http://$CONTROLLER_IP:8080"
etcd_endpoints: "http://$CONTROLLER_IP:2379"
prometheus_port: $PROMETHEUS_PORT
log_level: $LOG_LEVEL

metrics:
  collection_interval: 30s
  enabled_metrics:
    - cpu_usage
    - memory_usage
    - disk_usage
    - network_interfaces
    - system_load
    - uptime

telemetry:
  enabled: true
  interval: 60s
  endpoint: "http://$CONTROLLER_IP:8080/api/v1/telemetry"

health_check:
  enabled: true
  interval: 30s
  timeout: 10s
EOF

# Underlay Manager configuration
cat > /tmp/underlay-manager-config.yml << EOF
interfaces: [$NETWORK_INTERFACES]
probe_interval: 30s
server_port: 9093
log_level: $LOG_LEVEL

probe_settings:
  icmp_timeout: 5s
  udp_timeout: 3s
  bandwidth_test_duration: 10s
  packet_loss_threshold: 0.05
  latency_threshold: 100ms

metrics:
  retention_period: 1h
  aggregation_interval: 30s
EOF

# Packet Scheduler configuration
cat > /tmp/packet-scheduler-config.yml << EOF
scheduler:
  algorithm: "weighted-round-robin"
  update_interval: 10s
  health_check_interval: 30s

qos_rules:
  - name: "voice"
    priority: 1
    match:
      protocol: "udp"
      port_range: "10000-20000"
    action:
      link_preference: "lowest_latency"
      bandwidth_limit: "1Mbps"
      latency_threshold: "50ms"

  - name: "video"
    priority: 2
    match:
      protocol: "udp"
      port_range: "20001-30000"
    action:
      link_preference: "highest_bandwidth"
      bandwidth_limit: "5Mbps"

  - name: "data"
    priority: 3
    match:
      protocol: "tcp"
    action:
      link_preference: "balanced"
      bandwidth_limit: "10Mbps"

links:
  - id: "primary"
    name: "Primary Link"
    weight: 70
    health_check:
      enabled: true
      interval: 30s
      timeout: 5s

  - id: "backup"
    name: "Backup Link"
    weight: 30
    health_check:
      enabled: true
      interval: 30s
      timeout: 5s

failover:
  enabled: true
  mode: "make-before-break"
  timeout: 5s
  retry_interval: 30s
  max_retries: 3

log_level: $LOG_LEVEL
EOF

# Copy configurations
sudo cp /tmp/device-agent-config.yml "$DEPLOY_DIR/config/device-agent.yml"
sudo cp /tmp/underlay-manager-config.yml "$DEPLOY_DIR/config/underlay-manager.yml"
sudo cp /tmp/packet-scheduler-config.yml "$DEPLOY_DIR/config/packet-scheduler.yml"

# Create edge-specific docker-compose.yml
cat > /tmp/edge-compose.yml << EOF
version: '3.8'

services:
  # Device Agent (Python)
  device-agent:
    image: sdwan-overlay_device-agent:latest
    container_name: sdwan-edge-$EDGE_ID-device-agent
    ports:
      - "$PROMETHEUS_PORT:9092"
    environment:
      - CONTROLLER_ENDPOINT=http://$CONTROLLER_IP:8080
      - ETCD_ENDPOINTS=http://$CONTROLLER_IP:2379
      - SITE_ID=$SITE_ID
      - LOG_LEVEL=$LOG_LEVEL
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - $DEPLOY_DIR/config/device-agent.yml:/app/config/config.yml
      - $DEPLOY_DIR/logs:/app/logs
    restart: unless-stopped

  # Underlay Manager (Rust)
  underlay-manager:
    image: sdwan-overlay_underlay-manager:latest
    container_name: sdwan-edge-$EDGE_ID-underlay-manager
    environment:
      - GRPC_PORT=9093
      - LOG_LEVEL=$LOG_LEVEL
      - INTERFACES=$NETWORK_INTERFACES
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - $DEPLOY_DIR/config/underlay-manager.yml:/root/config/config.yml
      - $DEPLOY_DIR/logs:/root/logs
    restart: unless-stopped

  # Packet Scheduler (Rust)
  packet-scheduler:
    image: sdwan-overlay_packet-scheduler:latest
    container_name: sdwan-edge-$EDGE_ID-packet-scheduler
    environment:
      - UNDERLAY_MANAGER_ENDPOINT=http://localhost:9093
      - LOG_LEVEL=$LOG_LEVEL
    depends_on:
      - underlay-manager
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - $DEPLOY_DIR/config/packet-scheduler.yml:/root/config/config.yml
      - $DEPLOY_DIR/logs:/root/logs
    restart: unless-stopped

  # FEC Engine (C++)
  fec-engine:
    image: sdwan-overlay_fec-engine:latest
    container_name: sdwan-edge-$EDGE_ID-fec-engine
    environment:
      - LOG_LEVEL=$LOG_LEVEL
      - FEC_TYPE=reed-solomon
      - REDUNDANCY_LEVEL=2
    network_mode: host
    volumes:
      - $DEPLOY_DIR/logs:/root/logs
    restart: unless-stopped

  # Reassembly Engine (C++)
  reassembly-engine:
    image: sdwan-overlay_reassembly-engine:latest
    container_name: sdwan-edge-$EDGE_ID-reassembly-engine
    environment:
      - LOG_LEVEL=$LOG_LEVEL
      - JITTER_BUFFER_SIZE=1000
      - TUN_INTERFACE=sdwan$EDGE_ID
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - $DEPLOY_DIR/logs:/root/logs
    restart: unless-stopped
EOF

sudo cp /tmp/edge-compose.yml "$DEPLOY_DIR/docker-compose.yml"

# Create systemd service for edge device
cat > /tmp/sdwan-edge.service << EOF
[Unit]
Description=SD-WAN Edge Device $EDGE_ID
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$DEPLOY_DIR
ExecStart=/usr/bin/docker-compose -f $DEPLOY_DIR/docker-compose.yml up -d
ExecStop=/usr/bin/docker-compose -f $DEPLOY_DIR/docker-compose.yml down
TimeoutStartSec=300
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

sudo cp /tmp/sdwan-edge.service /etc/systemd/system/sdwan-edge-$EDGE_ID.service

# Create startup script
cat > /tmp/edge-startup.sh << 'EOF'
#!/bin/bash

# SD-WAN Edge Device Startup Script
# This script handles edge device startup tasks

set -e

EDGE_ID="$1"
DEPLOY_DIR="/opt/sdwan-edge-$EDGE_ID"

echo "Starting SD-WAN edge device $EDGE_ID..."

# Wait for Docker to be ready
echo "Waiting for Docker..."
for i in {1..30}; do
    if docker info >/dev/null 2>&1; then
        echo "Docker is ready"
        break
    fi
    echo "Waiting for Docker... ($i/30)"
    sleep 2
done

# Create TUN interface for this edge
TUN_IFACE="sdwan$EDGE_ID"
if ! ip link show $TUN_IFACE >/dev/null 2>&1; then
    echo "Creating TUN interface $TUN_IFACE..."
    ip tuntap add dev $TUN_IFACE mode tun
    ip link set $TUN_IFACE up
    ip addr add 10.0.$EDGE_ID.1/24 dev $TUN_IFACE
fi

# Set up iptables rules
echo "Setting up iptables rules..."
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE || true
iptables -A FORWARD -i $TUN_IFACE -o eth0 -j ACCEPT || true
iptables -A FORWARD -i eth0 -o $TUN_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT || true

# Start services
echo "Starting SD-WAN services..."
cd $DEPLOY_DIR
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Check service health
echo "Checking service health..."
docker-compose ps

echo "SD-WAN edge device $EDGE_ID startup complete!"
EOF

sudo cp /tmp/edge-startup.sh "$DEPLOY_DIR/startup.sh"
sudo chmod +x "$DEPLOY_DIR/startup.sh"

# Create management scripts
cat > /tmp/edge-manage.sh << 'EOF'
#!/bin/bash

# SD-WAN Edge Device Management Script
# Usage: ./edge-manage.sh <edge-id> <command>

EDGE_ID="$1"
COMMAND="$2"
DEPLOY_DIR="/opt/sdwan-edge-$EDGE_ID"

if [[ -z "$EDGE_ID" || -z "$COMMAND" ]]; then
    echo "Usage: $0 <edge-id> <command>"
    echo "Commands: start, stop, restart, status, logs, config"
    exit 1
fi

case $COMMAND in
    start)
        echo "Starting SD-WAN edge device $EDGE_ID..."
        sudo systemctl start sdwan-edge-$EDGE_ID
        ;;
    stop)
        echo "Stopping SD-WAN edge device $EDGE_ID..."
        sudo systemctl stop sdwan-edge-$EDGE_ID
        ;;
    restart)
        echo "Restarting SD-WAN edge device $EDGE_ID..."
        sudo systemctl restart sdwan-edge-$EDGE_ID
        ;;
    status)
        echo "Status of SD-WAN edge device $EDGE_ID..."
        sudo systemctl status sdwan-edge-$EDGE_ID
        docker-compose -f $DEPLOY_DIR/docker-compose.yml ps
        ;;
    logs)
        echo "Logs for SD-WAN edge device $EDGE_ID..."
        docker-compose -f $DEPLOY_DIR/docker-compose.yml logs -f
        ;;
    config)
        echo "Configuration for SD-WAN edge device $EDGE_ID..."
        echo "Device Agent config:"
        cat $DEPLOY_DIR/config/device-agent.yml
        echo ""
        echo "Underlay Manager config:"
        cat $DEPLOY_DIR/config/underlay-manager.yml
        echo ""
        echo "Packet Scheduler config:"
        cat $DEPLOY_DIR/config/packet-scheduler.yml
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo "Available commands: start, stop, restart, status, logs, config"
        exit 1
        ;;
esac
EOF

sudo cp /tmp/edge-manage.sh "$DEPLOY_DIR/manage.sh"
sudo chmod +x "$DEPLOY_DIR/manage.sh"

# Enable and start the service
print_status "Enabling systemd service..."
sudo systemctl daemon-reload
sudo systemctl enable sdwan-edge-$EDGE_ID

print_status "Starting SD-WAN edge device..."
sudo systemctl start sdwan-edge-$EDGE_ID

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 15

# Check service status
print_status "Checking service status..."
sudo systemctl status sdwan-edge-$EDGE_ID --no-pager

# Show management commands
print_success "SD-WAN edge device $EDGE_ID deployed successfully!"
echo ""
echo "Management commands:"
echo "  sudo systemctl start sdwan-edge-$EDGE_ID"
echo "  sudo systemctl stop sdwan-edge-$EDGE_ID"
echo "  sudo systemctl restart sdwan-edge-$EDGE_ID"
echo "  sudo systemctl status sdwan-edge-$EDGE_ID"
echo "  $DEPLOY_DIR/manage.sh $EDGE_ID logs"
echo "  $DEPLOY_DIR/manage.sh $EDGE_ID config"
echo ""
echo "Deployment directory: $DEPLOY_DIR"
echo "Logs directory: $DEPLOY_DIR/logs"
echo "Configuration directory: $DEPLOY_DIR/config" 