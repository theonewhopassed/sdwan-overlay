#!/bin/bash

set -e

# Parse command line arguments
SITE_ID=""
WAN_INTERFACES=""
CONFIG_DIR="/etc/sdwan"
LOG_DIR="/var/log/sdwan"

while [[ $# -gt 0 ]]; do
    case $1 in
        --site-id)
            SITE_ID="$2"
            shift 2
            ;;
        --wan-interfaces)
            WAN_INTERFACES="$2"
            shift 2
            ;;
        --config-dir)
            CONFIG_DIR="$2"
            shift 2
            ;;
        --log-dir)
            LOG_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 --site-id <site-id> --wan-interfaces <interface1,interface2> [options]"
            echo "Options:"
            echo "  --site-id <site-id>           Site identifier (required)"
            echo "  --wan-interfaces <interfaces> Comma-separated list of WAN interfaces (required)"
            echo "  --config-dir <dir>            Configuration directory (default: /etc/sdwan)"
            echo "  --log-dir <dir>               Log directory (default: /var/log/sdwan)"
            echo "  --help                        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$SITE_ID" ]]; then
    echo "Error: --site-id is required"
    exit 1
fi

if [[ -z "$WAN_INTERFACES" ]]; then
    echo "Error: --wan-interfaces is required"
    exit 1
fi

echo "Deploying SD-WAN edge device..."
echo "Site ID: $SITE_ID"
echo "WAN Interfaces: $WAN_INTERFACES"
echo "Config Directory: $CONFIG_DIR"
echo "Log Directory: $LOG_DIR"

# Create directories
sudo mkdir -p "$CONFIG_DIR"
sudo mkdir -p "$LOG_DIR"
sudo mkdir -p /var/lib/sdwan

# Set permissions
sudo chown -R $USER:$USER "$CONFIG_DIR"
sudo chown -R $USER:$USER "$LOG_DIR"

# Build components
echo "Building SD-WAN components..."

# Build Rust components
cd rust/packet-scheduler
cargo build --release
sudo cp target/release/packet-scheduler /usr/local/bin/
cd ../underlay-manager
cargo build --release
sudo cp target/release/underlay-manager /usr/local/bin/
cd ../..

# Build C++ components
cd cpp/fec-engine
make
sudo cp bin/fec-engine /usr/local/bin/
cd ../reassembly-engine
make
sudo cp bin/reassembly-engine /usr/local/bin/
cd ../..

# Build Go components
go build -o bin/controller ./cmd/controller
go build -o bin/device-agent ./cmd/device-agent
sudo cp bin/controller /usr/local/bin/
sudo cp bin/device-agent /usr/local/bin/

# Install Python components
cd python/device-agent
pip3 install -e .
cd ../..

# Create configuration files
cat > "$CONFIG_DIR/edge.yml" << EOF
site_id: $SITE_ID
wan_interfaces: [$WAN_INTERFACES]
controller_endpoint: http://localhost:8080
log_level: info
metrics_port: 9092

components:
  packet_scheduler:
    enabled: true
    config_file: $CONFIG_DIR/scheduler.yml
  
  underlay_manager:
    enabled: true
    config_file: $CONFIG_DIR/underlay.yml
  
  fec_engine:
    enabled: true
    type: reed-solomon
    data_shards: 4
    parity_shards: 2
  
  reassembly_engine:
    enabled: true
    jitter_buffer_size: 1000
    tun_interface: sdwan0

failover:
  enabled: true
  health_check_interval: 5000
  failover_threshold: 3
  recovery_threshold: 5
EOF

# Create scheduler configuration
cat > "$CONFIG_DIR/scheduler.yml" << EOF
scheduler:
  algorithm: weighted_round_robin
  batch_size: 64
  max_queue_size: 10000
  metrics_interval: 1000

qos:
  rules:
    - name: voip
      priority: 7
      match_criteria:
        protocol: UDP
        port_range:
          start: 10000
          end: 20000
        dscp: 46
      action:
        link_preference: [eth0]
        bandwidth_limit: 1000000
        latency_threshold: 20
    
    - name: video
      priority: 6
      match_criteria:
        protocol: UDP
        port_range:
          start: 20000
          end: 30000
      action:
        link_preference: [eth0, eth1]
        bandwidth_limit: 5000000
        latency_threshold: 50

links:
  - name: eth0
    interface: eth0
    weight: 1.0
    max_bandwidth: 100000000
    min_latency: 10
    failover_group: primary
  
  - name: eth1
    interface: eth1
    weight: 0.8
    max_bandwidth: 50000000
    min_latency: 15
    failover_group: backup

failover:
  enabled: true
  health_check_interval: 5000
  failover_threshold: 3
  recovery_threshold: 5
EOF

# Create underlay manager configuration
cat > "$CONFIG_DIR/underlay.yml" << EOF
interfaces:
  - name: eth0
    enabled: true
    probe_interval: 5000
    icmp_enabled: true
    udp_enabled: true
    bandwidth_test_enabled: true
  
  - name: eth1
    enabled: true
    probe_interval: 5000
    icmp_enabled: true
    udp_enabled: true
    bandwidth_test_enabled: true

probes:
  icmp_timeout: 1000
  udp_timeout: 2000
  bandwidth_test_duration: 10000
  packet_size: 1500
  probe_count: 10

server:
  grpc_port: 9093
  metrics_interval: 1000
  max_connections: 100
EOF

# Create systemd service files
cat > /tmp/sdwan-packet-scheduler.service << EOF
[Unit]
Description=SD-WAN Packet Scheduler
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/packet-scheduler --config $CONFIG_DIR/scheduler.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /tmp/sdwan-underlay-manager.service << EOF
[Unit]
Description=SD-WAN Underlay Manager
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/underlay-manager --config $CONFIG_DIR/underlay.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /tmp/sdwan-fec-engine.service << EOF
[Unit]
Description=SD-WAN FEC Engine
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/fec-engine
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /tmp/sdwan-reassembly-engine.service << EOF
[Unit]
Description=SD-WAN Reassembly Engine
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/reassembly-engine
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /tmp/sdwan-device-agent.service << EOF
[Unit]
Description=SD-WAN Device Agent
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/device-agent --config $CONFIG_DIR/edge.yml --site-id $SITE_ID
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Install systemd services
sudo cp /tmp/sdwan-*.service /etc/systemd/system/
sudo systemctl daemon-reload

# Enable services
sudo systemctl enable sdwan-packet-scheduler
sudo systemctl enable sdwan-underlay-manager
sudo systemctl enable sdwan-fec-engine
sudo systemctl enable sdwan-reassembly-engine
sudo systemctl enable sdwan-device-agent

# Create TUN interface
sudo ip tuntap add mode tun sdwan0
sudo ip link set sdwan0 up
sudo ip addr add 10.0.0.1/24 dev sdwan0

# Setup iptables rules
sudo iptables -t nat -A POSTROUTING -o sdwan0 -j MASQUERADE
sudo iptables -A FORWARD -i sdwan0 -j ACCEPT
sudo iptables -A FORWARD -o sdwan0 -j ACCEPT

echo "SD-WAN edge device deployment complete!"
echo "Services installed and enabled:"
echo "  - sdwan-packet-scheduler"
echo "  - sdwan-underlay-manager"
echo "  - sdwan-fec-engine"
echo "  - sdwan-reassembly-engine"
echo "  - sdwan-device-agent"
echo ""
echo "To start services: sudo systemctl start sdwan-*"
echo "To check status: sudo systemctl status sdwan-*"
echo "To view logs: sudo journalctl -u sdwan-* -f" 