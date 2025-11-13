FROM --platform=linux/amd64 swift:6.0-jammy as builder

WORKDIR /build

# Copy package files
COPY Package.swift .
COPY Sources ./Sources

# Build with static linking
RUN swift build -c release --static-swift-stdlib

# Strip the binary to reduce size
RUN strip .build/release/hetzner-dyndns

# Create minimal runtime image
FROM --platform=linux/amd64 ubuntu:22.04

# Install only essential runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary
COPY --from=builder /build/.build/release/hetzner-dyndns /usr/local/bin/hetzner-dyndns

# Make it executable
RUN chmod +x /usr/local/bin/hetzner-dyndns

ENTRYPOINT ["/usr/local/bin/hetzner-dyndns"]

