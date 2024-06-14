# echo "Installing iptables-persistent..."
# DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent > /dev/null

# modprobe xt_TPROXY
# modprobe nf_tproxy_ipv4
# modprobe nf_tproxy_ipv6

# if ! grep -qE '^net.ipv4.ip_forward\s*=\s*1$' /etc/sysctl.conf; then
#   echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
#   sysctl -p
# fi

# if ! grep -qE '^net.ipv4.conf.all.route_localnet\s*=\s*1$' /etc/sysctl.conf; then
#   echo "net.ipv4.conf.all.route_localnet=1" >> /etc/sysctl.conf
#   sysctl -p
# fi

# tailscale_was_up=false
# if command -v tailscale >/dev/null 2>&1; then
#     if ! tailscale status | grep -q 'stopped'; then
#         echo "Tailscale network is up and connected. Bringing it down..."
#         tailscale down
#         tailscale_was_up=true
#     fi
# else
#     echo "Tailscale command not found. Please ensure Tailscale is installed."
# fi

# if [ "$tailscale_was_up" = true ]; then
#     echo "Restarting Tailscale..."
#     tailscale up
# fi
