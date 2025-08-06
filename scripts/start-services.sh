#!/bin/bash

# SD-WAN Overlay System - Service Startup Script
# This script handles post-Docker startup tasks

set -e

echo "Starting SD-WAN services..."

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Check if TUN interface exists, create if not
if ! ip link show sdwan0 >/dev/null 2>&1; then
    echo "Creating TUN interface sdwan0..."
    ip tuntap add dev sdwan0 mode tun
    ip link set sdwan0 up
    ip addr add 10.0.0.1/24 dev sdwan0
fi

# Set up iptables rules for SD-WAN traffic
echo "Setting up iptables rules..."
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE || true
iptables -A FORWARD -i sdwan0 -o eth0 -j ACCEPT || true
iptables -A FORWARD -i eth0 -o sdwan0 -m state --state RELATED,ESTABLISHED -j ACCEPT || true

# Check service health
echo "Checking service health..."
docker-compose ps

# Wait for key services to be ready
echo "Waiting for key services..."
for i in {1..30}; do
    if curl -s http://localhost:8080/health >/dev/null 2>&1; then
        echo "Controller is ready"
        break
    fi
    echo "Waiting for controller... ($i/30)"
    sleep 2
done

for i in {1..30}; do
    if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
        echo "Prometheus is ready"
        break
    fi
    echo "Waiting for Prometheus... ($i/30)"
    sleep 2
done

for i in {1..30}; do
    if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
        echo "Grafana is ready"
        break
    fi
    echo "Waiting for Grafana... ($i/30)"
    sleep 2
done

echo "SD-WAN system startup complete!"
echo ""
echo "Access URLs:"
echo "  Grafana: http://$(hostname -I | awk '{print $1}'):3000 (admin/admin)"
echo "  Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
echo "  Controller API: http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo "To view logs: docker-compose logs -f"
echo "To stop: make stop" 