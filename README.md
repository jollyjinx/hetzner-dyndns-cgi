# hetzner-dyndns-cgi

A CGI binary that provides a DynDNS-compatible interface for updating Hetzner DNS records. This allows you to use consumer routers with DynDNS support to automatically update your Hetzner DNS records.

## Features

- ✅ **DynDNS Protocol Compatible** - Works with most consumer routers that support DynDNS
- ✅ **Static Binary** - Single executable with no dependencies
- ✅ **Hetzner DNS API** - Direct integration with Hetzner's DNS API
- ✅ **IPv4 & IPv6 Support** - Automatically handles A and AAAA records
- ✅ **Standard Responses** - Returns standard DynDNS response codes

## How It Works

The CGI binary accepts HTTP requests with Basic Authentication where:
- **Username** = Your Hetzner DNS Zone ID
- **Password** = Your Hetzner API Token

Query parameters:
- `hostname` (or `host`, `domain`) - The DNS record to update (e.g., `mydynhost`)
- `myip` (or `ip`) - Optional IP address (defaults to the client's remote address)


## Deployment

1. **Upload to your web server's CGI directory**:
   Either build the binary from source or use one of the provided binaries (amd64 or arm64) and copy them to the cgi-bin of your webserver.
   ```bash
   scp .build/release/hetzner-dyndns.amd64 user@yourserver.com:/var/www/cgi-bin/dyndns.cgi
   ```

1. **Upload the .htaccess file** (IMPORTANT - required for authentication):
   You need to change the .htaccess file so that the binary does get the authentication headers. 
   The `.htaccess` file captures the HTTP Authorization header and makes it available to the CGI script. Without it, authentication will fail.
   
   An example is provided:
      ```bash
   scp htaccess user@yourserver.com:/var/www/.htaccess
   ```
    
For detailed deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md)

## Router Configuration

Configure your router's DynDNS settings - for UniFi I'm using

- **Service**: Custom
- **Hostname**: `mydynhost`
- **Username**: Your Hetzner Zone ID (e.g., `abc123def456`)
- **Password**: Your Hetzner API Token
- **URL/Path**: `www.yourserver.com/dyndns?hostname=%h&myip=%i`

### Getting Your Hetzner Credentials

1. **Zone ID**: 
   - Log into [Hetzner DNS Console](https://dns.hetzner.com/)
   - Click on your zone
   - The Zone ID is in the URL: `https://dns.hetzner.com/zone/YOUR_ZONE_ID`

2. **API Token**:
   - Go to [API Tokens](https://dns.hetzner.com/settings/api-token)
   - Create a new token with DNS read/write permissions
   - Save the token securely

### Example Router URLs

Different routers use different URL formats. Here are common examples:

**Format 1** (Most common):
```
https://yourserver.com/cgi-bin/dyndns?hostname=<domain>&myip=<ipaddr>
```

**Format 2** (Some routers):
```
https://yourserver.com/cgi-bin/dyndns?host=<domain>&ip=<ipaddr>
```

**Format 3** (Minimal):
```
https://yourserver.com/cgi-bin/dyndns?hostname=home.example.com
```
(IP will be auto-detected from the request)

## Response Codes

The CGI follows standard DynDNS response codes:

| Response | Meaning |
|----------|---------|
| `good 1.2.3.4` | Update successful |
| `nochg 1.2.3.4` | IP unchanged, no update needed |
| `badauth` | Invalid credentials (Zone ID or API Token) |
| `notfqdn` | Hostname parameter missing or invalid |
| `nohost` | Hostname not found in your DNS zone |
| `dnserr` | Invalid IP address format |
| `911` | Server error (check Hetzner API status) |


## Building from Source

### Option 1: Using Docker (Recommended for Linux binary)

```bash
./build-linux-static.sh
```

This will create a static Linux binary at `.build/release/hetzner-dyndns`

### Option 2: Using Docker Compose

```bash
docker build -t hetzner-dyndns .
docker run --rm -v $(pwd):/output hetzner-dyndns sh -c "cp /usr/local/bin/hetzner-dyndns /output/"
```

### Option 3: Native Build (macOS/Linux)

```bash
swift build -c release --static-swift-stdlib
```

Note: Native builds may not be fully static and might require runtime dependencies.


## Testing

You can test the CGI locally or on your server using curl:

```bash
# Test with explicit IP
curl -u "ZONE_ID:API_TOKEN" \
  "https://yourserver.com/cgi-bin/dyndns?hostname=home.example.com&myip=1.2.3.4"

# Test with auto-detected IP
curl -u "ZONE_ID:API_TOKEN" \
  "https://yourserver.com/cgi-bin/dyndns?hostname=home.example.com"
```

Expected response:
```
good 1.2.3.4
```

## Requirements

- Swift 6.0 or later (for building)
- Docker (for cross-compilation to Linux)
- Linux server with CGI support (Apache, nginx with fcgiwrap, etc.)
- Hetzner DNS account with API access

## Security Notes

- The API token has full access to your DNS zone - keep it secure
- Use HTTPS for all requests to protect credentials in transit
- Consider IP-based access restrictions in your web server config
- The binary runs with the web server's user permissions

## Troubleshooting

### "badauth" response
- Verify your Zone ID is correct (check Hetzner DNS Console URL)
- Verify your API Token is valid and has DNS permissions
- Check that your router is sending Basic Authentication headers

### "nohost" response
- Ensure the DNS record exists in your Hetzner zone
- Check that the hostname matches exactly (including subdomain)
- Verify you're updating the correct zone

### "911" response
- Check Hetzner API status
- Verify network connectivity from your server
- Check web server error logs for details

### Binary won't execute
- Ensure execute permissions: `chmod +x /path/to/dyndns`
- Check that the binary is Linux-compatible (use Docker build)
- Verify CGI is enabled in your web server configuration

## License

MIT - See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
