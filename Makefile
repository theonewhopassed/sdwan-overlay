.PHONY: all build clean test benchmark start stop deploy-edge setup

# Default target
all: build

# Build all components
build: build-rust build-cpp build-go build-python build-docker

# Build Rust components
build-rust:
	@echo "Building Rust components..."
	cargo build --release --manifest-path rust/packet-scheduler/Cargo.toml
	cargo build --release --manifest-path rust/underlay-manager/Cargo.toml

# Build C++ components
build-cpp:
	@echo "Building C++ components..."
	$(MAKE) -C cpp/fec-engine
	$(MAKE) -C cpp/reassembly-engine

# Build Go components
build-go:
	@echo "Building Go components..."
	go build -o bin/controller ./cmd/controller

# Build Python components
build-python:
	@echo "Building Python components..."
	@echo "Skipping Python build due to externally managed environment"
	@echo "To build Python components, create a virtual environment:"
	@echo "  python3 -m venv venv"
	@echo "  source venv/bin/activate"
	@echo "  pip install -e python/device-agent"

# Build Docker images
build-docker:
	@echo "Building Docker images..."
	docker-compose build

# Run all tests
test: test-rust test-cpp test-go test-python test-integration

test-rust:
	@echo "Running Rust tests..."
	cargo test --manifest-path rust/packet-scheduler/Cargo.toml
	cargo test --manifest-path rust/underlay-manager/Cargo.toml

test-cpp:
	@echo "Running C++ tests..."
	$(MAKE) -C cpp/fec-engine test
	$(MAKE) -C cpp/reassembly-engine test

test-go:
	@echo "Running Go tests..."
	go test ./...

test-python:
	@echo "Running Python tests..."
	python -m pytest python/tests/

test-integration:
	@echo "Running integration tests..."
	./scripts/test-integration.sh

# Run benchmarks
benchmark:
	@echo "Running benchmarks..."
	cargo bench --manifest-path rust/packet-scheduler/Cargo.toml
	./scripts/benchmark-cpp.sh
	./scripts/benchmark-go.sh

# Start the system
start:
	@echo "Starting SD-WAN overlay system..."
	docker-compose up -d
	./scripts/start-services.sh

# Stop the system
stop:
	@echo "Stopping SD-WAN overlay system..."
	docker-compose down
	./scripts/stop-services.sh

# Deploy edge device
deploy-edge:
	@echo "Deploying edge device..."
	./scripts/deploy-edge.sh $(ARGS)

# Setup environment
setup:
	@echo "Setting up development environment..."
	./scripts/setup.sh

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	cargo clean
	$(MAKE) -C cpp/fec-engine clean
	$(MAKE) -C cpp/reassembly-engine clean
	go clean ./...
	rm -rf bin/
	rm -rf dist/
	docker-compose down --rmi all

# Install dependencies
install-deps:
	@echo "Installing dependencies..."
	./scripts/install-dependencies.sh

# Generate documentation
docs:
	@echo "Generating documentation..."
	cargo doc --manifest-path rust/packet-scheduler/Cargo.toml
	cargo doc --manifest-path rust/underlay-manager/Cargo.toml
	godoc -http=:6060 &
	@echo "Documentation available at http://localhost:6060"

# Format code
format:
	@echo "Formatting code..."
	cargo fmt --manifest-path rust/packet-scheduler/Cargo.toml
	cargo fmt --manifest-path rust/underlay-manager/Cargo.toml
	go fmt ./...
	black python/
	isort python/

# Lint code
lint:
	@echo "Linting code..."
	cargo clippy --manifest-path rust/packet-scheduler/Cargo.toml
	cargo clippy --manifest-path rust/underlay-manager/Cargo.toml
	golangci-lint run
	flake8 python/
	mypy python/

# Security scan
security:
	@echo "Running security scan..."
	cargo audit --manifest-path rust/packet-scheduler/Cargo.toml
	cargo audit --manifest-path rust/underlay-manager/Cargo.toml
	gosec ./...
	bandit -r python/

# Help
help:
	@echo "Available targets:"
	@echo "  build        - Build all components"
	@echo "  test         - Run all tests"
	@echo "  benchmark    - Run benchmarks"
	@echo "  start        - Start the system"
	@echo "  stop         - Stop the system"
	@echo "  deploy-edge  - Deploy edge device"
	@echo "  setup        - Setup environment"
	@echo "  clean        - Clean build artifacts"
	@echo "  install-deps - Install dependencies"
	@echo "  docs         - Generate documentation"
	@echo "  format       - Format code"
	@echo "  lint         - Lint code"
	@echo "  security     - Security scan"
	@echo "  help         - Show this help" 