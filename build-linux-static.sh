#!/bin/bash
set -e

echo "Building static Linux binary for hetzner-dyndns CGI..."

# Clean previous build if it exists
# rm -rf .build

# Get current user ID and group ID for fixing permissions
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Build using Docker with Swift for Linux
docker run --rm \
  -v "$(pwd):/workspace" \
  -w /workspace \
  swift:6.0-jammy \
  bash -c "swift build -c release --static-swift-stdlib && \
           strip .build/release/hetzner-dyndns"

echo ""
echo "Build complete! Binary location:"
echo "  .build/release/hetzner-dyndns"
echo ""
echo "Binary size: $(du -h .build/release/hetzner-dyndns | cut -f1)"
echo ""
echo "To deploy, copy this binary to your web server's cgi-bin directory."

