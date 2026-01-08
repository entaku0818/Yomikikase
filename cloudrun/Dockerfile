# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install git for private dependencies (if any)
RUN apk add --no-cache git ca-certificates

# Copy go mod files first for better cache
COPY go.mod go.sum* ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o server ./cmd/server

# Runtime stage
FROM alpine:3.19

# Install ca-certificates for HTTPS calls
RUN apk --no-cache add ca-certificates

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/server .

# Create non-root user
RUN adduser -D -g '' appuser
USER appuser

# Cloud Run will set PORT environment variable
ENV PORT=8080

EXPOSE 8080

# Run the binary
CMD ["./server"]
