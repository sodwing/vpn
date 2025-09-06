## WireGuard VPN Setup Guide

An easy and GUI-based way to set up a WireGuard VPN on a server is through **wg-easy**. However, this guide will walk you through the manual setup process, which is straightforward and effective.

### Time to Complete
- **Pro:** 5 minutes
- **Intermediate:** 10 minutes
- **Beginner:** 30 minutes
- **Noob:** 1 day
- Anything longer than that, and you might need to reassess your approach!

---

## Steps Overview
1. Self-host WireGuard VPN on a server.
2. Set up the first WireGuard VPN client.
3. Configure firewall rules on the peer side.
4. Implement DNS over VPN using a public provider.

### Not Yet Figured Out
1. Self-host DNS provider.

---

## Server-Side Setup

### Step 1: Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### Step 2: Install WireGuard
```bash
sudo apt install wireguard -y
```

### Step 3: Generate WireGuard Keys
```bash
umask 077
sudo wg genkey | sudo tee /etc/wireguard/server_private.key | wg pubkey | sudo tee /etc/wireguard/server_public.key
sudo chmod 600 /etc/wireguard/server_private.key # restrict access
```

### Step 4: Identify Main Network Interface
Run the following command to identify your main network interface:
```bash
ip addr show
```
Example interfaces include **enp1s0**, **eth0**, etc.

### Step 5: Create WireGuard Configuration
Edit the configuration file at `/etc/wireguard/wg0.conf`:
```ini
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <server_private_key>
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o <network_interface> -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o <network_interface> -j MASQUERADE
```

### Step 6: Enable IPv4 Forwarding
Add the following line to enable IPv4 forwarding:
```bash
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p # apply changes
```

### Step 7: Allow UDP Port
Ensure that UDP traffic on port **51820** is allowed. If using a cloud server, refer to their documentation, as each service may differ. Also, check any firewall settings to allow this port.

### Step 8: Start WireGuard and Check Status
```bash
sudo systemctl start wg-quick@wg0
systemctl status wg-quick@wg0
sudo wg show wg0 # to view active interface and peers
```

### Automatically Start WireGuard at System Boot (Optional)
Enable WireGuard to start automatically on system startup.
```bash
sudo systemctl enable wg-quick@wg0
```
---

## First Client Setup

### Step 1: Update System
```bash
sudo apt update
sudo apt upgrade
```

### Step 2: Install WireGuard
```bash
sudo apt install wireguard
```

### Step 3: Generate WireGuard Keys
```bash
sudo -s
cd /etc/wireguard
wg genkey | tee client_private.key | wg pubkey > client_public.key
exit
```

### Step 4: Create Client Configuration
Edit the client configuration file at `/etc/wireguard/wg0.conf`:
```ini
[Interface]
PrivateKey = <peer_private_key>
Address = <vpn_address>
DNS = <dns>

[Peer]
PublicKey = <server_public_key>
AllowedIPs = 0.0.0.0/0
Endpoint = <server_public_ip>:51820
```
- **DNS:** You can use your own or public DNS servers like **1.1.1.1** (Cloudflare), **8.8.8.8** (Google), or **9.9.9.9** (Quad9).
- **Address:** Set this to **10.0.0.2/24** (the address assigned in the WireGuard server).
- **PersistentKeepalive:** Add this line in the peer section if the connection breaks:
```ini
PersistentKeepalive = 25
```

### Step 5: Add Peer on Server Side
Edit the server configuration file at `/etc/wireguard/wg0.conf`:
```ini
[Peer]
PublicKey = <client_public_key>
AllowedIPs = 10.0.0.2/32
```

### Step 6: Restart WireGuard Service
```bash
sudo systemctl restart wg-quick
