FROM gcc:11-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache make

# Copy source code
COPY cpp/fec-engine ./fec-engine

# Build the application
WORKDIR /app/fec-engine
RUN make clean && make

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/fec-engine/bin/fec-engine .

# Copy configuration files
COPY config/fec-engine ./config

EXPOSE 9095

CMD ["./fec-engine"] 