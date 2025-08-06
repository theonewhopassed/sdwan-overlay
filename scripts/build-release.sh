#!/bin/bash

# SD-WAN Overlay Release Builder
# Creates compiled binaries and distribution packages

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VERSION=${VERSION:-"1.0.0"}
BUILD_DIR="build/release"
DIST_DIR="dist"
PLATFORMS=("linux-amd64" "linux-arm64" "linux-armv7")
ARCHIVE_NAME="sdwan-overlay-${VERSION}"

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

clean_build() {
    log_info "Cleaning previous build artifacts..."
    rm -rf "${BUILD_DIR}"
    rm -rf "${DIST_DIR}"
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${DIST_DIR}"
}

build_rust_components() {
    log_info "Building Rust components..."
    
    # Build packet-scheduler
    log_info "Building packet-scheduler..."
    cd rust/packet-scheduler
    cargo build --release --target x86_64-unknown-linux-gnu
    cargo build --release --target aarch64-unknown-linux-gnu
    cd ../..
    
    # Build underlay-manager
    log_info "Building underlay-manager..."
    cd rust/underlay-manager
    cargo build --release --target x86_64-unknown-linux-gnu
    cargo build --release --target aarch64-unknown-linux-gnu
    cd ../..
}

build_cpp_components() {
    log_info "Building C++ components..."
    
    # Build FEC Engine
    log_info "Building FEC Engine..."
    cd cpp/fec-engine
    make clean
    make CXX=g++ CXXFLAGS="-O3 -DNDEBUG"
    cd ../..
    
    # Build Reassembly Engine
    log_info "Building Reassembly Engine..."
    cd cpp/reassembly-engine
    make clean
    make CXX=g++ CXXFLAGS="-O3 -DNDEBUG"
    cd ../..
}

build_go_components() {
    log_info "Building Go components..."
    
    # Build controller for multiple platforms
    for platform in "${PLATFORMS[@]}"; do
        IFS='-' read -r os arch <<< "$platform"
        log_info "Building controller for ${platform}..."
        
        GOOS=$os GOARCH=$arch go build \
            -ldflags="-s -w -X main.Version=${VERSION}" \
            -o "${BUILD_DIR}/controller-${platform}" \
            ./cmd/controller
    done
}

build_python_package() {
    log_info "Building Python package..."
    
    cd python/device-agent
    python3 setup.py bdist_wheel
    cd ../..
    
    # Copy wheel to build directory
    cp python/device-agent/dist/*.whl "${BUILD_DIR}/"
}

create_docker_images() {
    log_info "Creating Docker images..."
    
    # Build all Docker images
    docker-compose build
    
    # Save images as tar files
    docker save sdwan-controller:latest -o "${BUILD_DIR}/controller-image.tar"
    docker save sdwan-device-agent:latest -o "${BUILD_DIR}/device-agent-image.tar"
    docker save sdwan-underlay-manager:latest -o "${BUILD_DIR}/underlay-manager-image.tar"
    docker save sdwan-packet-scheduler:latest -o "${BUILD_DIR}/packet-scheduler-image.tar"
    docker save sdwan-fec-engine:latest -o "${BUILD_DIR}/fec-engine-image.tar"
    docker save sdwan-reassembly-engine:latest -o "${BUILD_DIR}/reassembly-engine-image.tar"
}

create_deployment_packages() {
    log_info "Creating deployment packages..."
    
    for platform in "${PLATFORMS[@]}"; do
        log_info "Creating package for ${platform}..."
        
        # Create platform-specific directory
        platform_dir="${BUILD_DIR}/${platform}"
        mkdir -p "${platform_dir}"
        
        # Copy binaries
        cp "${BUILD_DIR}/controller-${platform}" "${platform_dir}/controller"
        cp "rust/packet-scheduler/target/${platform}/release/packet-scheduler" "${platform_dir}/" 2>/dev/null || true
        cp "rust/underlay-manager/target/${platform}/release/underlay-manager" "${platform_dir}/" 2>/dev/null || true
        cp "cpp/fec-engine/fec_engine" "${platform_dir}/"
        cp "cpp/reassembly-engine/reassembly_engine" "${platform_dir}/"
        
        # Copy configuration files
        cp -r config "${platform_dir}/"
        
        # Copy scripts
        cp -r scripts "${platform_dir}/"
        
        # Copy documentation
        cp README.md LICENSE "${platform_dir}/"
        
        # Create systemd service files
        create_systemd_services "${platform_dir}"
        
        # Create installation script
        create_install_script "${platform_dir}" "${platform}"
        
        # Create archive
        cd "${platform_dir}"
        tar -czf "../../${DIST_DIR}/${ARCHIVE_NAME}-${platform}.tar.gz" .
        cd ../..
    done
}

create_systemd_services() {
    local platform_dir="$1"
    
    # Controller service
    cat > "${platform_dir}/systemd/sdwan-controller.service" << 'EOF'
[Unit]
Description=SD-WAN Controller
After=network.target

[Service]
Type=simple
User=sdwan
Group=sdwan
WorkingDirectory=/opt/sdwan
ExecStart=/opt/sdwan/controller
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Underlay Manager service
    cat > "${platform_dir}/systemd/sdwan-underlay-manager.service" << 'EOF'
[Unit]
Description=SD-WAN Underlay Manager
After=network.target

[Service]
Type=simple
User=sdwan
Group=sdwan
WorkingDirectory=/opt/sdwan
ExecStart=/opt/sdwan/underlay-manager
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Packet Scheduler service
    cat > "${platform_dir}/systemd/sdwan-packet-scheduler.service" << 'EOF'
[Unit]
Description=SD-WAN Packet Scheduler
After=network.target sdwan-underlay-manager.service

[Service]
Type=simple
User=sdwan
Group=sdwan
WorkingDirectory=/opt/sdwan
ExecStart=/opt/sdwan/packet-scheduler
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # FEC Engine service
    cat > "${platform_dir}/systemd/sdwan-fec-engine.service" << 'EOF'
[Unit]
Description=SD-WAN FEC Engine
After=network.target

[Service]
Type=simple
User=sdwan
Group=sdwan
WorkingDirectory=/opt/sdwan
ExecStart=/opt/sdwan/fec_engine
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Reassembly Engine service
    cat > "${platform_dir}/systemd/sdwan-reassembly-engine.service" << 'EOF'
[Unit]
Description=SD-WAN Reassembly Engine
After=network.target

[Service]
Type=simple
User=sdwan
Group=sdwan
WorkingDirectory=/opt/sdwan
ExecStart=/opt/sdwan/reassembly_engine
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

create_install_script() {
    local platform_dir="$1"
    local platform="$2"
    
    cat > "${platform_dir}/install.sh" << EOF
#!/bin/bash

# SD-WAN Overlay Installer for ${platform}
# Version: ${VERSION}

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/opt/sdwan"
SERVICE_DIR="/etc/systemd/system"
USER="sdwan"
GROUP="sdwan"

log_info() {
    echo -e "\${GREEN}[INFO]\${NC} \$1"
}

log_error() {
    echo -e "\${RED}[ERROR]\${NC} \$1"
}

# Check if running as root
if [[ \$EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

log_info "Installing SD-WAN Overlay ${VERSION} for ${platform}..."

# Create user and group
if ! id "\$USER" &>/dev/null; then
    log_info "Creating user \$USER..."
    useradd -r -s /bin/false \$USER
fi

# Create installation directory
log_info "Creating installation directory..."
mkdir -p \$INSTALL_DIR
mkdir -p \$INSTALL_DIR/logs
mkdir -p \$INSTALL_DIR/config

# Copy files
log_info "Copying files..."
cp -r * \$INSTALL_DIR/
chown -R \$USER:\$GROUP \$INSTALL_DIR
chmod +x \$INSTALL_DIR/*

# Install systemd services
log_info "Installing systemd services..."
cp systemd/*.service \$SERVICE_DIR/
systemctl daemon-reload

# Enable services
log_info "Enabling services..."
systemctl enable sdwan-controller
systemctl enable sdwan-underlay-manager
systemctl enable sdwan-packet-scheduler
systemctl enable sdwan-fec-engine
systemctl enable sdwan-reassembly-engine

log_info "Installation completed successfully!"
log_info "To start the services, run: systemctl start sdwan-controller"
log_info "To check status, run: systemctl status sdwan-*"
EOF

    chmod +x "${platform_dir}/install.sh"
}

create_docker_package() {
    log_info "Creating Docker deployment package..."
    
    docker_dir="${BUILD_DIR}/docker"
    mkdir -p "${docker_dir}"
    
    # Copy Docker files
    cp docker-compose.yml "${docker_dir}/"
    cp -r docker "${docker_dir}/"
    cp -r config "${docker_dir}/"
    cp -r scripts "${docker_dir}/"
    cp README.md LICENSE "${docker_dir}/"
    
    # Copy Docker images
    cp "${BUILD_DIR}"/*.tar "${docker_dir}/"
    
    # Create Docker installation script
    cat > "${docker_dir}/install-docker.sh" << 'EOF'
#!/bin/bash

# Docker Installation Script for SD-WAN Overlay

set -e

log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

log_info "Loading Docker images..."
docker load -i controller-image.tar
docker load -i device-agent-image.tar
docker load -i underlay-manager-image.tar
docker load -i packet-scheduler-image.tar
docker load -i fec-engine-image.tar
docker load -i reassembly-engine-image.tar

log_info "Starting SD-WAN Overlay..."
docker-compose up -d

log_info "Installation completed!"
log_info "Grafana: http://localhost:3000 (admin/admin)"
log_info "Prometheus: http://localhost:9090"
log_info "Management API: http://localhost:8080"
EOF

    chmod +x "${docker_dir}/install-docker.sh"
    
    # Create archive
    cd "${docker_dir}"
    tar -czf "../../${DIST_DIR}/${ARCHIVE_NAME}-docker.tar.gz" .
    cd ../..
}

create_checksums() {
    log_info "Creating checksums..."
    cd "${DIST_DIR}"
    sha256sum *.tar.gz > SHA256SUMS
    cd ..
}

main() {
    log_info "Starting SD-WAN Overlay release build (v${VERSION})..."
    
    # Clean previous builds
    clean_build
    
    # Build all components
    build_rust_components
    build_cpp_components
    build_go_components
    build_python_package
    
    # Create Docker images
    create_docker_images
    
    # Create deployment packages
    create_deployment_packages
    create_docker_package
    
    # Create checksums
    create_checksums
    
    log_success "Build completed successfully!"
    log_info "Distribution packages created in: ${DIST_DIR}/"
    log_info "Available packages:"
    ls -la "${DIST_DIR}/"
}

# Run main function
main "$@"
