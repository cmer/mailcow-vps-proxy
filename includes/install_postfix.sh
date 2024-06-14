echo "Installing Postfix..."
DEBIAN_FRONTEND=noninteractive apt-get install -y postfix > /dev/null

# Preconfigure Postfix settings to avoid TUI prompts
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string $myhostname" | debconf-set-selections

# Configure Dovecot for SASL authentication
tee /etc/dovecot/conf.d/10-master.conf > /dev/null <<EOF
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

tee /etc/dovecot/conf.d/10-auth.conf > /dev/null <<EOF
disable_plaintext_auth = no
auth_mechanisms = plain login
EOF

tee /etc/dovecot/conf.d/10-ssl.conf > /dev/null <<EOF
ssl = required
ssl_cert = /etc/letsencrypt/live/$myhostname/fullchain.pem
ssl_key = /etc/letsencrypt/live/$myhostname/privkey.pem
EOF

# Create the SMTP user
tee /etc/dovecot/users > /dev/null <<EOF
$smtp_username:{PLAIN}$smtp_password
EOF

# Add the passdb configuration
tee /etc/dovecot/conf.d/10-passdb.conf > /dev/null <<EOF
passdb {
  driver = passwd-file
  args = /etc/dovecot/users
}
EOF

# Restart Dovecot to apply changes
systemctl restart dovecot

# Edit Postfix main.cf configuration
postfix_main_cf="/etc/postfix/main.cf"
# Update the Postfix configuration
tee $postfix_main_cf > /dev/null <<EOF
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
tee /etc/postfix/master.cf > /dev/null <<EOF
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
systemctl restart postfix

echo "Postfix has been configured to listen on port $relay_port with authentication and encryption."
