# VXLAN Sink

A complete solution for deploying VXLAN receiver/sink virtual machines on AWS using Graviton (ARM64) instances.

## Overview

This repository provides two key capabilities:

1. **AMI Building** — Packer configuration to build a pre-configured VXLAN receiver AMI
2. **Terraform Module** — Deploy the VXLAN sink into any existing AWS VPC

### What is a VXLAN Sink?

A VXLAN sink is a virtual machine configured to receive VXLAN-encapsulated traffic. VXLAN (Virtual Extensible LAN) is an overlay network protocol that encapsulates Layer 2 Ethernet frames within UDP packets, enabling network virtualization across Layer 3 boundaries.

This implementation creates a `vxlan0` interface that:
- Listens on UDP port 4789 (standard VXLAN port)
- Uses VXLAN ID 1337
- Assigns IP 10.200.0.1/24 to the VXLAN interface
- Starts automatically on boot via systemd

### Why Graviton?

The AMI is built for AWS Graviton (ARM64) processors, specifically using `t4g.nano` instances—the cheapest EC2 instance type available—making this ideal for cost-sensitive network infrastructure.

---

## Repository Structure

```
vxlan-sink/
├── ami/                              # AMI building (Packer)
│   ├── graviton-vxlan-ami.pkr.hcl    # Main Packer configuration
│   ├── variables.pkrvars.hcl.example # Packer variables template
│   ├── vxlan-setup.sh                # Creates VXLAN interface
│   ├── vxlan-teardown.sh             # Removes VXLAN interface
│   ├── vxlan.service                 # Systemd unit file
│   └── install-vxlan-service.sh      # Manual installation script
│
├── terraform/                        # Terraform module for deployment
│   ├── main.tf                       # EC2 instance + security group
│   ├── variables.tf                  # Input variables
│   ├── outputs.tf                    # Output values
│   ├── versions.tf                   # Provider requirements
│   └── examples/                     # Usage examples
│       ├── explicit-ami/             # Deploy with known AMI ID
│       └── ami-lookup/               # Deploy with AMI auto-discovery
│
├── github-oidc/                      # AWS OIDC setup for GitHub Actions
│   └── github-oidc.tf                # IAM role + OIDC provider
│
├── .github/workflows/                # CI/CD automation
│   ├── build-ami.yml                 # Build and publish AMIs
│   └── cleanup-amis.yml              # Cost optimization
│
└── Makefile                          # Convenience commands
```

---

## Quick Start

### Option 1: Use Pre-built AMI with Terraform

If AMIs are already published (check [Releases](../../releases)), deploy directly:

```hcl
module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  vpc_id             = "vpc-0123456789abcdef0"
  subnet_id          = "subnet-0123456789abcdef0"
  vxlan_source_cidrs = ["10.0.0.0/8"]
}

output "vxlan_endpoint" {
  value = module.vxlan_sink.vxlan_endpoint
}
```

### Option 2: Build Your Own AMI

```bash
# Clone the repository
git clone https://github.com/mlbright/vxlan-sink.git
cd vxlan-sink

# Initialize and build
make init
make build

# The AMI ID will be in manifest.json
```

---

## Building the AMI

### Prerequisites

- [Packer](https://www.packer.io/) >= 1.10.0
- AWS credentials configured
- IAM permissions for EC2 AMI creation

### AMI Specifications

| Property | Value |
|----------|-------|
| Base Image | Ubuntu 24.04 LTS (Noble) |
| Architecture | ARM64 (Graviton) |
| Instance Type | t4g.nano (for building) |
| Volume | 8 GB gp3 |
| VXLAN Port | 4789 (UDP) |
| VXLAN ID | 1337 |
| VXLAN Interface | vxlan0 (10.200.0.1/24) |

### Build Commands

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

### Customizing VXLAN Configuration

Edit `ami/vxlan-setup.sh` before building:

```bash
VXLAN_ID="1337"           # Your VXLAN ID
VXLAN_PORT="4789"         # Your port
VXLAN_IP="10.200.0.1/24"  # Your VXLAN network
```

---

## Using the Terraform Module

The Terraform module deploys a VXLAN sink instance into an existing VPC.

### Module Source

```hcl
source = "github.com/mlbright/vxlan-sink//terraform"
```

### Basic Usage (Automatic AMI Lookup)

```hcl
module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  vpc_id             = "vpc-0123456789abcdef0"
  subnet_id          = "subnet-0123456789abcdef0"
  vxlan_source_cidrs = ["10.0.0.0/8"]
}
```

### With Explicit AMI ID

```hcl
module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  ami_id             = "ami-0123456789abcdef0"
  vpc_id             = "vpc-0123456789abcdef0"
  subnet_id          = "subnet-0123456789abcdef0"
  vxlan_source_cidrs = ["10.0.0.0/8"]
}
```

### With SSH Access Enabled

```hcl
module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  vpc_id             = "vpc-0123456789abcdef0"
  subnet_id          = "subnet-0123456789abcdef0"
  vxlan_source_cidrs = ["10.0.0.0/8"]

  # Enable SSH (disabled by default)
  ssh_source_cidrs   = ["10.0.0.0/8"]
  key_name           = "my-key-pair"
}
```

### Module Inputs

| Variable | Type | Default | Required | Description |
|----------|------|---------|:--------:|-------------|
| `ami_id` | string | `null` | No | Explicit AMI ID (if null, uses lookup) |
| `ami_name_prefix` | string | `"vxlan-graviton"` | No | AMI name prefix for automatic lookup |
| `instance_type` | string | `"t4g.nano"` | No | EC2 instance type (ARM64/Graviton) |
| `vpc_id` | string | — | **Yes** | VPC ID to deploy into |
| `subnet_id` | string | — | **Yes** | Subnet ID for the instance |
| `key_name` | string | `null` | No | SSH key pair name |
| `vxlan_source_cidrs` | list(string) | — | **Yes** | CIDRs allowed VXLAN traffic (UDP 4789) |
| `ssh_source_cidrs` | list(string) | `[]` | No | CIDRs allowed SSH access (empty = disabled) |
| `iam_instance_profile` | string | `null` | No | IAM instance profile name |
| `name` | string | `"vxlan-sink"` | No | Name prefix for resources |
| `tags` | map(string) | `{}` | No | Additional tags for resources |

### Module Outputs

| Output | Description |
|--------|-------------|
| `instance_id` | EC2 instance ID |
| `private_ip` | Private IP address |
| `security_group_id` | Security group ID |
| `ami_id` | Resolved AMI ID (from explicit or lookup) |
| `vxlan_endpoint` | VXLAN endpoint (`private_ip:4789`) |

### Examples

See [terraform/examples/](terraform/examples/) for complete working examples:

- [explicit-ami](terraform/examples/explicit-ami/) — Deploy with a known AMI ID
- [ami-lookup](terraform/examples/ami-lookup/) — Deploy with automatic AMI discovery

---

## CI/CD with GitHub Actions

The repository includes automated workflows for building and publishing AMIs.

### Features

- ✅ **OIDC Authentication** — No long-lived AWS credentials
- ✅ **Multi-Region** — Build AMIs in US East, US West, and EU West simultaneously
- ✅ **Automatic Publishing** — Make AMIs public on tagged releases
- ✅ **Validation** — Packer validation on all PRs
- ✅ **GitHub Releases** — Automatic release creation with AMI IDs

### Workflow Triggers

| Trigger | When | What Happens |
|---------|------|--------------|
| Push to `main` | Code merged | Builds dev AMIs (private) |
| Push tag `v*` | Release tag created | Builds public AMIs, creates GitHub release |
| Pull Request | PR opened/updated | Validates Packer config only |
| Manual | workflow_dispatch | Configurable regions and visibility |

### Setting Up CI/CD

1. **Configure AWS OIDC**

   ```bash
   cd github-oidc/
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your GitHub org/repo
   terraform init
   terraform apply
   ```

2. **Add GitHub Secret**

   Copy the IAM role ARN from Terraform output and add it as `AWS_ROLE_ARN` secret in your repository settings.

3. **Create a Release**

   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

### AMI Naming Convention

```
vxlan-graviton-{VERSION}

Examples:
- Tagged release: vxlan-graviton-v1.0.0
- Dev build:      vxlan-graviton-dev-20260124-a1b2c3d
```

---

## Security

### Network Security

- **SSH disabled by default** — Must explicitly set `ssh_source_cidrs` to enable
- **No public IPs** — Instances only have private IPs
- **VXLAN restricted** — Only specified CIDRs can send VXLAN traffic

### OIDC Authentication

- No long-lived AWS credentials stored
- Repository-scoped access
- Automatic credential expiration (1 hour)

### IAM Permissions

The GitHub Actions role uses least-privilege permissions:
- Launch EC2 instances for AMI building
- Create AMIs and snapshots
- Modify AMI attributes (make public)

### Systemd Security

The VXLAN service runs with restricted capabilities:
- Only `NET_ADMIN` and `NET_RAW` capabilities
- Private temp directories
- Protected system paths

---

## Cost

### AMI Build Cost

| Component | Cost |
|-----------|------|
| EC2 t4g.nano (~15 min) | ~$0.001 |
| EBS during build | ~$0.001 |
| **Total per build** | **~$0.002** |

### Running Instance Cost

| Component | Cost |
|-----------|------|
| t4g.nano (hourly) | ~$0.0042/hour |
| t4g.nano (monthly) | ~$3.00/month |

### Storage Cost

| Component | Cost |
|-----------|------|
| AMI storage | ~$0.10/month per AMI |
| Snapshots | ~$0.05/GB/month |

**Example (3 regions, 5 AMI versions):**
15 AMIs × $0.10 = **$1.50/month**

Use the cleanup workflow to automatically delete old AMIs.

---

## Troubleshooting

### "Could not retrieve caller identity"

**Cause:** AWS OIDC not configured correctly

**Fix:**
1. Verify `AWS_ROLE_ARN` secret exists in GitHub
2. Check IAM role trust policy allows your repository
3. Re-run `terraform apply` in `github-oidc/`

### "UnauthorizedOperation" during build

**Cause:** IAM role lacks permissions

**Fix:**
```bash
cd github-oidc/
terraform apply  # Reapply to update permissions
```

### AMI not public after release

**Check:**
1. Tag starts with `v` (e.g., `v1.0.0`)
2. Review workflow logs for "Make AMI public" step

**Manual fix:**
```bash
aws ec2 modify-image-attribute \
  --image-id ami-xxxxx \
  --launch-permission "Add=[{Group=all}]"
```

### Can't find AMI

**Check correct region:**
```bash
aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=vxlan-graviton-*" \
  --region us-east-1
```

---

## References

- [VXLAN RFC 7348](https://tools.ietf.org/html/rfc7348)
- [Packer Documentation](https://www.packer.io/docs)
- [AWS Graviton](https://aws.amazon.com/ec2/graviton/)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

## License

This project is provided as-is for educational and operational use.
