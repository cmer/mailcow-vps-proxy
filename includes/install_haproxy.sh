DEBIAN_FRONTEND=noninteractive apt-get install -y haproxy > /dev/null

haproxy_config="/etc/haproxy/haproxy.cfg"

echo "Creating HAProxy configuration file ${haproxy_config}"

# Create the HAProxy configuration file
cat <<EOF > $haproxy_config
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

listen stats
    bind *:444  ssl crt /etc/letsencrypt/live/${mydomain}/haproxy.pem
    mode http
    stats enable
    stats uri /haproxy?stats
    stats refresh 10s
    stats show-node
    stats auth admin:${smtp_password}
    stats admin if TRUE
EOF

for port in "${send_proxy_ports[@]}"; do
    cat <<EOF >> $haproxy_config

frontend ft_email_${port}
    bind *:${port}
    default_backend bk_email_${port}

backend bk_email_${port}
    server email_server_${port} ${mailcow_ip}:${port} send-proxy check inter 5000 fall 3 rise 2
EOF
done

cat /etc/letsencrypt/live/${mydomain}/fullchain.pem /etc/letsencrypt/live/${mydomain}/privkey.pem > /etc/letsencrypt/live/${mydomain}/haproxy.pem

echo "Starting HAProxy..."
systemctl restart haproxy
systemctl enable haproxy
