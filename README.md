## WireGuard VPN Setup Guide

An easy and GUI-based way to set up a WireGuard VPN on a server is through **wg-easy**. However, this guide will walk you through the manual setup process, which is straightforward and effective.

### Prerequisites
- A Linux server (root or sudo access).
- At least one client (Linux, Windows, macOS, Android, or iOS).
- Basic terminal knowledge (copy-paste commands is fine)

### Time to Complete
- **Pro:** 5 minutes
- **Intermediate:** 10 minutes
- **Beginner:** 30 minutes
- **Noob:** 1 day
- Anything longer than that, and you might need to reassess your approach!

### Steps Overview
1. Self-host WireGuard VPN on a server.
2. Set up the first WireGuard VPN client.
3. Configure firewall rules on the peer side.
4. Implement DNS over VPN using a public provider.

### Not Yet Figured Out
1. Self-host DNS provider.

### Note
> In this guide, some commands are intended for Debian/Ubuntu (version 11 and above). If your operating system differs, please make the necessary adjustments.

---

### Step 1: Install WireGuard
On both server and client(s):
```bash
sudo apt update && sudo apt install wireguard -y
```

### Step 2: Generate WireGuard Keys
On both server and client(s):
```bash
wg genkey | sudo tee /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key
sudo chmod 600 /etc/wireguard/private.key # restrict access
```
This will generate WireGuard private and public keys in /etc/wireguard and set the private key’s permissions to be readable only by root.

### Step 3: Server Configuration
Create `/etc/wireguard/wg0.conf`:
```ini
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>
```
- Replace <SERVER_PRIVATE_KEY> with the server's actual WireGuard private key.
- ListenPort 51820 is the default WireGuard port (you may change it if needed).
- Address 10.0.0.1/24 is the first address in the sequential client/network plan — assign subsequent clients addresses in order (for example 10.0.0.2, 10.0.0.3, etc.).

### Step 5: Allow UDP Port
Ensure that UDP traffic on port **51820** is allowed. If using a cloud server, refer to their documentation, as each service may differ. Also, check any firewall settings to allow this port.

### Step 8: Start WireGuard and Check Status
```bash
sudo systemctl start wg-quick@wg0
systemctl status wg-quick@wg0
sudo wg show wg0 # to view active interface and peers
```
---

## First Client Setup

### Step 1: Update System
```bash
sudo apt update
```

### Step 2: Install WireGuard
```bash
sudo apt install wireguard -y
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
```

### Enable IPv4 Forwarding (Optional)
If the client needs to access the public Internet via the server, enable IPv4 forwarding on server side.
Add these lines to the [Interface] section of the WireGuard config:
```ini
# Allow IPv4 forwarding
PostUp   = sysctl -w net.ipv4.ip_forward=1
PostDown = sysctl -w net.ipv4.ip_forward=0
```
This will enable IPv4 forwarding when WireGuard is up and disable it when WireGuard is down.

### Automatically Start WireGuard at System Boot (Optional)
Enable WireGuard to start automatically on system startup.
```bash
sudo systemctl enable wg-quick@wg0
```
