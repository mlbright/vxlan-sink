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

# Variables
variable "aws_region" {
  description = "AWS region for OIDC provider"
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "oidc_provider_exists" {
  description = "Set to true if GitHub OIDC provider already exists in your AWS account"
  type        = bool
  default     = false
}

# GitHub OIDC Provider
# Note: You can only have one OIDC provider per AWS account for GitHub
resource "aws_iam_openid_connect_provider" "github" {
  count = var.oidc_provider_exists ? 0 : 1

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name      = "GitHub Actions OIDC Provider"
    ManagedBy = "Terraform"
    Purpose   = "GitHub Actions OIDC Authentication"
  }
}

# Data source to reference existing OIDC provider if it exists
data "aws_iam_openid_connect_provider" "github" {
  count = var.oidc_provider_exists ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.oidc_provider_exists ? data.aws_iam_openid_connect_provider.github[0].arn : aws_iam_openid_connect_provider.github[0].arn
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name        = "GitHubActions-PackerAMIBuilder"
  description = "Role for GitHub Actions to build and publish AMIs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  max_session_duration = 3600 # 1 hour

  tags = {
    Name       = "GitHub Actions Packer AMI Builder"
    ManagedBy  = "Terraform"
    Repository = "${var.github_org}/${var.github_repo}"
  }
}

# IAM Policy for Packer AMI building
resource "aws_iam_policy" "packer_ami_builder" {
  name        = "PackerAMIBuilder"
  description = "Policy for Packer to build AMIs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 permissions for Packer
      {
        Sid    = "PackerEC2Permissions"
        Effect = "Allow"
        Action = [
          "ec2:AttachVolume",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CopyImage",
          "ec2:CreateImage",
          "ec2:CreateKeypair",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteKeyPair",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteSnapshot",
          "ec2:DeleteVolume",
          "ec2:DeregisterImage",
          "ec2:DescribeImageAttribute",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeRegions",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSnapshots",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DetachVolume",
          "ec2:GetPasswordData",
          "ec2:ModifyImageAttribute",
          "ec2:ModifyInstanceAttribute",
          "ec2:ModifySnapshotAttribute",
          "ec2:RegisterImage",
          "ec2:RunInstances",
          "ec2:StopInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
      # SSM permissions for session management (optional, for debugging)
      {
        Sid    = "PackerSSMPermissions"
        Effect = "Allow"
        Action = [
          "ssm:DescribeParameters",
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "*"
      },
      # IAM permissions to pass roles (if needed)
      {
        Sid    = "PackerIAMPassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      },
      # STS permissions for session info
      {
        Sid    = "STSGetCallerIdentity"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name      = "Packer AMI Builder Policy"
    ManagedBy = "Terraform"
  }
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "github_actions_packer" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.packer_ami_builder.arn
}

# Optional: Additional policy for multi-region AMI copying
resource "aws_iam_policy" "ami_multi_region" {
  name        = "PackerAMIMultiRegion"
  description = "Additional permissions for multi-region AMI operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MultiRegionAMI"
        Effect = "Allow"
        Action = [
          "ec2:CopyImage",
          "ec2:DescribeImages",
          "ec2:CreateTags",
          "ec2:ModifyImageAttribute"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name      = "Packer Multi-Region AMI Policy"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_multi_region" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.ami_multi_region.arn
}

# Outputs
output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = local.oidc_provider_arn
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions (set this as AWS_ROLE_ARN secret)"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "Name of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.name
}

output "next_steps" {
  description = "Instructions for completing the setup"
  value       = <<-EOT
    
    ╔════════════════════════════════════════════════════════════════════╗
    ║  GitHub OIDC Setup Complete!                                       ║
    ╚════════════════════════════════════════════════════════════════════╝
    
    Next Steps:
    
    1. Add this secret to your GitHub repository:
       
       Name:  AWS_ROLE_ARN
       Value: ${aws_iam_role.github_actions.arn}
       
       Go to: https://github.com/${var.github_org}/${var.github_repo}/settings/secrets/actions
    
    2. The GitHub Actions workflow is ready to use!
       
       - Push to main branch to build dev AMIs
       - Push a tag (v*) to build and publish release AMIs
       - Use workflow_dispatch for manual builds
    
    3. Role ARN: ${aws_iam_role.github_actions.arn}
    
    4. Test the workflow:
       git tag v1.0.0
       git push origin v1.0.0
    
  EOT
}
