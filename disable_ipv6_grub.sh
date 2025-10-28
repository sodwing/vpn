#!/bin/bash
# Disable IPv6 permanently on Fedora, Debian, or Ubuntu
# Works across distributions that use systemd + sysctl

set -e

echo "=== Disable IPv6 (Fedora/Debian compatible) ==="

SYSCTL_FILE="/etc/sysctl.d/99-disable-ipv6.conf"

echo "[+] Writing sysctl config to $SYSCTL_FILE ..."
sudo bash -c "cat > $SYSCTL_FILE" << 'EOF'
# Disable IPv6 system-wide
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

echo "[+] Applying sysctl settings..."
sudo sysctl --system > /dev/null

# Optional: disable IPv6 in GRUB for complete kernel-level disable
GRUB_FILE="/etc/default/grub"
if [[ -f "$GRUB_FILE" ]]; then
    echo "[?] Do you also want to disable IPv6 at kernel level (via GRUB)? (y/N)"
    read -r REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        if grep -q "ipv6.disable=1" "$GRUB_FILE"; then
            echo "[i] Kernel IPv6 disable flag already set."
        else
            echo "[+] Adding ipv6.disable=1 to GRUB_CMDLINE_LINUX..."
            sudo sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="ipv6.disable=1 /' "$GRUB_FILE"
            echo "[+] Updating GRUB configuration..."
            if command -v update-grub &>/dev/null; then
                sudo update-grub
            elif command -v grub2-mkconfig &>/dev/null; then
                if [[ -d /boot/efi/EFI/fedora ]]; then
                    sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
                else
                    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
                fi
            fi
        fi
        echo "[✓] IPv6 will be disabled at next reboot."
    fi
fi

echo "[+] Verifying..."
if [[ $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6) -eq 1 ]]; then
    echo "[✓] IPv6 disabled successfully (runtime + persistent)."
else
    echo "[!] IPv6 disable may require reboot to take full effect."
fi

