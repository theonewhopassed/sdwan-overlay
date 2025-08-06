FROM debian:bullseye-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    cmake \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy source code
COPY cpp/reassembly-engine ./reassembly-engine

# Build the application
WORKDIR /app/reassembly-engine
RUN make clean && make

# Final stage
FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/reassembly-engine/bin/reassembly-engine .

# Copy configuration files
COPY config/reassembly-engine ./config

EXPOSE 9096

CMD ["./reassembly-engine"] 