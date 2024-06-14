#!/bin/bash
#
# This script forwards TCP traffic to a remote Mailcow (or equivalent) server setup.
# It also sets up a Postfix relay that listens on port 2525. The remote Mailcow server
# can then relay outbound traffic through port 2525.
#
# It is assumed that you run this script on a publicly-accessible Debian server (ie VPS) with a static IP address.
# I recommend setting up a VPN between the two servers. I use Tailscale for this.
#

#
# EDIT THE FOLLOWING VARIABLES AS DESIRED
#
# Hostname of the publicly-assessible server
myhostname="mail.example.com"
mydomain="example.com"

# Postfix Relay
relay_port="2525"
smtp_username="mailcow"
smtp_password="a long and complicated random password"

# Let's Encrypt w/ Cloudflare DNS challenge
letsencrypt_email="john@example.com"
cloudflare_api_token="your cloudflare token"

# Remote Mailcow server IP -- Tailscale recommended
mailcow_ip="ip address of your mailcow server that is not publicly accessible"

# Ports to be forwarded to Mailcow
forwarded_ports=(25 465 587 143 993 110 995 4190 80 443)

##
##
## DO NOT MODIFY ANYTHING BELOW THIS LINE!
##
##

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

# Get the public IP address
public_ip=$(curl -s https://ipinfo.io/ip)
echo "Your public IP is: $public_ip"

source includes/install_syslog.sh

source includes/install_haproxy.sh

source includes/install_letsencrypt.sh

source includes/install_postfix.sh

echo "Done!"

