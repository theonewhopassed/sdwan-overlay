FROM golang:1.19-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY cmd/controller ./cmd/controller
COPY cmd/controller/internal ./cmd/controller/internal

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o controller ./cmd/controller

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/controller .

# Copy configuration files
COPY config/controller ./config

EXPOSE 8080 9091

CMD ["./controller"] 