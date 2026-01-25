# Explicit AMI Example

This example demonstrates deploying a VXLAN sink instance using an explicit AMI ID.

## Usage

```hcl
module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  ami_id             = "ami-0123456789abcdef0"
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

## Steps

1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Edit values to match your environment
3. Run `terraform init`
4. Run `terraform plan`
5. Run `terraform apply`
