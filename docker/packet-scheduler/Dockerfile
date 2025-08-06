FROM rust:1.75-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy Cargo files
COPY rust/packet-scheduler/Cargo.toml ./Cargo.toml

# Create dummy main.rs to build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# Copy source code
COPY rust/packet-scheduler/src ./src

# Build the application with static linking for better compatibility
RUN cargo build --release --target x86_64-unknown-linux-musl

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/packet-scheduler .

# Copy configuration files
COPY config/packet-scheduler ./config

EXPOSE 9094

CMD ["./packet-scheduler"] 