# Let's Encrypt w/ Cloudflare DNS challenge
echo "Installing Let's Encrypt..."
apt update
DEBIAN_FRONTEND=noninteractive apt-get install -y snapd > /dev/null
snap install --classic certbot
snap set certbot trust-plugin-with-root=ok
snap install --classic certbot-dns-cloudflare
ln -fs /snap/bin/certbot /usr/bin/certbot

# Configure Cloudflare DNS plugin with API credentials
mkdir -p /etc/letsencrypt
tee /etc/letsencrypt/cloudflare.ini > /dev/null <<EOF
dns_cloudflare_api_token = $cloudflare_api_token
EOF

# Secure the Cloudflare API credentials file
chmod 600 /etc/letsencrypt/cloudflare.ini

# Setup a cron job to renew SSL certificates
tee /etc/cron.d/certbot-renew > /dev/null <<EOF
0 0,12 * * * root certbot renew --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini --post-hook "systemctl reload postfix dovecot"
EOF

# Get certificate for the first time
echo "Getting SSL certificates..."
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini -d $myhostname --non-interactive --agree-tos --email $letsencrypt_email
