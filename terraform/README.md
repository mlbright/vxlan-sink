# VXLAN Sink Terraform Module

Terraform module for deploying VXLAN sink instances into existing AWS VPCs.

## Features

- **Automatic AMI lookup** - Find latest AMI by name prefix, or use explicit AMI ID
- **Security by default** - SSH disabled unless explicitly enabled
- **No public IPs** - Instances are private-only
- **Flexible networking** - Works with any existing VPC/subnet

## Usage

### Basic (AMI Lookup)

```hcl
module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  vpc_id             = "vpc-xxx"
  subnet_id          = "subnet-xxx"
}
```

### With Explicit AMI

```hcl
module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  ami_id             = "ami-0123456789abcdef0"
  vpc_id             = "vpc-xxx"
  subnet_id          = "subnet-xxx"
}
```

### With SSH Access

```hcl
module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  vpc_id             = "vpc-xxx"
  subnet_id          = "subnet-xxx"
  ssh_source_cidrs   = ["10.0.0.0/8"]
  key_name           = "my-key-pair"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.13.4 |
| aws | ~> 6.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ami_id | Explicit AMI ID. If null, uses automatic lookup. | `string` | `null` | no |
| ami_name_prefix | AMI name prefix for automatic lookup | `string` | `"vxlan-graviton"` | no |
| instance_type | EC2 instance type (ARM64/Graviton) | `string` | `"t4g.nano"` | no |
| vpc_id | VPC ID to deploy into | `string` | n/a | **yes** |
| subnet_id | Subnet ID for the instance | `string` | n/a | **yes** |
| key_name | SSH key pair name | `string` | `null` | no |
| ssh_source_cidrs | CIDRs allowed SSH access (empty = disabled) | `list(string)` | `[]` | no |
| iam_instance_profile | IAM instance profile name | `string` | `null` | no |
| name | Name prefix for resources | `string` | `"vxlan-sink"` | no |
| tags | Additional tags for resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | EC2 instance ID |
| private_ip | Private IP address |
| security_group_id | Security group ID |
| ami_id | Resolved AMI ID |
| vxlan_endpoint | VXLAN endpoint (private_ip:4789) |

## Examples

- [explicit-ami](examples/explicit-ami/) - Deploy with known AMI ID
- [ami-lookup](examples/ami-lookup/) - Deploy with automatic AMI discovery

## Security

- **SSH is disabled by default** - Set `ssh_source_cidrs` to enable
- **No public IP** - Instances only have private IPs
- **VXLAN restricted** - Only specified CIDRs can send VXLAN traffic

## VXLAN Configuration

The deployed instance is pre-configured with:
- VXLAN ID: `1337`
- VXLAN Port: `4789` (standard)
- VXLAN Interface IP: `10.200.0.1/24`
- Interface name: `vxlan0`

The VXLAN service starts automatically on boot via systemd.
