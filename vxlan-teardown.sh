#!/bin/bash
set -euo pipefail

# VXLAN Teardown Script
# This script removes the VXLAN interface and bridge

VXLAN_INTERFACE="vxlan0"
BRIDGE_INTERFACE="br-vxlan"
VXLAN_PORT="4789"

echo "Tearing down VXLAN configuration..."

# Remove VXLAN interface
if ip link show ${VXLAN_INTERFACE} &>/dev/null; then
  echo "Removing VXLAN interface ${VXLAN_INTERFACE}..."
  ip link set ${VXLAN_INTERFACE} down 2>/dev/null || true
  ip link delete ${VXLAN_INTERFACE} 2>/dev/null || true
fi

# Remove bridge interface
if ip link show ${BRIDGE_INTERFACE} &>/dev/null; then
  echo "Removing bridge interface ${BRIDGE_INTERFACE}..."
  ip link set ${BRIDGE_INTERFACE} down 2>/dev/null || true
  ip link delete ${BRIDGE_INTERFACE} 2>/dev/null || true
fi

# Remove firewall rules
echo "Removing firewall rules..."
if command -v nft &>/dev/null; then
  nft delete table inet vxlan 2>/dev/null || true
  echo "Removed nftables rules"
elif command -v iptables &>/dev/null; then
  iptables -D INPUT -p udp --dport ${VXLAN_PORT} -j ACCEPT 2>/dev/null || true
  echo "Removed iptables rules"
fi

echo "VXLAN teardown complete!"
