# AMI Lookup Example

This example demonstrates deploying a VXLAN sink instance using automatic AMI lookup by name prefix.

The module will find the most recent AMI matching the `ami_name_prefix` pattern owned by your account.

## Usage

```hcl
module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  # No ami_id specified - will look up by prefix
  ami_name_prefix    = "vxlan-graviton"
  vpc_id             = "vpc-xxx"
  subnet_id          = "subnet-xxx"

  # Optional: Enable SSH access
  # ssh_source_cidrs = ["10.0.0.0/8"]
  # key_name         = "my-key-pair"

  tags = {
    Environment = "production"
  }
}
```

## Prerequisites

- An AMI must exist in your account matching the `ami_name_prefix` pattern
- Build the AMI using the Packer configuration in the repository root

## Steps

1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Edit values to match your environment
3. Run `terraform init`
4. Run `terraform plan`
5. Run `terraform apply`
