DEBIAN_FRONTEND=noninteractive apt-get install -y haproxy > /dev/null

# Create the HAProxy configuration file
cat <<EOF > /etc/haproxy/haproxy.cfg
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

# Append frontends and backends to the configuration file
for port in "${forwarded_ports[@]}"; do
    cat <<EOF >> /etc/haproxy/haproxy.cfg

frontend ft_email_${port}
    bind *:${port}
    default_backend bk_email_${port}

backend bk_email_${port}
    server email_server_${port} ${mailcow_ip}:${port} check
EOF
done

echo "HAProxy configuration file created at /etc/haproxy/haproxy.cfg"
echo "Starting HAProxy..."
systemctl start haproxy
systemctl enable haproxy
