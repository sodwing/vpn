#!/bin/bash
# Permanently disable IPv6 on Debian via GRUB

# Backup the original GRUB config
sudo cp /etc/default/grub /etc/default/grub.bak

# Add ipv6.disable=1 kernel parameter if not already present
sudo sed -i '/^GRUB_CMDLINE_LINUX="/{
    /ipv6\.disable=1/! s/"$/ ipv6.disable=1"/
}' /etc/default/grub

# Update GRUB configuration
sudo update-grub

echo "GRUB updated. Reboot to complete IPv6 disable."