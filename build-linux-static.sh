#!/bin/bash
set -euo pipefail


# Get current user ID and group ID for fixing permissions
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Build using Docker with Swift for Linux (x86_64/Intel architecture)

for architecture in amd64 arm64
do
echo "Building static Linux binary for hetzner-dyndns architecture: $architecture"

binaryname="hetzner-dyndns.$architecture"
scratchdir="/tmp/hetzner-dyndns-build-$architecture"

container system start
container run --rm \
  --platform linux/$architecture \
  -v "$(pwd):/workspace" \
  -w /workspace \
  swift:6.2.1-jammy \
  bash -lc "rm -rf '$scratchdir' && \
            swift build -c release --static-swift-stdlib --jobs 1 --scratch-path '$scratchdir' && \
            strip '$scratchdir/release/hetzner-dyndns' && \
            cp '$scratchdir/release/hetzner-dyndns' '$binaryname' && \
            rm -rf '$scratchdir'"

    echo ""
    echo "Binary size: $(du -h "$binaryname" | cut -f1)"
    echo ""
    echo "Verifying architecture:"
    file "$binaryname"
    echo ""
    echo "To deploy, copy this binary to your web server's cgi-bin directory."
done

