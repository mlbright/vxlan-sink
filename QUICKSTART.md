# Quick Start Guide

This guide walks you through setting up automated AMI building and publishing using GitHub Actions with AWS OIDC authentication.

## Prerequisites

- ✅ AWS account with admin access
- ✅ GitHub account and repository
- ✅ AWS CLI installed and configured
- ✅ Terraform installed (>= 1.5.0)
- ✅ Git installed

## 📋 Overview

You'll complete these steps:

1. Clone/setup repository
2. Configure AWS OIDC provider
3. Add GitHub secret
4. Build your first AMI
5. Publish a release

**Time to complete:** ~15 minutes

---

## Step 1: Repository Setup

### 1.1 Clone or Create Repository

```bash
# If using an existing repository
git clone https://github.com/YOUR-ORG/YOUR-REPO.git
cd YOUR-REPO

# Copy all files from this project into your repo
```

### 1.2 Verify File Structure

```bash
tree -L 2 -a
```

Expected structure:
```
.
├── .github/
│   └── workflows/
│       ├── build-ami.yml
│       ├── cleanup-amis.yml
│       └── README.md
├── terraform/
│   ├── github-oidc.tf
│   ├── terraform.tfvars.example
│   └── README.md
├── vxlan-setup.sh
├── vxlan-teardown.sh
├── vxlan.service
├── install-vxlan-service.sh
├── graviton-vxlan-ami.pkr.hcl
├── variables.pkrvars.hcl.example
├── Makefile
├── README.md
├── QUICKSTART.md
└── .gitignore
```

---

## Step 2: Configure AWS OIDC Provider

### 2.1 Configure Terraform Variables

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region = "us-east-1"
github_org = "your-github-username"    # Replace with your GitHub username/org
github_repo = "vxlan-ami-builder"      # Replace with your repo name
oidc_provider_exists = false           # Set to true if you already use GitHub OIDC
```

### 2.2 Initialize Terraform

```bash
terraform init
```

### 2.3 Review Plan

```bash
terraform plan
```

You should see resources to be created:
- `aws_iam_openid_connect_provider.github` (if oidc_provider_exists=false)
- `aws_iam_role.github_actions`
- `aws_iam_policy.packer_ami_builder`
- Related attachments

### 2.4 Apply Configuration

```bash
terraform apply
```

Type `yes` to confirm.

### 2.5 Copy Role ARN

Terraform will output:

```
Outputs:

github_actions_role_arn = "arn:aws:iam::123456789012:role/GitHubActions-PackerAMIBuilder"
```

**📋 Copy this ARN** - you'll need it in the next step.

---

## Step 3: Add GitHub Secret

### 3.1 Navigate to Repository Settings

1. Go to your GitHub repository
2. Click **Settings** (top menu)
3. Navigate to **Secrets and variables** → **Actions** (left sidebar)

### 3.2 Add Secret

1. Click **New repository secret**
2. Fill in:
   - **Name**: `AWS_ROLE_ARN`
   - **Value**: Paste the ARN from Step 2.5
3. Click **Add secret**

✅ Your GitHub repository can now authenticate with AWS!

---

## Step 4: Test the Setup

### 4.1 Commit and Push Files

```bash
cd ..  # Return to repository root

# Add all files
git add .

# Commit
git commit -m "Add VXLAN AMI builder with GitHub Actions"

# Push to main branch
git push origin main
```

### 4.2 Monitor the Workflow

1. Go to your GitHub repository
2. Click **Actions** tab
3. You should see "Build and Publish Graviton VXLAN AMI" workflow running

### 4.3 View Progress

Click on the workflow run to see:
- ✅ Validation step
- 🔄 AMI builds in 3 regions (parallel)
- 📝 Job summaries with AMI IDs

**Expected duration:** ~15 minutes per region (parallel)

### 4.4 Check Results

After completion, each region job will show:

```
### AMI Build Complete 🚀

**Region:** us-east-1
**AMI ID:** ami-0123456789abcdef0
**Version:** dev-20251029-a1b2c3d
**Public:** false
```

✅ Your first AMI is built! (Note: it's private since this was a dev build)

---

## Step 5: Publish a Release

### 5.1 Create a Release Tag

```bash
# Create an annotated tag
git tag -a v1.0.0 -m "Release v1.0.0 - Initial public release"

# Push the tag
git push origin v1.0.0
```

### 5.2 Monitor Release Build

1. Go to **Actions** tab
2. Find the workflow triggered by the tag
3. This will:
   - ✅ Build AMIs in all regions
   - ✅ Make them public
   - ✅ Create a GitHub release

### 5.3 Check GitHub Release

1. Go to your repository
2. Click **Releases** (right sidebar)
3. You'll see release **v1.0.0** with:
   - AMI IDs for all regions
   - Launch instructions
   - Manifest JSON files

---

## Step 6: Launch Your First Instance

### 6.1 Get AMI ID

From the GitHub release or workflow summary, copy the AMI ID for your preferred region.

### 6.2 Launch Instance

```bash
# Replace with your values
AMI_ID="ami-0123456789abcdef0"
KEY_NAME="your-key-pair"
SUBNET_ID="subnet-xxxxx"
SECURITY_GROUP="sg-xxxxx"

aws ec2 run-instances \
  --region us-east-1 \
  --image-id $AMI_ID \
  --instance-type t4g.nano \
  --key-name $KEY_NAME \
  --subnet-id $SUBNET_ID \
  --security-group-ids $SECURITY_GROUP \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=vxlan-test}]'
```

### 6.3 Connect and Verify

```bash
# Get instance IP
INSTANCE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=vxlan-test" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

# SSH to instance
ssh ubuntu@$INSTANCE_IP

# Check VXLAN is running
sudo systemctl status vxlan.service
ip link show vxlan0
ip addr show br-vxlan
```

✅ Your VXLAN interface should be up and running!

---

## 🎉 Success!

You've successfully set up:
- ✅ AWS OIDC authentication for GitHub Actions
- ✅ Automated multi-region AMI builds
- ✅ Public AMI publishing on releases
- ✅ VXLAN-configured Graviton instances

---

## Next Steps

### Add More Regions

Edit `.github/workflows/build-ami.yml`:

```yaml
strategy:
  matrix:
    region: 
      - us-east-1
      - us-west-2
      - eu-west-1
      - ap-south-1      # Add more regions
      - eu-central-1
```

### Customize VXLAN Configuration

Edit `vxlan-setup.sh`:

```bash
VXLAN_ID="100"           # Your VXLAN ID
VXLAN_PORT="4789"        # Your port
BRIDGE_IP="10.200.0.1/24"  # Your network
```

Rebuild AMI:
```bash
git add vxlan-setup.sh
git commit -m "Update VXLAN configuration"
git tag v1.1.0
git push origin v1.1.0
```

### Set Up AMI Cleanup

The cleanup workflow runs monthly, but you can test it:

1. Go to **Actions** → **Cleanup Old AMIs**
2. Click **Run workflow**
3. Set:
   - **Dry run:** `true` (test first)
   - **Keep count:** `5`
4. Click **Run workflow**

After verifying the dry run output, run again with:
- **Dry run:** `false` (actually delete)

### Configure Security Groups

Don't forget to restrict VXLAN traffic:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol udp \
  --port 4789 \
  --cidr 10.0.0.0/8  # Replace with your trusted CIDR
```

---

## Troubleshooting

### Problem: Workflow fails with "could not retrieve caller identity"

**Solution:**
1. Verify `AWS_ROLE_ARN` secret exists
2. Check role trust policy in AWS Console
3. Ensure `github_org` and `github_repo` match exactly in `terraform.tfvars`

```bash
cd terraform/
terraform destroy  # If needed
terraform apply    # Reapply with correct values
```

### Problem: "UnauthorizedOperation" during AMI build

**Solution:** IAM role lacks permissions

```bash
cd terraform/
terraform apply  # Reapply to update permissions
```

### Problem: AMI not public after release

**Solution:** Verify:
1. Tag starts with `v` (e.g., `v1.0.0`)
2. Check workflow logs for "Make AMI public" step

```bash
# Manually make public if needed
aws ec2 modify-image-attribute \
  --image-id ami-xxxxx \
  --launch-permission "Add=[{Group=all}]"
```

### Problem: Can't find AMI in AWS Console

**Solution:** Check correct region

```bash
# List AMIs in a region
aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=vxlan-graviton-*" \
  --region us-east-1
```

---

## Cost Estimates

### Setup Costs
- **OIDC Provider:** Free
- **IAM Role/Policies:** Free
- **GitHub Actions:** Free tier (2,000 minutes/month)

### Per-Build Costs
- **EC2 (t4g.nano, 15 min):** ~$0.001
- **EBS during build:** ~$0.001
- **Negligible total per build**

### Storage Costs (Ongoing)
- **AMI storage:** ~$0.10/month per AMI
- **Snapshots:** ~$0.05/GB/month

**Example (3 regions, 5 releases):**
- 15 AMIs × $0.10 = **$1.50/month**

Use the cleanup workflow to keep costs low!

---

## Documentation

- **Main README**: [README.md](README.md)
- **GitHub Actions**: [.github/workflows/README.md](.github/workflows/README.md)
- **Terraform Setup**: [terraform/README.md](terraform/README.md)
- **Packer Variables**: [variables.pkrvars.hcl.example](variables.pkrvars.hcl.example)

---

## Support

**Having issues?**

1. Check workflow logs in Actions tab
2. Review AWS CloudTrail for API errors
3. Verify IAM permissions in AWS Console
4. Check documentation links above

**Common issues:**
- [GitHub Actions Troubleshooting](.github/workflows/README.md#troubleshooting)
- [Terraform Troubleshooting](terraform/README.md#troubleshooting)

---

## Contributing

Improvements welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

---

**Ready to automate your infrastructure? Get building! 🚀**
