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

---

> **Note for Debian/Ubuntu users:**  
> In this guide, some commands are intended for Debian/Ubuntu (version 11 and above). If your operating system differs, please make the necessary adjustments.

> **Warning on IPv6 and Privacy:**  
> This guide focuses on IPv4. If your system also has IPv6, it may leak outside the VPN unless you either disable IPv6 or configure WireGuard to tunnel it (`AllowedIPs = ::/0`). In some cases IPv6 address can uniquely identify your device across networks — a big privacy risk. For strict privacy, ensure IPv6 is handled explicitly.

---

### Step 1: Install WireGuard
On both server and client(s):
```bash
sudo apt update && sudo apt install wireguard -y
```

### Step 2: Generate WireGuard Keys
On both server and client(s):  
Generate private key and restrict access:
```bash
wg genkey | sudo tee /etc/wireguard/private.key > /dev/null
```
```
sudo chmod 600 /etc/wireguard/private.key # restrict access
```

> **Warning:** Never share the private key.

Generate public key from private key:
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
Address = 10.0.0.2/32
DNS = <DNS> # optional

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
AllowedIPs = 10.0.0.1/32 # peer-to-peer only mode
Endpoint = <SERVER_IP>:51820
```
> **Warning:** If you do not specify a DNS server, your DNS requests will use the system's default DNS and may not be secured by the VPN.

Note: On Debian/Ubuntu, systemd-resolved usually manages DNS. If not running, you may need resolvconf. Install only if WireGuard complains about DNS setup.
```
sudo apt install resolvconf
```
- **DNS:** You can use your own or public DNS servers like 1.1.1.1 (Cloudflare), 8.8.8.8 (Google), or 9.9.9.9 (Quad9).
- **Address:** Set this to 10.0.0.2/32 (the address assigned in the WireGuard server).
- **AllowedIPs:** 10.0.0.1/32 is peer-to-peer only mode. For more options see section below: Enable IPv4 Forwarding
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

Whether you need forwarding depends on how you configure `AllowedIPs` in the client:

* **Peer-to-Peer (`10.0.0.1/32`)** → No forwarding required. Client can only talk to the server’s VPN IP.
* **LAN-Only (`10.0.0.0/24`)** → Clients can communicate with each other inside the VPN. IPv4 forwarding is required on the server so it can route traffic between clients.
* **Full Tunnel (`0.0.0.0/0`)** → Client sends all Internet traffic through the server. Forwarding **is required** on the server to route packets out to the Internet.

To enable IPv4 forwarding and NAT automatically when WireGuard starts, add these lines to the `[Interface]` section of the server config (`wg0.conf`):

```
PostUp   = sysctl -w net.ipv4.ip_forward=1
PostUp   = nft list table inet nat >/dev/null 2>&1 || nft add table inet nat
PostUp   = nft list chain inet nat postrouting >/dev/null 2>&1 || nft add chain inet nat postrouting { type nat hook postrouting priority 100 \; }
PostUp   = nft add rule inet nat postrouting oif "<WAN_INTERFACE>" masquerade

PostDown = sysctl -w net.ipv4.ip_forward=0
PostDown = nft delete rule inet nat postrouting oif "<WAN_INTERFACE>" masquerade
```
Note: Replace <WAN_INTERFACE> with the name of your server’s external network interface (e.g., eth0, ens3, or enp0s3).
You can find it with:
```
ip route | grep default
```

This enables IPv4 forwarding only while WireGuard is active.

If IPv4 forwarding is already enabled on the system, the server might already be using it. In that case, remove the postup/postdown IPv4 forwarding commands from the configuration. You can verify the current setting with:
```
cat /proc/sys/net/ipv4/ip_forward
```

---

### Automatically Start WireGuard at System Boot (Optional)
Enable WireGuard to start automatically on system startup.
```bash
sudo systemctl enable wg-quick@wg0
```

### ASCII Diagrams

**1. Peer-to-Peer Only (`AllowedIPs = 10.0.0.1/32`)**
Client talks only to the server’s VPN address.

```
[Client] <--- WireGuard ---> [Server]
```

**2. LAN-Only (`AllowedIPs = 10.0.0.0/24`)**
Client can reach all devices inside the VPN subnet.

```
[Client A] <--- WireGuard ---> [Server] ---> [Client B]
```

**3. Full Tunnel (`AllowedIPs = 0.0.0.0/0`)**
All of the client’s traffic (Internet included) goes through the VPN server.

```
[Client] <--- WireGuard ---> [Server] ---> Internet
```

---
### FAQ

**1. Permission error when starting WireGuard**  
If wg-quick fails to start because of a permission/SELinux issue for the config file, run:
```
sudo restorecon -v /etc/wireguard/wg0.conf
```
This restores the SELinux security context on the config file. Then retry starting WireGuard (e.g., sudo systemctl restart wg-quick@wg0).
