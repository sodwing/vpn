#!/usr/bin/env bash
# nftables-based WireGuard killswitch (Fedora-compatible)
# Usage:
#   ./wg-killswitch.sh enable
#   ./wg-killswitch.sh disable
#   ./wg-killswitch.sh persist
#   ./wg-killswitch.sh unpersist
#   ./wg-killswitch.sh status

WG_CONF="/etc/wireguard/wg0.conf"
WG_INTERFACE="wg0"

# Detect correct nftables persistent config path
if [ -f /etc/sysconfig/nftables.conf ] || grep -qi "fedora" /etc/os-release 2>/dev/null; then
    NFT_PERSIST_CONF="/etc/sysconfig/nftables.conf"
else
    NFT_PERSIST_CONF="/etc/nftables.conf"
fi

# Extract server endpoint (IP:PORT)
ENDPOINT=$(sudo grep -m1 '^Endpoint' "$WG_CONF" | awk '{print $3}')
VPN_SERVER_IP=$(echo "$ENDPOINT" | cut -d: -f1)
VPN_PORT=$(echo "$ENDPOINT" | cut -d: -f2)

enable_killswitch() {
    NFT_RULESET="/tmp/wg-killswitch.nft"

    cat > "$NFT_RULESET" <<EOF
flush ruleset

table inet vpnfw {
    chain input {
        type filter hook input priority 0; policy drop;

        meta iifname "lo" accept
        ct state established,related accept
        meta iifname "$WG_INTERFACE" accept
        ip saddr $VPN_SERVER_IP udp sport $VPN_PORT accept
    }

    chain output {
        type filter hook output priority 0; policy drop;

        meta oifname "lo" accept
        ct state established,related accept
        meta oifname "$WG_INTERFACE" accept
        ip daddr $VPN_SERVER_IP udp dport $VPN_PORT accept
    }
}
EOF

    echo "[*] Applying killswitch rules..."
    sudo nft -f "$NFT_RULESET"
    rm -f "$NFT_RULESET"
    echo "[+] Killswitch enabled for $WG_INTERFACE ($VPN_SERVER_IP:$VPN_PORT)"
}

disable_killswitch() {
    echo "[*] Disabling killswitch..."
    sudo nft flush ruleset
    echo "[+] Killswitch disabled. Normal networking restored."
}

persist_killswitch() {
    echo "[*] Saving current nftables rules for persistence..."
    # Remove the top "flush ruleset" line (Fedora's nftables service rejects it)
    sudo nft list ruleset | grep -v '^flush ruleset' | sudo tee "$NFT_PERSIST_CONF" > /dev/null
    sudo systemctl enable nftables
    echo "[+] Rules saved to $NFT_PERSIST_CONF and nftables service enabled."
}

unpersist_killswitch() {
    echo "[*] Removing persistent nftables rules..."
    echo "flush ruleset" | sudo tee "$NFT_PERSIST_CONF" > /dev/null
    sudo systemctl disable nftables
    echo "[+] Persistence removed. nftables service disabled."
}

status_killswitch() {
    echo "=== Kill Switch Status ==="

    if sudo nft list tables | grep -q "vpnfw"; then
        echo "[+] Active: Yes (vpnfw rules are loaded)"
    else
        echo "[-] Active: No"
    fi

    if systemctl is-enabled --quiet nftables 2>/dev/null; then
        if sudo grep -q "vpnfw" "$NFT_PERSIST_CONF" 2>/dev/null; then
            echo "[+] Persistent: Yes (vpnfw rules saved in $NFT_PERSIST_CONF)"
        else
            echo "[-] Persistent: No (nftables enabled but no vpnfw rules)"
        fi
    else
        echo "[-] Persistent: No"
    fi

    if ip link show "$WG_INTERFACE" &>/dev/null; then
        echo "[+] WireGuard: $WG_INTERFACE is up"
    else
        echo "[-] WireGuard: $WG_INTERFACE is down"
    fi

    echo "==========================="
}

case "$1" in
    enable) enable_killswitch ;;
    disable) disable_killswitch ;;
    persist) persist_killswitch ;;
    unpersist) unpersist_killswitch ;;
    status) status_killswitch ;;
    *)
        echo "Usage: $0 {enable|disable|persist|unpersist|status}"
        exit 1
        ;;
esac
