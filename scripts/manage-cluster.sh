#!/bin/bash

# SD-WAN Cluster Management Script
# Usage: ./scripts/manage-cluster.sh <command> [options]

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
    echo "SD-WAN Cluster Management Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status              Show cluster status"
    echo "  health              Check health of all components"
    echo "  logs [component]    View logs (component optional)"
    echo "  restart [component] Restart components"
    echo "  backup              Create backup of configurations"
    echo "  restore <backup>    Restore from backup"
    echo "  update              Update all components"
    echo "  scale <count>       Scale edge devices"
    echo "  monitor             Start monitoring dashboard"
    echo "  test                Run connectivity tests"
    echo "  help                Show this help message"
    echo ""
    echo "Components:"
    echo "  controller, device-agent, underlay-manager, packet-scheduler"
    echo "  fec-engine, reassembly-engine, etcd, prometheus, grafana"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 logs controller"
    echo "  $0 restart packet-scheduler"
    echo "  $0 health"
}

# Check if running in the right directory
if [[ ! -f "docker-compose.yml" ]]; then
    print_error "Must be run from the SD-WAN project root directory"
    exit 1
fi

COMMAND="$1"
COMPONENT="$2"

case $COMMAND in
    status)
        print_status "Checking SD-WAN cluster status..."
        echo ""
        echo "=== Docker Services ==="
        docker-compose ps
        echo ""
        echo "=== System Services ==="
        sudo systemctl status sdwan-* --no-pager || true
        echo ""
        echo "=== Network Interfaces ==="
        ip link show | grep sdwan || echo "No SD-WAN interfaces found"
        echo ""
        echo "=== Port Status ==="
        netstat -tlnp | grep -E ':(8080|9090|9091|9092|9093|3000|2379)' || echo "No SD-WAN ports listening"
        ;;
        
    health)
        print_status "Checking SD-WAN cluster health..."
        
        # Check Docker services
        HEALTHY_SERVICES=0
        TOTAL_SERVICES=0
        
        for service in $(docker-compose ps --services); do
            TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
            if docker-compose ps $service | grep -q "Up"; then
                print_success "✓ $service is running"
                HEALTHY_SERVICES=$((HEALTHY_SERVICES + 1))
            else
                print_error "✗ $service is not running"
            fi
        done
        
        echo ""
        echo "Service Health: $HEALTHY_SERVICES/$TOTAL_SERVICES services healthy"
        
        # Check API endpoints
        print_status "Checking API endpoints..."
        
        # Controller API
        if curl -s http://localhost:8080/health >/dev/null 2>&1; then
            print_success "✓ Controller API is responding"
        else
            print_error "✗ Controller API is not responding"
        fi
        
        # Prometheus
        if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_success "✓ Prometheus is responding"
        else
            print_error "✗ Prometheus is not responding"
        fi
        
        # Grafana
        if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
            print_success "✓ Grafana is responding"
        else
            print_error "✗ Grafana is not responding"
        fi
        
        # Etcd
        if curl -s http://localhost:2379/health >/dev/null 2>&1; then
            print_success "✓ Etcd is responding"
        else
            print_error "✗ Etcd is not responding"
        fi
        ;;
        
    logs)
        if [[ -n "$COMPONENT" ]]; then
            print_status "Showing logs for $COMPONENT..."
            docker-compose logs -f "$COMPONENT"
        else
            print_status "Showing all logs..."
            docker-compose logs -f
        fi
        ;;
        
    restart)
        if [[ -n "$COMPONENT" ]]; then
            print_status "Restarting $COMPONENT..."
            docker-compose restart "$COMPONENT"
            print_success "$COMPONENT restarted"
        else
            print_status "Restarting all services..."
            docker-compose restart
            print_success "All services restarted"
        fi
        ;;
        
    backup)
        BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
        print_status "Creating backup in $BACKUP_DIR..."
        
        mkdir -p "$BACKUP_DIR"
        
        # Backup configurations
        cp -r config/ "$BACKUP_DIR/"
        cp docker-compose.yml "$BACKUP_DIR/"
        cp scripts/ "$BACKUP_DIR/" -r
        
        # Backup data volumes
        docker run --rm -v sdwan-overlay_etcd_data:/data -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/etcd_data.tar.gz -C /data .
        docker run --rm -v sdwan-overlay_prometheus_data:/data -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/prometheus_data.tar.gz -C /data .
        docker run --rm -v sdwan-overlay_grafana_data:/data -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/grafana_data.tar.gz -C /data .
        
        print_success "Backup created: $BACKUP_DIR"
        ;;
        
    restore)
        if [[ -z "$COMPONENT" ]]; then
            print_error "Backup directory required"
            echo "Usage: $0 restore <backup-directory>"
            exit 1
        fi
        
        if [[ ! -d "$COMPONENT" ]]; then
            print_error "Backup directory not found: $COMPONENT"
            exit 1
        fi
        
        print_status "Restoring from backup: $COMPONENT"
        
        # Stop services
        docker-compose down
        
        # Restore configurations
        cp -r "$COMPONENT/config/" ./
        cp "$COMPONENT/docker-compose.yml" ./
        
        # Restore data volumes
        docker run --rm -v sdwan-overlay_etcd_data:/data -v $(pwd)/$COMPONENT:/backup alpine tar xzf /backup/etcd_data.tar.gz -C /data
        docker run --rm -v sdwan-overlay_prometheus_data:/data -v $(pwd)/$COMPONENT:/backup alpine tar xzf /backup/prometheus_data.tar.gz -C /data
        docker run --rm -v sdwan-overlay_grafana_data:/data -v $(pwd)/$COMPONENT:/backup alpine tar xzf /backup/grafana_data.tar.gz -C /data
        
        # Start services
        docker-compose up -d
        
        print_success "Restore completed"
        ;;
        
    update)
        print_status "Updating SD-WAN cluster..."
        
        # Pull latest images
        docker-compose pull
        
        # Rebuild local images
        make build-docker
        
        # Restart services
        docker-compose down
        docker-compose up -d
        
        print_success "Cluster updated"
        ;;
        
    scale)
        if [[ -z "$COMPONENT" ]]; then
            print_error "Edge count required"
            echo "Usage: $0 scale <edge-count>"
            exit 1
        fi
        
        EDGE_COUNT="$COMPONENT"
        print_status "Scaling to $EDGE_COUNT edge devices..."
        
        # This would integrate with your edge deployment system
        # For now, just show the command
        echo "To scale edge devices, use:"
        echo "  ./scripts/deploy-edge.sh edge-XX <controller-ip>"
        echo "  Where XX is the edge number (01, 02, etc.)"
        ;;
        
    monitor)
        print_status "Opening monitoring dashboard..."
        
        # Get server IP
        SERVER_IP=$(hostname -I | awk '{print $1}')
        
        echo "Monitoring URLs:"
        echo "  Grafana: http://$SERVER_IP:3000 (admin/admin)"
        echo "  Prometheus: http://$SERVER_IP:9090"
        echo "  Controller API: http://$SERVER_IP:8080"
        echo ""
        echo "Opening Grafana in browser..."
        
        # Try to open browser
        if command -v xdg-open &> /dev/null; then
            xdg-open "http://$SERVER_IP:3000"
        elif command -v open &> /dev/null; then
            open "http://$SERVER_IP:3000"
        else
            echo "Please open: http://$SERVER_IP:3000"
        fi
        ;;
        
    test)
        print_status "Running SD-WAN connectivity tests..."
        
        # Test internal connectivity
        echo "=== Internal Connectivity Tests ==="
        
        # Test controller API
        if curl -s http://localhost:8080/health >/dev/null 2>&1; then
            print_success "✓ Controller API accessible"
        else
            print_error "✗ Controller API not accessible"
        fi
        
        # Test Prometheus
        if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
            print_success "✓ Prometheus accessible"
        else
            print_error "✗ Prometheus not accessible"
        fi
        
        # Test Grafana
        if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
            print_success "✓ Grafana accessible"
        else
            print_error "✗ Grafana not accessible"
        fi
        
        # Test Etcd
        if curl -s http://localhost:2379/health >/dev/null 2>&1; then
            print_success "✓ Etcd accessible"
        else
            print_error "✗ Etcd not accessible"
        fi
        
        echo ""
        echo "=== Network Interface Tests ==="
        
        # Check TUN interfaces
        TUN_COUNT=$(ip link show | grep sdwan | wc -l)
        if [[ $TUN_COUNT -gt 0 ]]; then
            print_success "✓ Found $TUN_COUNT SD-WAN TUN interfaces"
        else
            print_warning "⚠ No SD-WAN TUN interfaces found"
        fi
        
        # Check iptables rules
        IPTABLES_RULES=$(iptables -L -n | grep sdwan | wc -l)
        if [[ $IPTABLES_RULES -gt 0 ]]; then
            print_success "✓ Found $IPTABLES_RULES SD-WAN iptables rules"
        else
            print_warning "⚠ No SD-WAN iptables rules found"
        fi
        
        echo ""
        echo "=== Performance Tests ==="
        
        # Test packet scheduler
        if docker-compose ps packet-scheduler | grep -q "Up"; then
            print_success "✓ Packet scheduler is running"
        else
            print_error "✗ Packet scheduler is not running"
        fi
        
        # Test underlay manager
        if docker-compose ps underlay-manager | grep -q "Up"; then
            print_success "✓ Underlay manager is running"
        else
            print_error "✗ Underlay manager is not running"
        fi
        
        print_success "Connectivity tests completed"
        ;;
        
    help)
        show_usage
        ;;
        
    *)
        print_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac 