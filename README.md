# hetzner-dyndns-cgi

A Swift package that provides:

- a reusable `HetznerDynDNS` library for updating Hetzner DNS records with DynDNS-compatible responses
- a `hetzner-dyndns` CGI executable for consumer routers that only speak the DynDNS protocol

The CGI uses the current Hetzner Console DNS API at `https://api.hetzner.cloud/v1`, which replaces the retired `dns.hetzner.com` API.

## Features

- ✅ **DynDNS Protocol Compatible** - Works with most consumer routers that support DynDNS
- ✅ **Reusable Swift Library** - Call the same update logic directly from other Swift programs
- ✅ **Self-Contained Linux Build** - Ships as a single Linux executable built for `amd64` or `arm64`
- ✅ **Hetzner Console DNS API** - Direct integration with the current Hetzner DNS API
- ✅ **IPv4 & IPv6 Support** - Automatically handles A and AAAA records
- ✅ **Standard Responses** - Returns standard DynDNS response codes

## Library Usage

The package now exposes a library product named `HetznerDynDNS`.

### Add the package

```swift
dependencies: [
    .package(url: "https://github.com/jollyjinx/hetzner-dyndns-cgi.git", from: "1.0.0"),
],
targets: [
    .executableTarget(
        name: "YourApp",
        dependencies: [
            .product(name: "HetznerDynDNS", package: "hetzner-dyndns-cgi"),
        ]
    ),
]
```

### Call the library directly

```swift
import HetznerDynDNS

let handler = DynDNSHandler()
let request = DynDNSRequest(zoneIdentifier: "example.com",
                            apiToken: "hetzner-api-token",
                            hostname: "home.example.com",
                            ipAddress: "203.0.113.10")

let response = await handler.handle(request)
print(response.status.code)
print(response.body)
```

The response body uses the same DynDNS-style strings as the CGI binary, for example `good 203.0.113.10`, `nochg 203.0.113.10`, `badauth`, or `nohost`.

## How It Works

The CGI executable accepts HTTP requests with Basic Authentication where:
- **Username** = Your Hetzner DNS zone name or zone ID
- **Password** = Your Hetzner Console API token

Query parameters:
- `hostname` (or `host`, `domain`) - The DNS record to update (e.g., `mydynhost`)
- `myip` (or `ip`) - Optional IP address (defaults to the client's remote address)


## CGI Deployment

1. **Upload to your web server's CGI directory**:
   Either build the binary from source or download the correct release asset (`hetzner-dyndns.amd64` or `hetzner-dyndns.arm64`) from GitHub Releases, then copy it to your web server's `cgi-bin` as `dyndns.cgi`.
   ```bash
   scp hetzner-dyndns.amd64 user@yourserver.com:/var/www/cgi-bin/dyndns.cgi
   ```

1. **Upload the .htaccess file** (IMPORTANT - required for authentication):
   You need to change the .htaccess file so that the binary does get the authentication headers. 
   The `.htaccess` file captures the HTTP Authorization header and makes it available to the CGI script. Without it, authentication will fail.
   
   An example is provided:
      ```bash
   scp .htaccess user@yourserver.com:/var/www/.htaccess
   ```
    
For detailed deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md)

## Router Configuration

Configure your router's DynDNS settings - for UniFi I'm using

- **Service**: Custom
- **Hostname**: `mydynhost`
- **Username**: Your Hetzner zone name (recommended) or zone ID
- **Password**: Your Hetzner Console API token
- **URL/Path**: `www.yourserver.com/cgi-bin/dyndns.cgi?hostname=%h&myip=%i`

### Getting Your Hetzner Credentials

1. **Zone name or zone ID**:
   - Log into [Hetzner Console](https://console.hetzner.cloud/)
   - Open the project that contains your DNS zone
   - Use the zone name (recommended) or copy the zone ID from the zone details

2. **API token**:
   - Create a project API token in Hetzner Console with DNS read/write permissions
   - Old tokens from `dns.hetzner.com` do not work with the new API
   - Save the token securely

### Example Router URLs

Different routers use different URL formats. Here are common examples:

**Format 1** (Most common):
```
https://yourserver.com/cgi-bin/dyndns.cgi?hostname=<domain>&myip=<ipaddr>
```

**Format 2** (Some routers):
```
https://yourserver.com/cgi-bin/dyndns.cgi?host=<domain>&ip=<ipaddr>
```

**Format 3** (Minimal):
```
https://yourserver.com/cgi-bin/dyndns.cgi?hostname=home.example.com
```
(IP will be auto-detected from the request)

## Response Codes

The CGI follows standard DynDNS response codes:

| Response | Meaning |
|----------|---------|
| `good 1.2.3.4` | Update successful |
| `nochg 1.2.3.4` | IP unchanged, no update needed |
| `badauth` | Invalid credentials (zone name/ID or API token) |
| `notfqdn` | Hostname parameter missing or invalid |
| `nohost` | Hostname not found in your DNS zone |
| `dnserr` | Invalid IP address format |
| `911` | Server error (check Hetzner API status) |


## Building from Source

### Option 1: Using Docker (Recommended for Linux binary)

```bash
./build-linux-static.sh
```

This creates Linux binaries in the project root:

- `hetzner-dyndns.amd64`
- `hetzner-dyndns.arm64`

The build script uses `container run` and serializes the Swift build to keep memory use low on smaller build hosts. These generated binaries are ignored by Git and are not committed to the repository.

### GitHub Releases

Pushing a numeric version tag such as `1.0.0` triggers GitHub Actions to run the test suite, build both Linux binaries, and attach them to a GitHub Release for that tag.

```bash
git tag 1.0.0
git push origin 1.0.0
```

Each release publishes:

- `hetzner-dyndns.amd64`
- `hetzner-dyndns.arm64`
- `SHA256SUMS`

The repository does not ship compiled binaries in git. Download release assets from GitHub Releases or build them locally when needed.

### Option 2: Using Docker Compose

```bash
docker build -t hetzner-dyndns .
docker run --rm -v $(pwd):/output hetzner-dyndns sh -c "cp /usr/local/bin/hetzner-dyndns /output/"
```

### Option 3: Native Build (macOS/Linux)

```bash
swift build -c release --static-swift-stdlib
```

Note: The production deployment flow is the Linux container build above. Native local builds are useful for development only.


## Testing

You can test the CGI locally or on your server using curl:

```bash
# Test with explicit IP
curl -u "ZONE_NAME_OR_ID:API_TOKEN" \
  "https://yourserver.com/cgi-bin/dyndns.cgi?hostname=home.example.com&myip=1.2.3.4"

# Test with auto-detected IP
curl -u "ZONE_NAME_OR_ID:API_TOKEN" \
  "https://yourserver.com/cgi-bin/dyndns.cgi?hostname=home.example.com"
```

Expected response:
```
good 1.2.3.4
```

## Requirements

- Swift 6.0 or later (for building)
- Docker (for cross-compilation to Linux)
- A container runtime that provides the `container` CLI used by `build-linux-static.sh`
- Linux server with CGI support (Apache, nginx with fcgiwrap, etc.)
- Hetzner DNS account with API access

## Security Notes

- The API token has full access to your DNS zone - keep it secure
- Use HTTPS for all requests to protect credentials in transit
- Consider IP-based access restrictions in your web server config
- The binary runs with the web server's user permissions

## Troubleshooting

### "badauth" response
- Verify your zone name or zone ID is correct
- Verify your Hetzner Console API token is valid and has DNS permissions
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
- Ensure execute permissions: `chmod +x /path/to/dyndns.cgi`
- Check that the binary is Linux-compatible (use Docker build)
- Verify CGI is enabled in your web server configuration

### Update path returns Apache 500
- Verify the file deployed to `cgi-bin/dyndns.cgi` is the newly built binary, not an older copy
- Compare checksums between `hetzner-dyndns.amd64` and the deployed `dyndns.cgi` before syncing
- If needed, enable `DYNDNS_TRACE=1` when running the binary directly to capture request flow on stderr

## License

MIT - See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
