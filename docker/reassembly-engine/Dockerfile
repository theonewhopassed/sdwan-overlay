FROM gcc:11-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache make

# Copy source code
COPY cpp/reassembly-engine ./reassembly-engine

# Build the application
WORKDIR /app/reassembly-engine
RUN make clean && make

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/reassembly-engine/bin/reassembly-engine .

# Copy configuration files
COPY config/reassembly-engine ./config

EXPOSE 9096

CMD ["./reassembly-engine"] 