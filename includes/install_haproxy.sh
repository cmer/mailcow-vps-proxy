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

# Append frontends and backends to the configuration file
for port in "${transparent_ports[@]}"; do
    cat <<EOF >> $haproxy_config

frontend ft_email_${port}
    bind *:${port} transparent
    default_backend bk_email_${port}

backend bk_email_${port}
    server email_server_${port} ${mailcow_ip}:${port} check
EOF
done

echo "Starting HAProxy..."
systemctl start haproxy
systemctl enable haproxy
