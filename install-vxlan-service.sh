#!/bin/bash
set -euo pipefail

# Installation script for VXLAN systemd service

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing VXLAN systemd service..."

# Copy scripts to /usr/local/bin
echo "Copying scripts to /usr/local/bin..."
install -m 755 "${SCRIPT_DIR}/vxlan-setup.sh" /usr/local/bin/vxlan-setup.sh
install -m 755 "${SCRIPT_DIR}/vxlan-teardown.sh" /usr/local/bin/vxlan-teardown.sh

# Copy service file to systemd
echo "Installing systemd service unit..."
install -m 644 "${SCRIPT_DIR}/vxlan.service" /etc/systemd/system/vxlan.service

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable the service
echo "Enabling VXLAN service..."
systemctl enable vxlan.service

echo ""
echo "Installation complete!"
echo "===================="
echo ""
echo "To start the VXLAN interface now:"
echo "  sudo systemctl start vxlan.service"
echo ""
echo "To check the status:"
echo "  sudo systemctl status vxlan.service"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u vxlan.service"
echo ""
echo "The VXLAN interface will automatically start on system boot."
