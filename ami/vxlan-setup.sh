#!/bin/bash
set -euo pipefail

# VXLAN Configuration Script
# This script sets up a VXLAN interface that accepts traffic from any source on port 4789

# Configuration variables
VXLAN_INTERFACE="vxlan0"
VXLAN_ID="1337"
VXLAN_PORT="4789"

# Auto-detect the first non-loopback physical interface
PHYSICAL_INTERFACE=$(ip -o link show | awk -F': ' '$2 !~ /^(lo|docker|br-|veth|virbr)/ {print $2; exit}')
if [[ -z "${PHYSICAL_INTERFACE}" ]]; then
  echo "Error: No physical network interface found"
  exit 1
fi

VXLAN_LOCAL_IP=$(ip -4 addr show ${PHYSICAL_INTERFACE} | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
if [[ -z "${VXLAN_LOCAL_IP}" ]]; then
  echo "Error: No IPv4 address found on interface ${PHYSICAL_INTERFACE}"
  exit 1
fi

echo "Starting VXLAN interface configuration..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

# Clean up existing VXLAN interface if it exists
if ip link show ${VXLAN_INTERFACE} &>/dev/null; then
  echo "Removing existing VXLAN interface ${VXLAN_INTERFACE}..."
  ip link set ${VXLAN_INTERFACE} down 2>/dev/null || true
  ip link delete ${VXLAN_INTERFACE} 2>/dev/null || true
fi

# Create VXLAN interface linked to physical interface
echo "Creating VXLAN interface ${VXLAN_INTERFACE} on ${PHYSICAL_INTERFACE}..."
ip link add ${VXLAN_INTERFACE} type vxlan \
  id ${VXLAN_ID} \
  dstport ${VXLAN_PORT} \
  local "${VXLAN_LOCAL_IP}" \
  dev ${PHYSICAL_INTERFACE} \
  nolearning

# Bring up VXLAN interface
echo "Bringing up VXLAN interface..."
ip link set ${VXLAN_INTERFACE} up

# Display interface information
echo ""
echo "VXLAN configuration complete!"
echo "================================"
ip -d link show ${VXLAN_INTERFACE}
echo ""
ip addr show ${VXLAN_INTERFACE}
echo ""
echo "VXLAN Interface: ${VXLAN_INTERFACE}"
echo "Physical Interface: ${PHYSICAL_INTERFACE}"
echo "VXLAN ID: ${VXLAN_ID}"
echo "VXLAN Port: ${VXLAN_PORT}"
echo "Local IP: ${VXLAN_LOCAL_IP}"
echo ""
echo "To add remote VXLAN endpoints, use:"
echo "  bridge fdb append 00:00:00:00:00:00 dev ${VXLAN_INTERFACE} dst <REMOTE_IP>"
