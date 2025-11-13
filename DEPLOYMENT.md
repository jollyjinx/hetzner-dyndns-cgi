# Deployment Guide

## Files to Upload

You need to upload two files to your Hetzner web server:

1. **The CGI binary**: `hetzner-dyndns` (compiled)
2. **The .htaccess file**: `.htaccess` (configuration)

## Step-by-Step Deployment

### 1. Build the Binary

```bash
./build-linux-static.sh
```

This creates `.build/release/hetzner-dyndns`

### 2. Upload Files to Your Server

```bash
# Upload the binary to cgi-bin directory
scp .build/release/hetzner-dyndns user@your-server:/path/to/cgi-bin/dyndns

# Upload the .htaccess file to the PARENT directory of cgi-bin
# (This is important - .htaccess must be in the web root or parent directory)
scp .htaccess user@your-server:/path/to/web-root/.htaccess
```

For your Hetzner setup, it looks like:
```bash
# Based on your environment output:
# DOCUMENT_ROOT=/usr/www/users/jinxae/jinx.de
# SCRIPT_FILENAME=/usr/www/users/jinxae/jinx.de/cgi-bin/dyndns.cgi

scp .build/release/hetzner-dyndns your-user@your-server:/usr/www/users/jinxae/jinx.de/cgi-bin/dyndns
scp .htaccess your-user@your-server:/usr/www/users/jinxae/jinx.de/.htaccess
```

### 3. Set Permissions

```bash
ssh user@your-server

# Make the CGI binary executable
chmod +x /usr/www/users/jinxae/jinx.de/cgi-bin/dyndns

# Ensure .htaccess is readable
chmod 644 /usr/www/users/jinxae/jinx.de/.htaccess
```

### 4. Configure URL Rewriting (if needed)

If your URL is `/dyndns` but the script is at `/cgi-bin/dyndns`, add this to your `.htaccess`:

```apache
# Enable rewrite engine
RewriteEngine On

# Capture Authorization header and make it available to CGI
RewriteCond %{HTTP:Authorization} ^(.*)
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

# Alternative: Set it as REDIRECT_HTTP_AUTHORIZATION as well
RewriteCond %{HTTP:Authorization} ^(.*)
RewriteRule .* - [E=REDIRECT_HTTP_AUTHORIZATION:%{HTTP:Authorization}]

# Rewrite /dyndns to /cgi-bin/dyndns (if needed)
RewriteCond %{REQUEST_URI} ^/dyndns$
RewriteRule ^dyndns$ /cgi-bin/dyndns [L,PT]
```

## Testing

After deployment, test with curl:

```bash
# Test with valid credentials
curl -v -u "YOUR_ZONE_ID:YOUR_API_TOKEN" \
  "https://your-domain.com/dyndns?hostname=test.example.com&myip=1.2.3.4"

# Expected output: "good 1.2.3.4" or "nochg 1.2.3.4"
```

## Troubleshooting

### Issue: "badauth - Missing or invalid Basic Authentication header"

**Solution**: The .htaccess file is not in the right place or mod_rewrite is not enabled.

1. Make sure `.htaccess` is in the document root (not in cgi-bin/)
2. Check that mod_rewrite is enabled on your server
3. Verify the RewriteRule is working by checking if `HTTP_AUTHORIZATION` appears in your debug output

### Issue: "500 Internal Server Error"

**Causes**:
1. Binary not executable: `chmod +x /path/to/dyndns`
2. Wrong architecture: Make sure you built with `--platform linux/amd64`
3. Check server error logs: `tail -f /path/to/error.log`

### Issue: "nohost - hostname not found"

**Causes**:
1. The DNS record doesn't exist in your Hetzner zone
2. The hostname doesn't match exactly (check spelling)
3. The record type (A vs AAAA) doesn't match the IP address type

**Debug**: The error message will show available records:
```
nohost - test.example.com (A) not found in zone. Available: [example.com (A), www.example.com (A)]
```

### Debug Script

To see what environment variables are being set, create a test CGI:

```bash
#!/bin/bash
echo "Content-Type: text/plain"
echo ""
echo "=== CGI Environment Variables ==="
env | sort
```

Upload it, make it executable, and call it with curl:
```bash
curl -v -u "test:test" "https://your-domain.com/cgi-bin/debug.cgi"
```

Look for `HTTP_AUTHORIZATION` or `REDIRECT_HTTP_AUTHORIZATION` in the output.

## Security Notes

- The API token has full access to your DNS zone - keep it secure
- Always use HTTPS to protect credentials in transit
- Consider IP-based access restrictions if your IP doesn't change often
- Monitor your server logs for unauthorized access attempts

## URL Format for Routers

Configure your router's DynDNS settings with:

- **Server**: `your-domain.com`
- **URL/Path**: `/dyndns?hostname=<domain>&myip=<ipaddr>`
- **Username**: Your Hetzner Zone ID
- **Password**: Your Hetzner API Token

Most routers will automatically replace `<domain>` and `<ipaddr>` with the appropriate values.

