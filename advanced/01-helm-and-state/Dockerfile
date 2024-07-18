FROM golang:1.17.0-buster AS builder

# Set metadata
LABEL maintainer=jakob.beckmann@ipt.ch
LABEL desc="Builder image for simple web server providing HTTP API for Redis"

# Set working directory
WORKDIR /app

# Download dependencies first, for caching
COPY go.mod .
COPY go.sum .
RUN go mod download

# Build application
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -o server -ldflags "-s -w"

# Make executable only for owner
RUN chmod 100 /app/server

######################################################################
# Use empty image as runtime
FROM scratch

# Set metadata
LABEL maintainer=jakob.beckmann@ipt.ch
LABEL desc="Simple web server providing HTTP API for Redis"

# Set different user for security
USER 1000

# Copy executable from builder container
COPY --from=builder --chown=1000:1000 /app/server /server

# Expose port 8080 (optional)
EXPOSE 8080

# Start server on launch
ENTRYPOINT ["./server"]
