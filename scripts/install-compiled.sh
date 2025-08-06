#!/bin/bash

# SD-WAN Overlay Compiled Installer
# Installs pre-compiled binaries and services

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/opt/sdwan"
SERVICE_DIR="/etc/systemd/system"
USER="sdwan"
GROUP="sdwan"
VERSION="1.0.0"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    echo "SD-WAN Overlay Compiled Installer v${VERSION}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --type TYPE       Installation type: controller, edge, or all (default: all)"
    echo "  -c, --controller IP   Controller IP for edge devices"
    echo "  -s, --site-id ID      Site ID for edge devices"
    echo "  -i, --interfaces IF   Network interfaces (comma-separated)"
    echo "  -p, --port PORT       Prometheus port (default: 9092)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --type controller                    # Install as central controller"
    echo "  $0 --type edge --controller 192.168.1.100 --site-id branch-1"
    echo "  $0 --type all                          # Install controller + edge (all-in-one)"
}

install_dependencies() {
    log_info "Installing system dependencies..."
    
    # Update package list
    apt-get update
    
    # Install required packages
    apt-get install -y \
        curl \
        wget \
        net-tools \
        iptables \
        iproute2 \
        bridge-utils \
        python3 \
        python3-pip \
        python3-venv
}

create_user() {
    log_info "Creating system user..."
    
    if ! id "$USER" &>/dev/null; then
        useradd -r -s /bin/false -d "$INSTALL_DIR" "$USER"
        log_success "Created user $USER"
    else
        log_info "User $USER already exists"
    fi
}

install_binaries() {
    log_info "Installing binaries..."
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/logs"
    mkdir -p "$INSTALL_DIR/config"
    
    # Copy binaries (assuming they're in the same directory as this script)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Copy all files from the package
    cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/" 2>/dev/null || true
    
    # Set permissions
    chown -R "$USER:$GROUP" "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR"/* 2>/dev/null || true
}

install_systemd_services() {
    log_info "Installing systemd services..."
    
    # Copy service files
    if [ -d "$INSTALL_DIR/systemd" ]; then
        cp "$INSTALL_DIR/systemd"/*.service "$SERVICE_DIR/"
        systemctl daemon-reload
        log_success "Systemd services installed"
    else
        log_warning "No systemd service files found"
    fi
}

configure_controller() {
    log_info "Configuring as controller..."
    
    # Enable controller services
    systemctl enable sdwan-controller 2>/dev/null || true
    
    log_success "Controller configuration completed"
    log_info "Grafana will be available at: http://$(hostname -I | awk '{print $1}'):3000"
    log_info "Prometheus will be available at: http://$(hostname -I | awk '{print $1}'):9090"
    log_info "Management API will be available at: http://$(hostname -I | awk '{print $1}'):8080"
}

configure_edge() {
    local controller_ip="$1"
    local site_id="$2"
    local interfaces="$3"
    local prometheus_port="$4"
    
    log_info "Configuring as edge device..."
    
    # Update configuration
    if [ -f "$INSTALL_DIR/config/device-agent/config.yml" ]; then
        sed -i "s/controller_ip: .*/controller_ip: $controller_ip/" "$INSTALL_DIR/config/device-agent/config.yml"
        sed -i "s/site_id: .*/site_id: $site_id/" "$INSTALL_DIR/config/device-agent/config.yml"
        sed -i "s/prometheus_port: .*/prometheus_port: $prometheus_port/" "$INSTALL_DIR/config/device-agent/config.yml"
    fi
    
    if [ -f "$INSTALL_DIR/config/underlay-manager/config.yml" ]; then
        sed -i "s/interfaces: .*/interfaces: $interfaces/" "$INSTALL_DIR/config/underlay-manager/config.yml"
    fi
    
    # Enable edge services
    systemctl enable sdwan-underlay-manager 2>/dev/null || true
    systemctl enable sdwan-packet-scheduler 2>/dev/null || true
    systemctl enable sdwan-fec-engine 2>/dev/null || true
    systemctl enable sdwan-reassembly-engine 2>/dev/null || true
    
    log_success "Edge device configuration completed"
    log_info "TUN interface will be created as: sdwan-$(hostname)"
    log_info "Local metrics will be available at: http://$(hostname -I | awk '{print $1}'):$prometheus_port"
}

create_tun_interface() {
    log_info "Creating TUN interface..."
    
    local tun_name="sdwan-$(hostname)"
    
    # Create TUN interface
    ip tuntap add mode tun dev "$tun_name" 2>/dev/null || true
    ip link set "$tun_name" up
    ip addr add 10.0.0.1/24 dev "$tun_name" 2>/dev/null || true
    
    log_success "TUN interface $tun_name created"
}

setup_iptables() {
    log_info "Setting up iptables rules..."
    
    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Add iptables rules for NAT
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
    iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE 2>/dev/null || true
    
    log_success "Iptables rules configured"
}

start_services() {
    log_info "Starting services..."
    
    # Start controller services
    if [ "$INSTALL_TYPE" = "controller" ] || [ "$INSTALL_TYPE" = "all" ]; then
        systemctl start sdwan-controller 2>/dev/null || true
    fi
    
    # Start edge services
    if [ "$INSTALL_TYPE" = "edge" ] || [ "$INSTALL_TYPE" = "all" ]; then
        systemctl start sdwan-underlay-manager 2>/dev/null || true
        systemctl start sdwan-packet-scheduler 2>/dev/null || true
        systemctl start sdwan-fec-engine 2>/dev/null || true
        systemctl start sdwan-reassembly-engine 2>/dev/null || true
    fi
    
    log_success "Services started"
}

show_status() {
    log_info "Installation completed successfully!"
    echo ""
    echo "=== SD-WAN Overlay Status ==="
    systemctl status sdwan-* --no-pager -l || true
    echo ""
    echo "=== Network Interfaces ==="
    ip addr show | grep -E "(sdwan|eth|wlan)" || true
    echo ""
    echo "=== Service Logs ==="
    journalctl -u sdwan-* --no-pager -l --since "5 minutes ago" || true
}

# Parse command line arguments
INSTALL_TYPE="all"
CONTROLLER_IP=""
SITE_ID="$(hostname)"
INTERFACES="eth0,eth1"
PROMETHEUS_PORT="9092"

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            INSTALL_TYPE="$2"
            shift 2
            ;;
        -c|--controller)
            CONTROLLER_IP="$2"
            shift 2
            ;;
        -s|--site-id)
            SITE_ID="$2"
            shift 2
            ;;
        -i|--interfaces)
            INTERFACES="$2"
            shift 2
            ;;
        -p|--port)
            PROMETHEUS_PORT="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate arguments
if [ "$INSTALL_TYPE" = "edge" ] && [ -z "$CONTROLLER_IP" ]; then
    log_error "Controller IP is required for edge installation"
    exit 1
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

# Main installation
log_info "Starting SD-WAN Overlay installation (Type: $INSTALL_TYPE)..."

install_dependencies
create_user
install_binaries
install_systemd_services

if [ "$INSTALL_TYPE" = "controller" ] || [ "$INSTALL_TYPE" = "all" ]; then
    configure_controller
fi

if [ "$INSTALL_TYPE" = "edge" ] || [ "$INSTALL_TYPE" = "all" ]; then
    configure_edge "$CONTROLLER_IP" "$SITE_ID" "$INTERFACES" "$PROMETHEUS_PORT"
    create_tun_interface
    setup_iptables
fi

start_services
show_status

log_success "SD-WAN Overlay installation completed!"
