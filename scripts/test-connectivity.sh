#!/bin/bash

set -e

echo "Testing SD-WAN connectivity between sites..."

# Configuration
SITE_A_IP="192.168.1.10"
SITE_B_IP="192.168.1.11"
TEST_DURATION=60
PACKET_SIZE=1500
PACKET_COUNT=1000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    if [[ $status == "PASS" ]]; then
        echo -e "${GREEN}[PASS]${NC} $message"
    elif [[ $status == "FAIL" ]]; then
        echo -e "${RED}[FAIL]${NC} $message"
    elif [[ $status == "INFO" ]]; then
        echo -e "${YELLOW}[INFO]${NC} $message"
    fi
}

# Function to test basic connectivity
test_basic_connectivity() {
    print_status "INFO" "Testing basic connectivity..."
    
    # Test ping between sites
    if ping -c 3 -W 2 "$SITE_A_IP" > /dev/null 2>&1; then
        print_status "PASS" "Ping to Site A successful"
    else
        print_status "FAIL" "Ping to Site A failed"
        return 1
    fi
    
    if ping -c 3 -W 2 "$SITE_B_IP" > /dev/null 2>&1; then
        print_status "PASS" "Ping to Site B successful"
    else
        print_status "FAIL" "Ping to Site B failed"
        return 1
    fi
    
    return 0
}

# Function to test SD-WAN tunnel connectivity
test_tunnel_connectivity() {
    print_status "INFO" "Testing SD-WAN tunnel connectivity..."
    
    # Test connectivity through TUN interface
    if ping -c 3 -W 2 -I sdwan0 10.0.0.1 > /dev/null 2>&1; then
        print_status "PASS" "TUN interface connectivity successful"
    else
        print_status "FAIL" "TUN interface connectivity failed"
        return 1
    fi
    
    return 0
}

# Function to test service health
test_service_health() {
    print_status "INFO" "Testing service health..."
    
    local services=(
        "sdwan-packet-scheduler"
        "sdwan-underlay-manager"
        "sdwan-fec-engine"
        "sdwan-reassembly-engine"
        "sdwan-device-agent"
    )
    
    local all_healthy=true
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            print_status "PASS" "Service $service is running"
        else
            print_status "FAIL" "Service $service is not running"
            all_healthy=false
        fi
    done
    
    if [[ $all_healthy == true ]]; then
        return 0
    else
        return 1
    fi
}

# Function to test metrics endpoints
test_metrics_endpoints() {
    print_status "INFO" "Testing metrics endpoints..."
    
    local endpoints=(
        "http://localhost:9090"  # Prometheus
        "http://localhost:9091"  # Controller metrics
        "http://localhost:9092"  # Device agent metrics
        "http://localhost:9093"  # Underlay manager metrics
    )
    
    local all_accessible=true
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s --connect-timeout 5 "$endpoint" > /dev/null 2>&1; then
            print_status "PASS" "Metrics endpoint $endpoint accessible"
        else
            print_status "FAIL" "Metrics endpoint $endpoint not accessible"
            all_accessible=false
        fi
    done
    
    if [[ $all_accessible == true ]]; then
        return 0
    else
        return 1
    fi
}

# Function to test network performance
test_network_performance() {
    print_status "INFO" "Testing network performance..."
    
    # Test bandwidth between sites
    local bandwidth_result=$(iperf3 -c "$SITE_A_IP" -t 10 -J 2>/dev/null | jq -r '.end.sum_received.bits_per_second // 0')
    
    if [[ $bandwidth_result -gt 1000000 ]]; then  # > 1 Mbps
        print_status "PASS" "Bandwidth test passed: $(($bandwidth_result / 1000000)) Mbps"
    else
        print_status "FAIL" "Bandwidth test failed: $(($bandwidth_result / 1000000)) Mbps"
        return 1
    fi
    
    # Test latency
    local latency_result=$(ping -c 10 "$SITE_A_IP" | tail -1 | awk '{print $4}' | cut -d'/' -f2)
    
    if [[ $latency_result -lt 100 ]]; then  # < 100ms
        print_status "PASS" "Latency test passed: ${latency_result}ms"
    else
        print_status "FAIL" "Latency test failed: ${latency_result}ms"
        return 1
    fi
    
    return 0
}

# Function to test failover functionality
test_failover() {
    print_status "INFO" "Testing failover functionality..."
    
    # Simulate link failure by bringing down primary interface
    print_status "INFO" "Simulating primary link failure..."
    sudo ip link set eth0 down
    
    # Wait for failover
    sleep 10
    
    # Check if traffic is still flowing
    if ping -c 3 -W 2 "$SITE_A_IP" > /dev/null 2>&1; then
        print_status "PASS" "Failover successful - traffic still flowing"
    else
        print_status "FAIL" "Failover failed - traffic interrupted"
        sudo ip link set eth0 up
        return 1
    fi
    
    # Restore primary link
    sudo ip link set eth0 up
    sleep 10
    
    # Check if traffic returned to primary
    if ping -c 3 -W 2 "$SITE_A_IP" > /dev/null 2>&1; then
        print_status "PASS" "Primary link recovery successful"
    else
        print_status "FAIL" "Primary link recovery failed"
        return 1
    fi
    
    return 0
}

# Function to generate test report
generate_report() {
    local report_file="sdwan-test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
SD-WAN Connectivity Test Report
Generated: $(date)

Test Results:
$(cat /tmp/sdwan-test-results.txt 2>/dev/null || echo "No test results available")

System Information:
$(uname -a)

Network Interfaces:
$(ip addr show)

Routing Table:
$(ip route show)

Active Services:
$(systemctl list-units --type=service --state=active | grep sdwan || echo "No SD-WAN services found")

EOF
    
    print_status "INFO" "Test report generated: $report_file"
}

# Main test execution
main() {
    echo "Starting SD-WAN connectivity tests..."
    echo "======================================"
    
    local test_results=()
    
    # Run tests
    if test_basic_connectivity; then
        test_results+=("Basic Connectivity: PASS")
    else
        test_results+=("Basic Connectivity: FAIL")
    fi
    
    if test_tunnel_connectivity; then
        test_results+=("Tunnel Connectivity: PASS")
    else
        test_results+=("Tunnel Connectivity: FAIL")
    fi
    
    if test_service_health; then
        test_results+=("Service Health: PASS")
    else
        test_results+=("Service Health: FAIL")
    fi
    
    if test_metrics_endpoints; then
        test_results+=("Metrics Endpoints: PASS")
    else
        test_results+=("Metrics Endpoints: FAIL")
    fi
    
    if test_network_performance; then
        test_results+=("Network Performance: PASS")
    else
        test_results+=("Network Performance: FAIL")
    fi
    
    if test_failover; then
        test_results+=("Failover: PASS")
    else
        test_results+=("Failover: FAIL")
    fi
    
    # Display results
    echo ""
    echo "Test Results Summary:"
    echo "===================="
    
    local pass_count=0
    local fail_count=0
    
    for result in "${test_results[@]}"; do
        echo "$result"
        if [[ $result == *": PASS" ]]; then
            ((pass_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    echo "Summary: $pass_count passed, $fail_count failed"
    
    if [[ $fail_count -eq 0 ]]; then
        print_status "PASS" "All tests passed! SD-WAN system is working correctly."
        exit 0
    else
        print_status "FAIL" "Some tests failed. Please check the system configuration."
        exit 1
    fi
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Check dependencies
for cmd in ping curl jq iperf3 systemctl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' not found"
        exit 1
    fi
done

# Run main function
main 