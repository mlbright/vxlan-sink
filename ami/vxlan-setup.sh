#!/bin/bash
set -euo pipefail

# VXLAN Sink Setup
#
# Creates a VXLAN interface in "external" (collect-metadata) mode so it
# accepts packets for ANY VNI on UDP/4789, and uses a tc flower ingress rule
# to strip the tunnel metadata and redirect the decapsulated inner frames
# into a Linux bridge. Capture on the bridge to inspect inner traffic, or on
# the underlay NIC to inspect VXLAN-encapsulated packets (with VNI).

# Configuration variables
VXLAN_INTERFACE="vxlan0"
BRIDGE_INTERFACE="br0"
VXLAN_PORT="4789"
BRIDGE_IP="10.200.0.1/24" # IP address for the bridge interface

# Auto-detect the first non-loopback physical interface
PHYSICAL_INTERFACE=$(ip -o link show | awk -F': ' '$2 !~ /^(lo|docker|br-|veth|virbr)/ {print $2; exit}')
if [[ -z "${PHYSICAL_INTERFACE}" ]]; then
  echo "Error: No physical network interface found"
  exit 1
fi

VXLAN_LOCAL_IP=$(ip -4 addr show "${PHYSICAL_INTERFACE}" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
if [[ -z "${VXLAN_LOCAL_IP}" ]]; then
  echo "Error: No IPv4 address found on interface ${PHYSICAL_INTERFACE}"
  exit 1
fi

echo "Starting VXLAN sink configuration..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

# Verify required tools
for cmd in ip tc; do
  if ! command -v "${cmd}" &>/dev/null; then
    echo "Error: '${cmd}' not found. Install the iproute2 package."
    exit 1
  fi
done

# Clean up existing interfaces if present (vxlan first to drop its qdisc/filters)
for IF in "${VXLAN_INTERFACE}" "${BRIDGE_INTERFACE}"; do
  if ip link show "${IF}" &>/dev/null; then
    echo "Removing existing interface ${IF}..."
    ip link set "${IF}" down 2>/dev/null || true
    ip link delete "${IF}" 2>/dev/null || true
  fi
done

# Create the bridge that will receive decapsulated inner frames
echo "Creating bridge ${BRIDGE_INTERFACE}..."
ip link add "${BRIDGE_INTERFACE}" type bridge
ip addr add "${BRIDGE_IP}" dev "${BRIDGE_INTERFACE}"
ip link set "${BRIDGE_INTERFACE}" up

# Create VXLAN interface in external (collect-metadata) mode.
# 'external' tells the kernel not to bind the netdev to a single VNI;
# the VNI is carried as tunnel metadata and handled by tc/eBPF.
echo "Creating VXLAN interface ${VXLAN_INTERFACE} on ${PHYSICAL_INTERFACE} (external mode, all VNIs)..."
ip link add "${VXLAN_INTERFACE}" type vxlan \
  external \
  dstport "${VXLAN_PORT}" \
  local "${VXLAN_LOCAL_IP}" \
  dev "${PHYSICAL_INTERFACE}"

ip link set "${VXLAN_INTERFACE}" up

# tc ingress: match every decapsulated packet, strip tunnel metadata,
# and redirect into the bridge.
echo "Installing tc flower rule to redirect all VNIs into ${BRIDGE_INTERFACE}..."
tc qdisc add dev "${VXLAN_INTERFACE}" ingress
tc filter add dev "${VXLAN_INTERFACE}" ingress \
  protocol all \
  flower \
  action tunnel_key unset \
  action mirred egress redirect dev "${BRIDGE_INTERFACE}"

# Configure firewall to accept VXLAN traffic on UDP/4789 from any source
echo "Configuring firewall rules for VXLAN..."
if ! command -v nft &>/dev/null; then
  echo "Error: nftables not found. Please install nftables package."
  exit 1
fi

nft add table inet vxlan 2>/dev/null || true
nft add chain inet vxlan input { type filter hook input priority 0 \; } 2>/dev/null || true
nft add rule inet vxlan input udp dport "${VXLAN_PORT}" accept
echo "Added nftables rule to accept UDP port ${VXLAN_PORT}"

# Display interface information
echo ""
echo "VXLAN sink ready!"
echo "================="
ip -d link show "${VXLAN_INTERFACE}"
echo ""
ip -d link show "${BRIDGE_INTERFACE}"
echo ""
tc filter show dev "${VXLAN_INTERFACE}" ingress
echo ""
echo "Physical Interface: ${PHYSICAL_INTERFACE}"
echo "Local IP:           ${VXLAN_LOCAL_IP}"
echo "VXLAN Interface:    ${VXLAN_INTERFACE} (external mode, accepts ALL VNIs)"
echo "VXLAN Port:         ${VXLAN_PORT}"
echo "Bridge:             ${BRIDGE_INTERFACE} (${BRIDGE_IP})"
echo ""
echo "Inspect decapsulated inner frames:"
echo "  tcpdump -i ${BRIDGE_INTERFACE}"
echo ""
echo "Inspect VXLAN-encapsulated packets (with outer headers + VNI):"
echo "  tcpdump -i ${PHYSICAL_INTERFACE} 'udp port ${VXLAN_PORT}'"
