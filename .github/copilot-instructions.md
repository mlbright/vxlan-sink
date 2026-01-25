# Copilot Instructions for vxlan-sink

## Project Overview

This repository builds and deploys a VXLAN receiver/sink on AWS Graviton (ARM64) instances. It has two main components:

1. **AMI Builder** (`ami/`) - Packer configuration creating Ubuntu 24.04 ARM64 AMIs with VXLAN systemd service
2. **Terraform Module** (`terraform/`) - Deploys VXLAN sink EC2 instances with security groups

The VXLAN interface listens on UDP 4789, uses VNI 1337, and auto-detects the physical network interface at runtime.

## Architecture & Data Flow

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│  Packer Build   │ ──▶  │  AMI Published   │ ──▶  │ Terraform Deploy│
│  (ami/*.pkr.hcl)│      │  (us-east-1, etc)│      │  (t4g.nano EC2) │
└─────────────────┘      └──────────────────┘      └─────────────────┘
                                                            │
                                                            ▼
                                              ┌─────────────────────────┐
                                              │ vxlan.service (systemd) │
                                              │ → vxlan-setup.sh        │
                                              │ → vxlan0 interface      │
                                              └─────────────────────────┘
```

## Key Commands

```bash
# AMI Building (requires AWS credentials)
make init          # Initialize Packer plugins
make validate      # Validate Packer config
make build         # Build AMI with t4g.nano (cheapest)
make show-ami      # Show AMI ID from manifest.json

# Local VXLAN Testing (requires sudo)
sudo make test-vxlan    # Creates vxlan0, waits for Enter, then tears down
sudo make install-vxlan # Install systemd service locally
```

## Critical Conventions

### VXLAN Configuration (Hardcoded in `ami/vxlan-setup.sh`)
- Interface: `vxlan0`
- VNI: `1337`
- Port: `4789` (standard VXLAN)
- Physical interface: Auto-detected at runtime (first non-loopback, non-virtual)

### Instance Types
Always use `t4g.*` (Graviton/ARM64). Default is `t4g.nano` for cost optimization. The AMI is ARM64-only.

### Terraform Module Patterns
- `ami_id = null` triggers automatic AMI lookup by `ami_name_prefix`
- `ssh_source_cidrs = []` (default) disables SSH access entirely
- Required inputs: `vpc_id`, `subnet_id`, `vxlan_source_cidrs`

### File Naming
- Packer: `ami/graviton-vxlan-ami.pkr.hcl`
- Terraform module: `terraform/main.tf` (consumed as `github.com/mlbright/vxlan-sink//terraform`)

## CI/CD (GitHub Actions)

- **Build trigger**: Git tags matching `v*` build AMIs to us-east-1, us-west-2, eu-west-1
- **Auth**: OIDC via `github-oidc/github-oidc.tf` (no static credentials)
- **Outputs**: `manifest.json` contains built AMI details
- **Versioning**: Tags use `vX.Y.Z`, branches use `dev-YYYYMMDD-<sha>`

## VXLAN Runtime Usage

The `vxlan0` interface is created in "nolearning" mode without an assigned IP.
This is a headless receiver configuration.
To use the overlay network:

```bash
# Assign an IP to the VXLAN interface (if needed for bidirectional traffic)
sudo ip addr add 10.200.0.1/24 dev vxlan0

# Add remote VXLAN endpoints to the forwarding database
sudo bridge fdb append 00:00:00:00:00:00 dev vxlan0 dst <REMOTE_VTEP_IP>

# View current FDB entries
bridge fdb show dev vxlan0
```

The interface auto-binds to the detected physical interface's IP as the local VTEP address.

## First-Time AWS Account Setup (OIDC)

Before CI/CD works, deploy the OIDC infrastructure in `github-oidc/`:

```bash
cd github-oidc
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your github_org and github_repo

terraform init
terraform apply
```

This creates:
- GitHub OIDC provider (one per AWS account)
- `GitHubActions-PackerAMIBuilder` IAM role with Packer permissions
- Multi-region AMI copy permissions

After apply, add the output `github_actions_role_arn` as `AWS_ROLE_ARN` secret in GitHub repo settings.
Set `oidc_provider_exists = true` if you already have a GitHub OIDC provider in your account.

## Multi-Region AMI Builds

Default regions in `.github/workflows/build-ami.yml` matrix:
- `us-east-1` (primary)
- `us-west-2`
- `eu-west-1`

To add regions:
1. Add region to the `matrix.region` array in the workflow
2. Ensure the OIDC role has permissions in that region (already granted via `Resource = "*"`)

Manual builds support custom regions via `workflow_dispatch`:
```
regions: "us-east-1,ap-southeast-1,eu-central-1"
```

AMIs are made public automatically on tagged releases (`v*`).
Each region build runs in parallel with `max-parallel: 3`.

## When Modifying

1. **Changing VXLAN parameters**: Edit `ami/vxlan-setup.sh` and `ami/vxlan-teardown.sh` together
2. **Adding regions**: Update `.github/workflows/build-ami.yml` matrix
3. **Terraform variables**: Mirror defaults between `terraform/variables.tf` and `ami/graviton-vxlan-ami.pkr.hcl` (e.g., `ami_name_prefix = "vxlan-graviton"`)
4. **Security hardening**: The systemd unit in `ami/vxlan.service` uses `ProtectSystem=strict` - scripts need explicit `ReadWritePaths`
5. **markdown files**: Write one sentence per line for easy diffs