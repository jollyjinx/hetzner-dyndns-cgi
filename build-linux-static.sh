#!/bin/bash
set -e


# Clean previous build if it exists
# rm -rf .build

# Get current user ID and group ID for fixing permissions
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Build using Docker with Swift for Linux (x86_64/Intel architecture)

for architecture in amd64 arm64
do
echo "Building static Linux binary for hetzner-dyndns architecture: $architecture"

binaryname="hetzner-dyndns.$architecture"

docker run --rm \
  --platform linux/$architecture \
  -v "$(pwd):/workspace" \
  -w /workspace \
  swift:6.0-jammy \
  bash -c "swift build -c release --static-swift-stdlib && \
           strip .build/release/hetzner-dyndns && \
           cp .build/release/hetzner-dyndns $binaryname"

    echo ""
    echo "Binary size: $(du -h "$binaryname" | cut -f1)"
    echo ""
    echo "Verifying architecture:"
    file "$binaryname"
    echo ""
    echo "To deploy, copy this binary to your web server's cgi-bin directory."
done




