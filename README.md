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
Generate private key with restrictive permissions
```bash
(umask 077 && wg genkey | sudo tee /etc/wireguard/private.key > /dev/null)
```
Generate public key from private key
```bash
wg pubkey < /etc/wireguard/private.key | sudo tee /etc/wireguard/public.key > /dev/null
```
Explanation:
This will generate WireGuard private and public keys in /etc/wireguard and set the private key’s permissions to be readable only by root.
Redirecting output to /dev/null prevents your private key from being exposed in the terminal.

### Step 3: Server Configuration
Open wireguard config using your prefered text editor:
```bash
sudo nano /etc/wireguard/wg0.conf
```
Copy and paste the following in it:
```ini
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>

[Peer]
PublicKey = <CLIENT_PUBLIC_KEY>
AllowedIPs = 10.0.0.2/32
```
To save and close the file in nano, press CTRL+X, then type Y and hit ENTER to confirm your changes.

Interface Section
- **Address:** In the private subnet 10.0.0.0/24, the server is typically assigned the first usable IP (10.0.0.1), while clients receive subsequent addresses (10.0.0.2, 10.0.0.3, etc.). A /24 subnet contains 256 total addresses, of which 254 are usable by hosts (the .0 network address and .255 broadcast address are reserved).
- **ListenPort:** 51820 is the default WireGuard port (you may change it if needed).
- **PrivateKey:** Replace <SERVER_PRIVATE_KEY> with the server's actual WireGuard private key (keep this secret).

Peer Section
- **PublicKey:** Replace <CLIENT_PUBLIC_KEY> with the client's actual WireGuard public key.
- **AllowedIPs:** Assign a private IP address for the peer from the private IP range. If the server is assigned the first address, 10.0.0.1, the next available address for the peer would be 10.0.0.2, obtained by incrementing the server's IP by one.


### Step 4: Allow UDP Port
Ensure that UDP traffic on port **51820** is allowed. If using a cloud server, refer to their documentation, as each service may differ. Also, check any firewall settings to allow this port.  

If using `ufw`:
```
sudo ufw allow 51820/udp
```
If using `iptables`:
```
sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT
```
If using `nftables`:
```
sudo nft add rule inet filter input udp dport 51820 accept
```

### Step 5: Start WireGuard and Check Status
```bash
sudo wg-quick up wg0 # to start wireguard
sudo wg show wg0 # to check status
```

### Step 6: Create Client Configuration
Edit the client configuration file at `/etc/wireguard/wg0.conf`:
```ini
[Interface]
PrivateKey = <PEER_PRIVATE_KEY>
Address = 10.0.0.2/24
DNS = <DNS> # optional

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
AllowedIPs = 10.0.0.1/32
Endpoint = <SERVER_IP>:51820
```
> **Warning:** If you do not specify a DNS server, your DNS requests will use the system's default DNS and may not be secured by the VPN.

Note: If you set a DNS entry in a WireGuard config on Debian/Ubuntu, WireGuard may try to use resolvconf (or systemd-resolved, depending on your setup) and fail to start. To fix this, install resolvconf:
```
sudo apt install resolvconf
```
- **DNS:** You can use your own or public DNS servers like **1.1.1.1** (Cloudflare), **8.8.8.8** (Google), or **9.9.9.9** (Quad9).
- **Address:** Set this to **10.0.0.2/32** (the address assigned in the WireGuard server).
- **PersistentKeepalive:** Add this line in the peer section if the connection breaks:
  ```ini
  PersistentKeepalive = 25
  ```
### Start WireGuard on client and Check Status

### Test Connection
On client:
```
ping 10.0.0.1
```
On server:
```
ping 10.0.0.2
```
If both succeed → peer-to-peer VPN works

---

### Restart WireGuard Service on Config Edit
```bash
sudo systemctl restart wg-quick@wg0
```

### Enable IPv4 Forwarding (Optional)
If the client needs to access the public Internet via the server, enable IPv4 forwarding and NAT on server side.  
Dedicated VPN server? → The PostUp/PostDown approach is fine (less “attack surface”).
Add these lines to the [Interface] section of the WireGuard config:
```ini
PostUp   = sysctl -w net.ipv4.ip_forward=1
PostUp   = nft add table inet nat
PostUp   = nft add chain inet nat postrouting { type nat hook postrouting priority 100 \; }
PostUp   = nft add rule inet nat postrouting oif "eth0" masquerade

PostDown = sysctl -w net.ipv4.ip_forward=0
PostDown = nft delete rule inet nat postrouting oif "eth0" masquerade
```
This will enable IPv4 forwarding when WireGuard is up and disable it when WireGuard is down.  

Multi-purpose server (runs Docker, routing, other VPNs, etc.)? → Better to enable forwarding permanently:
```
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Automatically Start WireGuard at System Boot (Optional)
Enable WireGuard to start automatically on system startup.
```bash
sudo systemctl enable wg-quick@wg0
```

### ASCII diagram
This is what it looks like when forwarding is enabled.
```
[Client] <--- WireGuard ---> [Server] ---> Internet
```
