# VXLAN Sink

This repository provides two key capabilities:

1. **AMI Building** — Packer configuration to build a pre-configured VXLAN sink/receiver AMI
2. **Terraform Module** — Deploy the VXLAN sink into any existing AWS VPC

### What do you mean by a VXLAN Sink?

A virtual machine configured to receive VXLAN-encapsulated traffic.
VXLAN (Virtual Extensible LAN) is an overlay network protocol that encapsulates Layer 2 Ethernet frames within UDP packets, enabling network virtualization across Layer 3 boundaries.

This implementation creates a `vxlan0` interface that:

- Listens on UDP port 4789 (standard VXLAN port)
- Uses VXLAN ID 1337
- Starts automatically on boot via systemd

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

### Deployment with Terraform

Note: If AMIs are not yet published, see "Building the AMI" section below.

```hcl
module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  vpc_id             = "vpc-0123456789abcdef0"
  subnet_id          = "subnet-0123456789abcdef0"
}

output "vxlan_endpoint" {
  value = module.vxlan_sink.vxlan_endpoint
}
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
# Create a pull request
git checkout -b feature/my-changes
git push origin feature/my-changes
# Open PR on GitHub
```

This will:
1. ✅ Validate Packer configuration
2. ✅ Format check
3. ❌ No AMI build (saves costs)

### Manual Build

1. Go to **Actions** tab
2. Select **Build and Publish Graviton VXLAN AMI**
3. Click **Run workflow**
4. Configure:
   - Branch: `main`
   - Regions: `us-east-1,eu-central-1` (or leave default)
   - Make Public: ✓ (optional)
5. Click **Run workflow**

## Workflow Jobs Explained

### Job: `validate`

**Runs on**: All pushes and PRs

```yaml
Steps:
1. Checkout code
2. Setup Packer
3. Initialize Packer plugins
4. Validate configuration
5. Check formatting
```

**Purpose**: Catch configuration errors early without incurring AMI build costs.

### Job: `build-ami`

**Runs on**: Pushes to main/release branches, tags, manual dispatch

**Matrix Strategy**: Builds in parallel across regions
- `us-east-1` - US East (N. Virginia)
- `us-west-2` - US West (Oregon)  
- `eu-west-1` - EU (Ireland)

```yaml
Steps:
1. Checkout code
2. Setup Packer
3. Assume AWS role via OIDC
4. Verify AWS credentials
5. Build AMI with Packer
6. Tag AMI with metadata
7. Make AMI public (if tag/manual)
8. Upload manifest artifact
9. Generate summary
```

**Output**: AMI ID per region, saved in artifacts

### Job: `create-release`

**Runs on**: Tag pushes (`v*`) only

```yaml
Steps:
1. Download all manifests
2. Generate release notes with AMI IDs
3. Create GitHub release
4. Attach manifest files
```

**Output**: GitHub release with:
- AMI IDs for all regions
- Launch instructions
- Feature list
- Manifest JSON files

## GitHub Release Format

When you push a tag, the workflow creates a release like this:

```markdown
# Graviton VXLAN AMI Release v1.0.0

## AMI IDs by Region

- **us-east-1**: `ami-0123456789abcdef0`
- **us-west-2**: `ami-0fedcba9876543210`
- **eu-west-1**: `ami-0a1b2c3d4e5f67890`

## Launch Instance

```bash
aws ec2 run-instances \
  --image-id <AMI_ID_FROM_ABOVE> \
  --instance-type t4g.nano \
  --key-name YOUR_KEY_PAIR \
  --security-group-ids YOUR_SECURITY_GROUP \
  --subnet-id YOUR_SUBNET
```

## Features
- VXLAN interface pre-configured (vxlan0) in external/collect-metadata mode (accepts ALL VNIs)
- Linux bridge (br0) receives decapsulated inner frames via a tc flower ingress redirect
- Systemd service for automatic startup
- UDP port 4789 open for VXLAN traffic
- Capture decapsulated traffic with `tcpdump -i br0`; capture encapsulated traffic with `tcpdump -i <eth> 'udp port 4789'`
...
```

## Customizing Regions

### Change Default Regions

Edit `.github/workflows/build-ami.yml`:

```yaml
strategy:
  matrix:
    region: 
      - us-east-1
      - ap-south-1      # Add Mumbai
      - eu-central-1    # Add Frankfurt
```

### Build in Single Region

For testing/cost savings, temporarily edit to single region:

```yaml
strategy:
  matrix:
    region: 
      - us-east-1  # Only build here
```

Or use **workflow_dispatch** to specify regions manually.

## AMI Naming Convention

AMIs are named using this pattern:

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
