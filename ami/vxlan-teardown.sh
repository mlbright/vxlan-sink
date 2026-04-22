#!/bin/bash
set -euo pipefail

# VXLAN Sink Teardown
# Removes the VXLAN interface, the bridge, and firewall rules.

VXLAN_INTERFACE="vxlan0"
BRIDGE_INTERFACE="br0"
VXLAN_PORT="4789"

echo "Tearing down VXLAN sink configuration..."

# Remove VXLAN interface (also removes its qdisc/filters)
if ip link show ${VXLAN_INTERFACE} &>/dev/null; then
  echo "Removing VXLAN interface ${VXLAN_INTERFACE}..."
  ip link set ${VXLAN_INTERFACE} down 2>/dev/null || true
  ip link delete ${VXLAN_INTERFACE} 2>/dev/null || true
fi

# Remove bridge
if ip link show ${BRIDGE_INTERFACE} &>/dev/null; then
  echo "Removing bridge ${BRIDGE_INTERFACE}..."
  ip link set ${BRIDGE_INTERFACE} down 2>/dev/null || true
  ip link delete ${BRIDGE_INTERFACE} 2>/dev/null || true
fi

# Remove firewall rules
echo "Removing firewall rules..."
if command -v nft &>/dev/null; then
  nft delete table inet vxlan 2>/dev/null || true
  echo "Removed nftables rules"
else
  echo "Warning: nftables not found, skipping firewall cleanup"
fi

echo "VXLAN teardown complete!"