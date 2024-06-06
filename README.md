# mailcow-vps-proxy

This script simplifies the deployment of a mail server in a homelab environment, or on a non-publicly accessible mail server. I personally use Mailcow as my mail server. My residential ISP (like most) blocks certain ports, so I use a VPS to forward traffic to my server at home.

You should run the setup script on a publicly accessible server with a static IP address. A cheap VPS works well.

Once configured, the VPS will forward inbound traffic on ports 25, 80, 110, 143, 443, 465, 587, 993, 995 and 4190 to your mail server. A Postfix instance will also listen on port 2525. You can use it to relay the outbound mail from your home mail server.

I recommend configuring a VPN between your VPS and home mail server. I personally use Tailscale, which makes it easy and convenient. This script does NOT configure that VPN. You have to do it yourself.
