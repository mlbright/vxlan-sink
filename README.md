# VXLAN Interface with Systemd & AWS Graviton AMI Builder

This repository contains scripts to configure a VXLAN interface on Linux with systemd integration, and a Packer configuration to build AWS AMIs on Graviton (ARM64) instances.

## Contents

### VXLAN Scripts

1. **vxlan-setup.sh** - Bash script that configures a VXLAN interface
   - Creates a VXLAN interface (vxlan0) on port 4789
   - Sets up a bridge interface (br-vxlan)
   - Configures firewall rules to accept traffic from any source
   - Supports both nftables and iptables

2. **vxlan-teardown.sh** - Cleanup script to remove VXLAN configuration
   - Removes VXLAN and bridge interfaces
   - Cleans up firewall rules

3. **vxlan.service** - Systemd service unit file
   - Ensures VXLAN interface comes up at boot
   - Includes security hardening
   - Proper dependency management

4. **install-vxlan-service.sh** - Installation helper script
   - Installs all components to appropriate system locations
   - Enables the systemd service

### Packer Configuration

1. **graviton-vxlan-ami.pkr.hcl** - Main Packer HCL2 configuration
   - Builds an AWS AMI using Graviton (ARM64) instances
   - Uses t4g.nano (cheapest Graviton instance type)
   - Pre-installs and configures VXLAN setup
   - Based on Ubuntu 22.04 ARM64

2. **variables.pkrvars.hcl.example** - Example variables file
   - Customizable configuration options

## Prerequisites

### For VXLAN Setup
- Linux system with systemd
- Root access
- `iproute2` package installed
- Either `nftables` or `iptables` for firewall configuration

### For Packer
- [Packer](https://www.packer.io/) >= 1.9.0
- AWS credentials configured (`~/.aws/credentials` or environment variables)
- AWS account with permissions to create AMIs

## VXLAN Configuration Details

### Default Settings
- **VXLAN Interface**: vxlan0
- **VXLAN ID**: 100
- **VXLAN Port**: 4789 (UDP)
- **Bridge Interface**: br-vxlan
- **Bridge IP**: 10.200.0.1/24
- **Physical Interface**: eth0 (modify in script if needed)

### Customization
Edit the variables at the top of `vxlan-setup.sh`:

```bash
VXLAN_INTERFACE="vxlan0"
VXLAN_ID="100"
VXLAN_PORT="4789"
VXLAN_DEV="eth0"  # Change to your interface name
BRIDGE_IP="10.200.0.1/24"  # Change to your desired network
```

## Installation & Usage

### Manual VXLAN Setup

1. **Edit configuration** (if needed):
   ```bash
   vim vxlan-setup.sh
   # Modify VXLAN_DEV to match your network interface
   # Modify BRIDGE_IP to match your desired network
   ```

2. **Make scripts executable**:
   ```bash
   chmod +x vxlan-setup.sh vxlan-teardown.sh install-vxlan-service.sh
   ```

3. **Install systemd service**:
   ```bash
   sudo ./install-vxlan-service.sh
   ```

4. **Start the service**:
   ```bash
   sudo systemctl start vxlan.service
   ```

5. **Check status**:
   ```bash
   sudo systemctl status vxlan.service
   ```

6. **View logs**:
   ```bash
   sudo journalctl -u vxlan.service -f
   ```

### Adding Remote VXLAN Endpoints

After the VXLAN interface is up, add remote endpoints:

```bash
# Add a remote VXLAN endpoint
sudo bridge fdb append 00:00:00:00:00:00 dev vxlan0 dst <REMOTE_IP>

# Example:
sudo bridge fdb append 00:00:00:00:00:00 dev vxlan0 dst 192.168.1.100
```

### Manual Testing (Without Systemd)

```bash
# Run setup script directly
sudo ./vxlan-setup.sh

# Verify configuration
ip -d link show vxlan0
ip addr show br-vxlan

# Test with tcpdump
sudo tcpdump -i vxlan0 -n

# Clean up
sudo ./vxlan-teardown.sh
```

## Building AWS Graviton AMI with Packer

### Setup

1. **Configure AWS credentials**:
   ```bash
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_DEFAULT_REGION="us-east-1"
   ```

   Or configure via `~/.aws/credentials`

2. **Customize variables** (optional):
   ```bash
   cp variables.pkrvars.hcl.example variables.auto.pkrvars.hcl
   vim variables.auto.pkrvars.hcl
   ```

### Build AMI

1. **Initialize Packer**:
   ```bash
   packer init graviton-vxlan-ami.pkr.hcl
   ```

2. **Validate configuration**:
   ```bash
   packer validate graviton-vxlan-ami.pkr.hcl
   ```

3. **Build AMI**:
   ```bash
   packer build graviton-vxlan-ami.pkr.hcl
   ```

   With custom variables:
   ```bash
   packer build -var-file=variables.auto.pkrvars.hcl graviton-vxlan-ami.pkr.hcl
   ```

4. **Check output**:
   - AMI ID will be displayed at the end of the build
   - Check `manifest.json` for build details

### Using Different Graviton Instance Types

The default is `t4g.nano` (cheapest), but you can use:

```bash
# Via command line
packer build -var="instance_type=t4g.micro" graviton-vxlan-ami.pkr.hcl

# Or edit variables file
instance_type = "t4g.small"
```

**Graviton Instance Options** (ARM64):
- `t4g.nano` - 2 vCPU, 0.5 GB RAM (cheapest)
- `t4g.micro` - 2 vCPU, 1 GB RAM
- `t4g.small` - 2 vCPU, 2 GB RAM
- `t4g.medium` - 2 vCPU, 4 GB RAM
- `t4g.large` - 2 vCPU, 8 GB RAM
- `c7g.medium` - Compute optimized
- `m7g.medium` - General purpose
- `r7g.medium` - Memory optimized

## Firewall Configuration

The setup script automatically configures firewall rules to accept VXLAN traffic on UDP port 4789.

### nftables (preferred)
```bash
# View rules
sudo nft list table inet vxlan

# Manually add rule
sudo nft add table inet vxlan
sudo nft add chain inet vxlan input { type filter hook input priority 0 \; }
sudo nft add rule inet vxlan input udp dport 4789 accept
```

### iptables (fallback)
```bash
# View rules
sudo iptables -L -n | grep 4789

# Manually add rule
sudo iptables -A INPUT -p udp --dport 4789 -j ACCEPT
sudo iptables-save > /etc/iptables/rules.v4
```

## Security Considerations

1. **VXLAN accepts traffic from ANY source** - This is by design but consider:
   - Using AWS Security Groups to restrict source IPs
   - Implementing additional network ACLs
   - Using IPsec or WireGuard for VXLAN tunnel encryption

2. **Systemd Security Hardening** - The service includes:
   - Capability restrictions (only NET_ADMIN and NET_RAW)
   - Private temp directories
   - Protected system directories
   - No new privileges

3. **AWS Security Groups** - When using the AMI, configure security groups:
   ```bash
   # Allow VXLAN from specific CIDR
   aws ec2 authorize-security-group-ingress \
     --group-id sg-xxxxx \
     --protocol udp \
     --port 4789 \
     --cidr 10.0.0.0/8
   ```

## Troubleshooting

### VXLAN Interface Issues

```bash
# Check if interface exists
ip link show vxlan0

# Check systemd service status
sudo systemctl status vxlan.service

# View detailed logs
sudo journalctl -u vxlan.service -n 50

# Check physical interface
ip addr show eth0

# Verify kernel modules
lsmod | grep vxlan
```

### Firewall Issues

```bash
# Check nftables rules
sudo nft list ruleset

# Check iptables rules
sudo iptables -L -n -v

# Test connectivity
sudo tcpdump -i eth0 udp port 4789
```

### Packer Build Issues

```bash
# Enable debug logging
export PACKER_LOG=1
packer build graviton-vxlan-ami.pkr.hcl

# Validate configuration
packer validate -syntax-check graviton-vxlan-ami.pkr.hcl

# Check AWS credentials
aws sts get-caller-identity

# Verify AMI availability
aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*" --query 'Images[0].ImageId'
```

## Advanced Configuration

### Multi-VXLAN Setup

To run multiple VXLAN interfaces, create additional service files:

```bash
# Copy and modify for second VXLAN
sudo cp /etc/systemd/system/vxlan.service /etc/systemd/system/vxlan2.service
sudo vim /etc/systemd/system/vxlan2.service
# Update VXLAN_ID, VXLAN_INTERFACE, etc.

# Create a separate script with different parameters
sudo cp /usr/local/bin/vxlan-setup.sh /usr/local/bin/vxlan2-setup.sh
# Modify parameters in the new script

sudo systemctl daemon-reload
sudo systemctl enable vxlan2.service
sudo systemctl start vxlan2.service
```

### Integration with Docker/Kubernetes

The VXLAN interface can be used with containers:

```bash
# Connect container to VXLAN bridge
docker run -d --name test --network=bridge \
  --ip 10.200.0.10 \
  alpine sleep 3600

# Add container to VXLAN bridge
sudo ip link set dev veth... master br-vxlan
```

## References

- [VXLAN RFC 7348](https://tools.ietf.org/html/rfc7348)
- [Linux VXLAN Documentation](https://www.kernel.org/doc/Documentation/networking/vxlan.txt)
- [Packer Documentation](https://www.packer.io/docs)
- [AWS Graviton](https://aws.amazon.com/ec2/graviton/)
- [systemd.service Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)

## License

These scripts are provided as-is for educational and operational use.
