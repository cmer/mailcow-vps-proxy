# echo "Installing iptables-persistent..."
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent > /dev/null

if ! grep -qE '^net.ipv4.ip_forward\s*=\s*1$' /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  sysctl -p
fi

tailscale_was_up=false
if command -v tailscale >/dev/null 2>&1; then
    if ! tailscale status | grep -q 'stopped'; then
        echo "Tailscale network is up and connected. Bringing it down..."
        tailscale down
        tailscale_was_up=true
    fi
else
    echo "Tailscale command not found. Please ensure Tailscale is installed."
fi

for port in "${nat_ports[@]}"; do
    echo "Setting up NAT for port $port"
    iptables -t nat -A PREROUTING -p tcp --dport $port -j DNAT --to-destination $mailcow_ip:$port
    iptables -A FORWARD -p tcp -d $mailcow_ip --dport $port -j ACCEPT
done

iptables-save > /etc/iptables/rules.v4

if [ "$tailscale_was_up" = true ]; then
    echo "Restarting Tailscale..."
    tailscale up
fi
