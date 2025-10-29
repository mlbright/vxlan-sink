#!/bin/bash
set -euo pipefail

# VXLAN Configuration Script
# This script sets up a VXLAN interface that accepts traffic from any source on port 4789

# Configuration variables
VXLAN_INTERFACE="vxlan0"
VXLAN_ID="1337"
VXLAN_PORT="4789"
VXLAN_DEV="eth0" # Physical interface to bind to - adjust as needed
VXLAN_LOCAL_IP=$(ip -4 addr show ${VXLAN_DEV} | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
BRIDGE_INTERFACE="br-vxlan"
BRIDGE_IP="10.200.0.1/24" # Adjust to your network

echo "Starting VXLAN interface configuration..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

# Clean up existing interfaces if they exist
if ip link show ${VXLAN_INTERFACE} &>/dev/null; then
  echo "Removing existing VXLAN interface ${VXLAN_INTERFACE}..."
  ip link set ${VXLAN_INTERFACE} down 2>/dev/null || true
  ip link delete ${VXLAN_INTERFACE} 2>/dev/null || true
fi

if ip link show ${BRIDGE_INTERFACE} &>/dev/null; then
  echo "Removing existing bridge interface ${BRIDGE_INTERFACE}..."
  ip link set ${BRIDGE_INTERFACE} down 2>/dev/null || true
  ip link delete ${BRIDGE_INTERFACE} 2>/dev/null || true
fi

# Create VXLAN interface
# Using 'group 239.1.1.1' for multicast, or you can use specific remote IPs
echo "Creating VXLAN interface ${VXLAN_INTERFACE}..."
ip link add ${VXLAN_INTERFACE} type vxlan \
  id ${VXLAN_ID} \
  dstport ${VXLAN_PORT} \
  local "${VXLAN_LOCAL_IP}" \
  dev ${VXLAN_DEV} \
  nolearning

# Create bridge and attach VXLAN
echo "Creating bridge interface ${BRIDGE_INTERFACE}..."
ip link add ${BRIDGE_INTERFACE} type bridge
ip link set ${VXLAN_INTERFACE} master ${BRIDGE_INTERFACE}

# Bring up interfaces
echo "Bringing up interfaces..."
ip link set ${VXLAN_INTERFACE} up
ip link set ${BRIDGE_INTERFACE} up

# Assign IP to bridge
echo "Configuring bridge IP ${BRIDGE_IP}..."
ip addr add ${BRIDGE_IP} dev ${BRIDGE_INTERFACE}

# Configure firewall to accept VXLAN traffic on port 4789 from any source
echo "Configuring firewall rules for VXLAN..."
if command -v nft &>/dev/null; then
  # Using nftables
  nft add table inet vxlan 2>/dev/null || true
  nft add chain inet vxlan input { type filter hook input priority 0 \; } 2>/dev/null || true
  nft add rule inet vxlan input udp dport ${VXLAN_PORT} accept
  echo "Added nftables rule to accept UDP port ${VXLAN_PORT}"
elif command -v iptables &>/dev/null; then
  # Fallback to iptables
  iptables -C INPUT -p udp --dport ${VXLAN_PORT} -j ACCEPT 2>/dev/null ||
    iptables -A INPUT -p udp --dport ${VXLAN_PORT} -j ACCEPT
  echo "Added iptables rule to accept UDP port ${VXLAN_PORT}"
else
  echo "Warning: Neither nftables nor iptables found. Please configure firewall manually."
fi

# Display interface information
echo ""
echo "VXLAN configuration complete!"
echo "================================"
ip -d link show ${VXLAN_INTERFACE}
echo ""
ip addr show ${BRIDGE_INTERFACE}
echo ""
echo "VXLAN Interface: ${VXLAN_INTERFACE}"
echo "VXLAN ID: ${VXLAN_ID}"
echo "VXLAN Port: ${VXLAN_PORT}"
echo "Local IP: ${VXLAN_LOCAL_IP}"
echo "Bridge: ${BRIDGE_INTERFACE}"
echo "Bridge IP: ${BRIDGE_IP}"
echo ""
echo "To add remote VXLAN endpoints, use:"
echo "  bridge fdb append 00:00:00:00:00:00 dev ${VXLAN_INTERFACE} dst <REMOTE_IP>"
