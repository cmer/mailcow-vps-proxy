echo "Installing Syslog..."
apt-get update > /dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y vim rsyslog > /dev/null

# Start Syslog
systemctl start rsyslog
systemctl enable rsyslog
