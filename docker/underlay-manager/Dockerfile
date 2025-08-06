FROM rust:1.75-alpine AS builder

WORKDIR /app

# Copy Cargo files
COPY rust/underlay-manager/Cargo.toml ./Cargo.toml

# Create a dummy main.rs to build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# Copy source code
COPY rust/underlay-manager/src ./src

# Build the application
RUN cargo build --release

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/target/release/underlay-manager .

# Copy configuration files
COPY config/underlay-manager ./config

EXPOSE 9093

CMD ["./underlay-manager"] 