#!/bin/bash
#
# This script forwards TCP traffic to a remote Mailcow (or equivalent) server setup.
# It also sets up a Postfix relay that listens on port 2525. The remote Mailcow server
# can then relay outbound traffic through port 2525.
#
# It is assumed that you run this script on a publicly-accessible Debian server (ie VPS) with a static IP address.
# I recommend setting up a VPN between the two servers. I use Tailscale for this.
#

if [ ! -f config.sh ]; then
    echo "config.sh not found. Copy config.sh.example to config.sh and edit as appropriate."
    exit 1
fi

source config.sh

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

# Get the public IP address
public_ip=$(curl -s https://ipinfo.io/ip)
echo "Your public IP is: $public_ip"

# Ports to be forwarded to Mailcow
transparent_ports=(143 993 110 995 80 443)
send_proxy_ports=(25 465 587)

source includes/install_syslog.sh

source includes/install_haproxy.sh

source includes/install_letsencrypt.sh

source includes/install_postfix.sh

source inclues/setup_iptables.sh

echo "Done!"

