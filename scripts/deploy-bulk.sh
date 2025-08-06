#!/bin/bash

# SD-WAN Bulk Edge Device Deployment Script
# Usage: ./scripts/deploy-bulk.sh <config-file>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

show_usage() {
    echo "SD-WAN Bulk Edge Device Deployment Script"
    echo ""
    echo "Usage: $0 <config-file>"
    echo ""
    echo "Config file format (YAML):"
    echo "controller_ip: 192.168.1.100"
    echo "edges:"
    echo "  - id: edge-01"
    echo "    hostname: edge-01.example.com"
    echo "    site_id: branch-office-1"
    echo "    interfaces: eth0,eth1"
    echo "    prometheus_port: 9092"
    echo "    log_level: info"
    echo ""
    echo "  - id: edge-02"
    echo "    hostname: edge-02.example.com"
    echo "    site_id: branch-office-2"
    echo "    interfaces: eth0,eth1,wlan0"
    echo "    prometheus_port: 9093"
    echo "    log_level: debug"
    echo ""
    echo "Example:"
    echo "  $0 config/edges.yml"
}

# Check if config file is provided
if [[ $# -eq 0 ]]; then
    print_error "No config file provided"
    show_usage
    exit 1
fi

CONFIG_FILE="$1"

if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Config file not found: $CONFIG_FILE"
    exit 1
fi

print_status "Starting bulk deployment using config: $CONFIG_FILE"

# Check if yq is installed (for YAML parsing)
if ! command -v yq &> /dev/null; then
    print_error "yq is required for YAML parsing. Install with: sudo apt install yq"
    exit 1
fi

# Extract controller IP
CONTROLLER_IP=$(yq eval '.controller_ip' "$CONFIG_FILE")
if [[ -z "$CONTROLLER_IP" ]]; then
    print_error "controller_ip not found in config file"
    exit 1
fi

print_status "Controller IP: $CONTROLLER_IP"

# Get list of edges
EDGES=$(yq eval '.edges[].id' "$CONFIG_FILE")

# Deploy each edge
for EDGE_ID in $EDGES; do
    print_status "Deploying edge device: $EDGE_ID"
    
    # Extract edge-specific configuration
    EDGE_CONFIG=$(yq eval ".edges[] | select(.id == \"$EDGE_ID\")" "$CONFIG_FILE")
    
    SITE_ID=$(echo "$EDGE_CONFIG" | yq eval '.site_id // "edge-'$EDGE_ID'"' -)
    INTERFACES=$(echo "$EDGE_CONFIG" | yq eval '.interfaces // "eth0,eth1"' -)
    PROMETHEUS_PORT=$(echo "$EDGE_CONFIG" | yq eval '.prometheus_port // "9092"' -)
    LOG_LEVEL=$(echo "$EDGE_CONFIG" | yq eval '.log_level // "info"' -)
    
    print_status "  Site ID: $SITE_ID"
    print_status "  Interfaces: $INTERFACES"
    print_status "  Prometheus Port: $PROMETHEUS_PORT"
    print_status "  Log Level: $LOG_LEVEL"
    
    # Deploy the edge device
    ./scripts/deploy-edge.sh "$EDGE_ID" "$CONTROLLER_IP" \
        --site-id "$SITE_ID" \
        --interfaces "$INTERFACES" \
        --prometheus-port "$PROMETHEUS_PORT" \
        --log-level "$LOG_LEVEL"
    
    if [[ $? -eq 0 ]]; then
        print_success "Edge device $EDGE_ID deployed successfully"
    else
        print_error "Failed to deploy edge device $EDGE_ID"
        exit 1
    fi
    
    echo ""
done

print_success "Bulk deployment completed successfully!"
echo ""
echo "Deployed edge devices:"
for EDGE_ID in $EDGES; do
    echo "  - $EDGE_ID"
done
echo ""
echo "Management commands:"
echo "  # Check status of all edges"
echo "  for edge in $EDGES; do"
echo "    sudo systemctl status sdwan-edge-\$edge"
echo "  done"
echo ""
echo "  # View logs of all edges"
echo "  for edge in $EDGES; do"
echo "    /opt/sdwan-edge-\$edge/manage.sh \$edge logs"
echo "  done" 