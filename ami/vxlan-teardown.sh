#!/bin/bash
set -euo pipefail

# VXLAN Teardown Script
# This script removes the VXLAN interface

VXLAN_INTERFACE="vxlan0"

echo "Tearing down VXLAN configuration..."

# Remove VXLAN interface
if ip link show ${VXLAN_INTERFACE} &>/dev/null; then
  echo "Removing VXLAN interface ${VXLAN_INTERFACE}..."
  ip link set ${VXLAN_INTERFACE} down 2>/dev/null || true
  ip link delete ${VXLAN_INTERFACE} 2>/dev/null || true
fi

echo "VXLAN teardown complete!"