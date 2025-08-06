#!/bin/bash

set -e

echo "Setting up SD-WAN development environment..."

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install essential packages
sudo apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    wget \
    unzip \
    pkg-config \
    libssl-dev \
    libpcap-dev \
    libnetfilter-queue-dev \
    python3 \
    python3-pip \
    python3-venv \
    golang-go \
    docker.io \
    docker-compose

# Install Rust
if ! command -v rustc &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
fi

# Install Go tools
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest

# Install Python development tools
pip3 install --user \
    black \
    isort \
    flake8 \
    mypy \
    pytest \
    pytest-asyncio

# Install additional system packages
sudo apt-get install -y \
    linux-tools-common \
    linux-tools-generic \
    htop \
    iotop \
    iftop \
    nethogs \
    tcpdump \
    wireshark \
    netcat \
    nmap \
    traceroute \
    mtr

# Setup kernel modules for TUN/TAP
sudo modprobe tun
echo 'tun' | sudo tee -a /etc/modules

# Setup network namespaces for testing
sudo ip netns add test-ns1 2>/dev/null || true
sudo ip netns add test-ns2 2>/dev/null || true

# Create necessary directories
mkdir -p config
mkdir -p logs
mkdir -p data
mkdir -p bin

# Setup Docker permissions
sudo usermod -aG docker $USER

# Install additional tools
sudo apt-get install -y \
    jq \
    yq \
    tree \
    tmux \
    vim \
    htop \
    glances

echo "Environment setup complete!"
echo "Please restart your shell or run: source ~/.cargo/env" 