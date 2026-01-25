terraform {
  required_version = ">= 1.13.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "Explicit AMI ID for the VXLAN sink instance"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the VXLAN sink instance will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the VXLAN sink instance"
  type        = string
}

variable "ssh_source_cidrs" {
  description = "List of CIDR blocks allowed SSH access"
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = null
}

module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  ami_id             = var.ami_id
  vpc_id             = var.vpc_id
  subnet_id          = var.subnet_id
  ssh_source_cidrs   = var.ssh_source_cidrs
  key_name           = var.key_name

  tags = {
    Environment = "example"
    Example     = "explicit-ami"
  }
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = module.vxlan_sink.instance_id
}

output "private_ip" {
  description = "Private IP address"
  value       = module.vxlan_sink.private_ip
}

output "vxlan_endpoint" {
  description = "VXLAN endpoint"
  value       = module.vxlan_sink.vxlan_endpoint
}
