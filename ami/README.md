# VXLAN Sink AMI

Packer configuration and scripts for building a Graviton-based VXLAN receiver/sink AMI.

## Files

| File | Purpose |
|------|---------|
| `graviton-vxlan-ami.pkr.hcl` | Main Packer configuration |
| `variables.pkrvars.hcl.example` | Example Packer variables file |
| `vxlan-setup.sh` | Script to create VXLAN interface |
| `vxlan-teardown.sh` | Script to remove VXLAN interface |
| `vxlan.service` | Systemd unit file for VXLAN service |
| `install-vxlan-service.sh` | Manual installation script |

## AMI Specifications

- **Base Image**: Ubuntu 24.04 LTS (Noble)
- **Architecture**: ARM64 (Graviton)
- **Default Instance Type**: t4g.nano
- **Volume**: 8 GB gp3

## VXLAN Configuration

The AMI is pre-configured with:

| Setting | Value |
|---------|-------|
| VXLAN ID | 1337 |
| VXLAN Port | 4789 (standard) |
| Interface IP | 10.200.0.1/24 |
| Interface Name | vxlan0 |

## Building the AMI

### Prerequisites

- [Packer](https://www.packer.io/) >= 1.10.0
- AWS credentials configured
- IAM permissions for EC2 AMI creation

### Build Commands

From the repository root:

```bash
# Initialize Packer plugins
make init

# Validate configuration
make validate

# Build AMI (default: t4g.nano in us-east-1)
make build

# Build with specific instance type
make build-micro   # t4g.micro
make build-small   # t4g.small

# Build in specific region
make build-region REGION=us-west-2
```

### Direct Packer Commands

```bash
# From repository root
packer init ami/graviton-vxlan-ami.pkr.hcl
packer validate ami/graviton-vxlan-ami.pkr.hcl
packer build ami/graviton-vxlan-ami.pkr.hcl

# With custom variables
packer build \
  -var "aws_region=eu-west-1" \
  -var "instance_type=t4g.micro" \
  ami/graviton-vxlan-ami.pkr.hcl
```

## Manual Installation

To install the VXLAN service on an existing Ubuntu system:

```bash
cd ami/
sudo ./install-vxlan-service.sh
```

## Testing VXLAN Setup

```bash
# From repository root
sudo make test-vxlan
```

This will:
1. Create the VXLAN interface
2. Wait for you to press Enter
3. Tear down the interface

## Output

After a successful build, `manifest.json` is created in the repository root containing:
- AMI ID
- Region
- Instance type used for build
- AMI name
