FROM gcc:12-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    make \
    cmake \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy source code
COPY cpp/fec-engine ./fec-engine

# Build the application
WORKDIR /app/fec-engine
RUN make clean && make

# Final stage
FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/fec-engine/bin/fec-engine .

# Copy configuration files
COPY config/fec-engine ./config

EXPOSE 9095

CMD ["./fec-engine"] 