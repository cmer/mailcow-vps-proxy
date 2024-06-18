#!/bin/bash
#
# Configures a Postfix relay that listens on port 2525.
#
# It is assumed that you run this script on a publicly-accessible Debian server (ie VPS) with a static IP address.
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

source includes/install_syslog.sh

source includes/install_letsencrypt.sh

source includes/install_postfix.sh

echo "Done!"

