# Example Router Configurations

This document provides example configurations for popular routers.

## FRITZ!Box (AVM)

1. Navigate to: **Internet → Permit Access → DynDNS**
2. Select: **Custom**
3. Configure:
   - **Update URL**: `https://yourserver.com/cgi-bin/dyndns?hostname=<domain>&myip=<ipaddr>`
   - **Domain Name**: `home.example.com`
   - **Username**: Your Hetzner Zone ID
   - **Password**: Your Hetzner API Token

## UniFi (Ubiquiti)

1. Navigate to: **Settings → Internet → WAN → Dynamic DNS**
2. Select: **Custom**
3. Configure:
   - **Service**: custom
   - **Hostname**: `home.example.com`
   - **Username**: Your Hetzner Zone ID
   - **Password**: Your Hetzner API Token
   - **Server**: `yourserver.com/cgi-bin/dyndns?hostname=%h&myip=%i`

## pfSense

1. Navigate to: **Services → Dynamic DNS**
2. Click **Add**
3. Configure:
   - **Service Type**: Custom
   - **Hostname**: `home.example.com`
   - **Username**: Your Hetzner Zone ID
   - **Password**: Your Hetzner API Token
   - **Update URL**: `https://yourserver.com/cgi-bin/dyndns?hostname=%HOSTNAME%&myip=%IP%`

## DD-WRT

1. Navigate to: **Setup → DDNS**
2. Configure:
   - **DDNS Service**: Custom
   - **DYNDNS Server**: `yourserver.com`
   - **Username**: Your Hetzner Zone ID
   - **Password**: Your Hetzner API Token
   - **Hostname**: `home.example.com`
   - **URL**: `/cgi-bin/dyndns?hostname=home.example.com&myip=`

## OpenWrt

1. Install the ddns-scripts package:
   ```bash
   opkg update
   opkg install ddns-scripts
   ```

2. Edit `/etc/config/ddns`:
   ```
   config service 'hetzner'
       option enabled '1'
       option service_name 'custom'
       option domain 'home.example.com'
       option username 'YOUR_ZONE_ID'
       option password 'YOUR_API_TOKEN'
       option update_url 'https://yourserver.com/cgi-bin/dyndns?hostname=[DOMAIN]&myip=[IP]'
       option use_https '1'
   ```

3. Restart the service:
   ```bash
   /etc/init.d/ddns restart
   ```

## MikroTik RouterOS

```
/system script add name=dyndns-update source={
  :local username "YOUR_ZONE_ID"
  :local password "YOUR_API_TOKEN"
  :local hostname "home.example.com"
  :local url "https://yourserver.com/cgi-bin/dyndns"
  
  :local ip [/ip address get [find interface=ether1] address]
  :set ip [:pick $ip 0 [:find $ip "/"]]
  
  /tool fetch url="$url?hostname=$hostname&myip=$ip" \
    user=$username password=$password mode=https keep-result=no
}

/system scheduler add name=dyndns-update interval=5m on-event=dyndns-update
```

## TP-Link

1. Navigate to: **Advanced → Network → Dynamic DNS**
2. Select: **Custom**
3. Configure:
   - **Service Provider**: Custom
   - **Domain**: `home.example.com`
   - **Username**: Your Hetzner Zone ID
   - **Password**: Your Hetzner API Token
   - **Server Address**: `yourserver.com/cgi-bin/dyndns?hostname=<domain>&myip=<ipaddr>`

## ASUS

1. Navigate to: **WAN → DDNS**
2. Configure:
   - **Server**: Custom
   - **Host Name**: `home.example.com`
   - **Username**: Your Hetzner Zone ID
   - **Password**: Your Hetzner API Token
   - **URL**: `https://yourserver.com/cgi-bin/dyndns?hostname=<domain>&myip=<ipaddr>`

## Netgear

1. Navigate to: **Advanced → Advanced Setup → Dynamic DNS**
2. Select: **Use a Dynamic DNS Service**
3. Configure:
   - **Service Provider**: Custom
   - **Host Name**: `home.example.com`
   - **Username**: Your Hetzner Zone ID
   - **Password**: Your Hetzner API Token

Note: Netgear routers may require specific URL formats. Check your model's documentation.

## Testing Your Configuration

After configuring your router, you can verify it's working by:

1. Check your router's DynDNS status page
2. Use curl to verify the DNS record:
   ```bash
   dig home.example.com
   ```
3. Check your web server's access logs for incoming requests

## Troubleshooting

- If your router doesn't support custom DynDNS URLs, try selecting "Custom" or "Generic" as the service type
- Some routers require the protocol (https://) in the URL, others don't - try both
- Check your router's system logs for DynDNS update errors
- Verify the URL format matches what your router expects (check documentation)

