echo "Installing iptables-persistent..."
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent > /dev/null

modprobe xt_TPROXY
modprobe nf_tproxy_ipv4
modprobe nf_tproxy_ipv6

if ! grep -qE '^net.ipv4.ip_forward\s*=\s*1$' /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  sysctl -p
fi

if ! grep -qE '^net.ipv4.conf.all.route_localnet\s*=\s*1$' /etc/sysctl.conf; then
  echo "net.ipv4.conf.all.route_localnet=1" >> /etc/sysctl.conf
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

echo "Setting up iptables..."

echo "Resetting iptables to default values..."
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -t raw -F

# Delete all chains
iptables -X
iptables -t nat -X
iptables -t mangle -X
iptables -t raw -X

# Set default policies to ACCEPT
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

echo "Iptables reset to default values."

echo "Setting up iptables rules..."

echo "Creating DIVERT chain..."
iptables -t mangle -N DIVERT
iptables -t mangle -A DIVERT -j MARK --set-mark 1
iptables -t mangle -A DIVERT -j ACCEPT
iptables -t mangle -A PREROUTING -p tcp -m socket -j DIVERT

for port in "${transparent_ports[@]}"; do
    echo "Setting up TPROXY PREROUTING for port $port..."
    iptables -t mangle -A PREROUTING -p tcp -m tcp --dport $port -j TPROXY --on-port $port --tproxy-mark 0x1/0x1
done

ip rule add fwmark 1 lookup 100
ip route add local 0.0.0.0/0 dev lo table 100

echo "Saving iptables rules..."
iptables-save > /etc/iptables/rules.v4

if [ "$tailscale_was_up" = true ]; then
    echo "Restarting Tailscale..."
    tailscale up
fi
