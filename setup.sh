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




# Install packages
echo "Installing required packages..."
sudo apt-get update > /dev/null
sudo apt-get install -y postfix dovecot-core dovecot-imapd certbot python3-certbot-dns-cloudflare  iptables-persistent > /dev/null

# Get the public IP address
public_ip=$(curl -s https://ipinfo.io/ip)
echo "Your public IP is: $public_ip"

# Flush existing NAT rules (optional, be cautious with this)
iptables -t nat -F

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
if ! grep -q "^net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf > /dev/null
fi
# Loop through each port and set up the forwarding rules
for PORT in "${forwarded_ports[@]}"
do
    echo "Forwarding traffic from $public_ip:$PORT to $mailcow_ip:$PORT..."
    iptables -t nat -A PREROUTING -d $public_ip -p tcp --dport $PORT -j DNAT --to-destination $mailcow_ip:$PORT
    iptables -t nat -A POSTROUTING -p tcp -d $mailcow_ip --dport $PORT -j MASQUERADE
done

echo "Saving iptables rules..."
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

# Preconfigure Postfix settings to avoid TUI prompts
echo "postfix postfix/main_mailer_type select Internet Site" | sudo debconf-set-selections
echo "postfix postfix/mailname string $myhostname" | sudo debconf-set-selections

# Configure Cloudflare DNS plugin with API credentials
sudo mkdir -p /etc/letsencrypt
sudo tee /etc/letsencrypt/cloudflare.ini > /dev/null <<EOF
dns_cloudflare_api_token = $cloudflare_api_token
EOF

# Secure the Cloudflare API credentials file
sudo chmod 600 /etc/letsencrypt/cloudflare.ini

# Let's Encrypt w/ Cloudflare DNS challenge# Obtain SSL certificates using Cloudflare DNS

# Configure Dovecot for SASL authentication
sudo tee /etc/dovecot/conf.d/10-master.conf > /dev/null <<EOF
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

sudo tee /etc/dovecot/conf.d/10-auth.conf > /dev/null <<EOF
disable_plaintext_auth = no
auth_mechanisms = plain login
EOF

sudo tee /etc/dovecot/conf.d/10-ssl.conf > /dev/null <<EOF
ssl = required
ssl_cert = </etc/letsencrypt/live/$myhostname/fullchain.pem
ssl_key = </etc/letsencrypt/live/$myhostname/privkey.pem
EOF

# Create the SMTP user
sudo tee /etc/dovecot/users > /dev/null <<EOF
$smtp_username:{PLAIN}$smtp_password
EOF

# Add the passdb configuration
sudo tee /etc/dovecot/conf.d/10-passdb.conf > /dev/null <<EOF
passdb {
  driver = passwd-file
  args = /etc/dovecot/users
}
EOF

# Restart Dovecot to apply changes
sudo systemctl restart dovecot

# Edit Postfix main.cf configuration
postfix_main_cf="/etc/postfix/main.cf"

# Backup the original configuration file with a unique name
sudo cp $postfix_main_cf ${postfix_main_cf}.bak.$(date +%F-%T)

# Update the Postfix configuration
sudo tee $postfix_main_cf > /dev/null <<EOF
# Basic settings
myhostname = $myhostname
mydomain = $mydomain
myorigin = \$mydomain
inet_interfaces = all
inet_protocols = ipv4
mydestination = \$myhostname, localhost.\$mydomain, localhost
relay_domains = *

# Enable SASL authentication
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = \$myhostname
broken_sasl_auth_clients = yes

# Enable TLS
smtpd_tls_cert_file = /etc/letsencrypt/live/$myhostname/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/$myhostname/privkey.pem
smtpd_use_tls = yes
smtpd_tls_auth_only = yes

# Restrict access to authenticated users
smtpd_client_restrictions = permit_sasl_authenticated, reject

# Restrict unauthorized relaying
smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination

# Recipient restrictions
smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination

# Logging
maillog_file = /var/log/mail.log
EOF

# Configure Postfix to listen on a non-standard port
sudo tee /etc/postfix/master.cf > /dev/null <<EOF
smtp      inet  n       -       y       -       -       smtpd
$relay_port  inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/$relay_port
  -o smtpd_tls_wrappermode=no
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_security_level=may
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
pickup    unix  n       -       n       60      1       pickup
cleanup   unix  n       -       n       -       0       cleanup
qmgr      unix  n       -       n       300     1       qmgr
tlsmgr    unix  -       -       n       1000?   1       tlsmgr
rewrite   unix  -       -       n       -       -       trivial-rewrite
bounce    unix  -       -       n       -       0       bounce
defer     unix  -       -       n       -       0       bounce
trace     unix  -       -       n       -       0       bounce
verify    unix  -       -       n       -       1       verify
flush     unix  n       -       n       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       n       -       -       smtp
relay     unix  -       -       n       -       -       smtp
showq     unix  n       -       n       -       -       showq
discard   unix  -       -       n       -       -       discard
retry     unix  -       -       n       -       -       error
scache    unix  -       -       n       -       1       scache
postlog   unix-dgram n  -       n       -       1       postlogd
EOF

# Restart Postfix to apply changes
sudo systemctl restart postfix

# Setup a cron job to renew SSL certificates
sudo tee /etc/cron.d/certbot-renew > /dev/null <<EOF
0 0,12 * * * root certbot renew --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini --post-hook "systemctl reload postfix dovecot"
EOF

echo "Postfix has been configured to listen on port $relay_port with authentication and encryption."
echo "Done!"
