# Mailcow VPS Proxy

This script facilitates the deployment of a mail server in a homelab environment or on a non-publicly accessible server. It is designed to work seamlessly with Mailcow, a popular mail server solution. Residential ISPs often block certain ports, so this script uses a VPS to forward traffic to your home server.

## Prerequisites

- A publicly accessible server with a static IP address (a cheap VPS works well. I use Virtono.)

- A VPN setup between your VPS and home mail server (Tailscale is recommended)

- Well configured mail DNS settings pointing to your VPS's public IP address or hostname.

- A PTR record for your VPS's public IP address.

## Features

- Forwards inbound traffic on ports 25, 80, 110, 143, 443, 465, 587, 993, and 995 to your home mail server using HAProxy.

- Runs a Postfix instance on port 2525 to relay outbound mail from your home mail server.

## Setup Instructions

1. Set up a VPN between your VPS and home mail server. Tailscale is a convenient option, but this script does not handle the VPN configuration. You must configure it yourself.

2. Configure `config.sh` to your liking based on `config.sh.example`.

3. Execute `./setup.sh` on your VPS. This will configure HAProxy to forward the necessary ports to your home mail server’s Tailscale IP, and configure Postfix to listen on port 2525.

4. Configure your home mail server (Mailcow) to use the VPS as the relay host for outbound mail. Make sure you use the VPS's public IP address or hostname since Mailcow's Docker containers do not have access to the Tailscale network.

5. Manually run the following on your Mailcow server to configure the Postfix relay:

```bash
cd /opt/mailcow-dockerized
echo "postscreen_upstream_proxy_protocol = haproxy" >> ./data/conf/postfix/extra.cf
docker compose restart postfix-mailcow

echo "set_real_ip_from <<---PRIVATE IP OF YOUR VPS--->>;" > ./data/conf/nginx/site.tailscale-proxy.custom
docker compose restart nginx-mailcow
```
