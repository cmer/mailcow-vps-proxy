echo "Installing iptables-persistent..."
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent > /dev/null

if ! grep -qE '^net.ipv4.ip_forward\s*=\s*1$' /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
fi
sysctl -p

echo "Setting up iptables..."
iptables -t mangle -N DIVERT
iptables -t mangle -A DIVERT -j MARK --set-mark 1
iptables -t mangle -A DIVERT -j ACCEPT
iptables -t mangle -A PREROUTING -p tcp -m socket -j DIVERT

for port in "${transparent_ports[@]}"; do
    echo "Setting up port $port..."
    iptables -t mangle -A PREROUTING -p tcp -m tcp --dport $port -j TPROXY --on-port $port --tproxy-mark 0x1/0x1
done

ip rule add fwmark 1 lookup 100
ip route add local 0.0.0.0/0 dev lo table 100

echo "Saving iptables rules..."
iptables-save > /etc/iptables/rules.v4
