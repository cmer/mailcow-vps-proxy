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

frontend ft_http
    bind *:80
    mode http
    option forwardfor
    default_backend bk_http

backend bk_http
mode http
    server http_server ${mailcow_ip}:80

frontend ft_https
    bind *:443 ssl crt /etc/letsencrypt/live/${myhostname}/haproxy.pem
    mode http
    option forwardfor
    default_backend bk_https

backend bk_https
mode http
    server https_server ${mailcow_ip}:443 ssl verify none
EOF

for port in "${send_proxy_ports[@]}"; do
    cat <<EOF >> $haproxy_config

frontend ft_email_${port}
    bind *:${port}
    default_backend bk_email_${port}

backend bk_email_${port}
    server email_server_${port} ${mailcow_ip}:${port} send-proxy
EOF
done

cat /etc/letsencrypt/live/${myhostname}/fullchain.pem /etc/letsencrypt/live/${myhostname}/privkey.pem > /etc/letsencrypt/live/${myhostname}/haproxy.pem

echo "Starting HAProxy..."
systemctl restart haproxy
systemctl enable haproxy
