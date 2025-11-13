#!/bin/bash
# Test script to verify error messages are being returned

BINARY="./.build/release/hetzner-dyndns"

echo "=== Testing Error Reporting in Hetzner DynDNS CGI ==="
echo ""

# Test 1: Missing Auth
echo "Test 1: Missing Authentication"
export REQUEST_METHOD="GET"
export QUERY_STRING="hostname=test.example.com&myip=1.2.3.4"
unset HTTP_AUTHORIZATION
export REMOTE_ADDR="1.2.3.4"
$BINARY
echo ""
echo "---"
echo ""

# Test 2: Missing Hostname
echo "Test 2: Missing Hostname Parameter"
export HTTP_AUTHORIZATION="Basic $(echo -n 'ZONE_ID:API_TOKEN' | base64)"
export QUERY_STRING="myip=1.2.3.4"
$BINARY
echo ""
echo "---"
echo ""

# Test 3: Invalid IP
echo "Test 3: Invalid IP Address"
export QUERY_STRING="hostname=test.example.com&myip=invalid_ip"
$BINARY
echo ""
echo "---"
echo ""

# Test 4: Another Invalid IP
echo "Test 4: Another Invalid IP (999.999.999.999)"
export QUERY_STRING="hostname=test.example.com&myip=999.999.999.999"
$BINARY
echo ""
echo "---"
echo ""

# Test 5: Bad Zone ID (will hit API)
echo "Test 5: Bad Zone ID (API will return error)"
export HTTP_AUTHORIZATION="Basic $(echo -n 'INVALID_ZONE:INVALID_TOKEN' | base64)"
export QUERY_STRING="hostname=home.example.com&myip=1.2.3.4"
$BINARY
echo ""
echo "---"
echo ""

echo "=== Tests Complete ==="
echo ""
echo "Note: All errors should now include descriptive messages explaining what went wrong."

