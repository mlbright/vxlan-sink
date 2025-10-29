# Project Summary: VXLAN AMI Builder with GitHub Actions

Complete automated solution for building and publishing AWS Graviton AMIs with VXLAN configuration using GitHub Actions and OIDC authentication.

## 📦 What's Included

This project provides everything you need to automatically build, test, and publish AWS AMIs with pre-configured VXLAN networking.

### Core Features

- ✅ **VXLAN Configuration** - Pre-configured overlay networking (port 4789)
- ✅ **Graviton Optimized** - ARM64 architecture (t4g.nano - cheapest option)
- ✅ **Systemd Integration** - Auto-start on boot
- ✅ **CI/CD Automation** - GitHub Actions workflows
- ✅ **OIDC Authentication** - No long-lived AWS credentials
- ✅ **Multi-Region** - Parallel builds across AWS regions
- ✅ **Public Publishing** - Automatic AMI publishing on releases
- ✅ **Cost Optimization** - Automated cleanup of old AMIs
- ✅ **Complete Documentation** - Step-by-step guides

---

## 📁 File Structure

```
vxlan-ami-builder/
├── .github/
│   └── workflows/
│       ├── build-ami.yml          # Main build & publish workflow
│       ├── cleanup-amis.yml       # Cost optimization workflow
│       └── README.md              # Workflow documentation
│
├── terraform/
│   ├── github-oidc.tf            # AWS OIDC provider & IAM role
│   ├── terraform.tfvars.example  # Configuration template
│   └── README.md                 # Terraform setup guide
│
├── vxlan-setup.sh                # VXLAN interface configuration
├── vxlan-teardown.sh             # VXLAN cleanup script
├── vxlan.service                 # Systemd service unit
├── install-vxlan-service.sh      # Service installation helper
│
├── graviton-vxlan-ami.pkr.hcl    # Packer HCL2 configuration
├── variables.pkrvars.hcl.example # Packer variables template
│
├── Makefile                      # Convenience targets
├── .gitignore                    # Git exclusions
│
├── README.md                     # Main documentation
├── QUICKSTART.md                 # 15-minute setup guide
└── ARCHITECTURE.md               # System diagrams & architecture
```

---

## 🚀 Quick Start (5 Minutes)

### Prerequisites
- AWS account with admin access
- GitHub repository
- Terraform installed

### Setup Steps

1. **Clone repository**
   ```bash
   git clone https://github.com/YOUR-ORG/vxlan-ami-builder.git
   cd vxlan-ami-builder
   ```

2. **Configure AWS OIDC**
   ```bash
   cd terraform/
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your GitHub org/repo
   terraform init
   terraform apply
   ```

3. **Add GitHub secret**
   - Copy IAM role ARN from Terraform output
   - Add as `AWS_ROLE_ARN` secret in GitHub repository settings

4. **Trigger build**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

Done! Check the Actions tab for build progress.

**Full guide:** [QUICKSTART.md](QUICKSTART.md)

---

## 📚 Documentation Index

| Document | Purpose | Audience |
|----------|---------|----------|
| **[README.md](README.md)** | Complete project overview and reference | All users |
| **[QUICKSTART.md](QUICKSTART.md)** | Step-by-step setup guide (15 min) | New users |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | System diagrams and architecture | Technical users |
| **[terraform/README.md](terraform/README.md)** | AWS OIDC setup instructions | DevOps engineers |
| **[.github/workflows/README.md](.github/workflows/README.md)** | GitHub Actions usage guide | Developers |

---

## 🔧 Key Components

### 1. VXLAN Scripts

**Purpose:** Configure overlay networking on Linux

| File | Description |
|------|-------------|
| `vxlan-setup.sh` | Creates VXLAN interface and firewall rules |
| `vxlan-teardown.sh` | Removes VXLAN configuration |
| `vxlan.service` | Systemd unit for automatic startup |
| `install-vxlan-service.sh` | Installation helper |

**Configuration:**
- VXLAN ID: 1337 (customizable)
- Port: 4789 (UDP)
- Auto-detects first physical interface (eth0, ens5, etc.)
- Default network: 10.200.0.1/24

### 2. Packer Configuration

**Purpose:** Build AMI images

| File | Description |
|------|-------------|
| `graviton-vxlan-ami.pkr.hcl` | Main Packer configuration |
| `variables.pkrvars.hcl.example` | Variable template |

**Build specification:**
- Base: Ubuntu 24.04 LTS ARM64
- Instance: t4g.nano (cheapest Graviton)
- Provisioning: ~15 minutes
- Output: AMI + snapshots

### 3. GitHub Actions Workflows

**Purpose:** Automate AMI building and publishing

| Workflow | Triggers | Actions |
|----------|----------|---------|
| `build-ami.yml` | Push to main, tags, manual | Build AMIs in multiple regions |
| `cleanup-amis.yml` | Monthly schedule, manual | Delete old AMIs to reduce costs |

**Features:**
- OIDC authentication (no credentials)
- Multi-region parallel builds
- Automatic public publishing on release tags
- GitHub releases with AMI IDs
- Job summaries with launch commands

### 4. Terraform Configuration

**Purpose:** Set up AWS OIDC provider and IAM roles

| File | Description |
|------|-------------|
| `github-oidc.tf` | OIDC provider + IAM role + policies |
| `terraform.tfvars.example` | Configuration template |

**Creates:**
- GitHub OIDC provider (if needed)
- IAM role: `GitHubActions-PackerAMIBuilder`
- Least-privilege IAM policies
- Trust relationship to your repository

---

## 🎯 Use Cases

### 1. Development Environment
```bash
# Push to main = Build private AMIs for testing
git push origin main
```

### 2. Production Release
```bash
# Tag = Build public AMIs + GitHub release
git tag v1.0.0
git push origin v1.0.0
```

### 3. Custom Build
```bash
# Manual workflow dispatch with custom regions
# Go to Actions → Build AMI → Run workflow
```

### 4. Cost Management
```bash
# Cleanup old AMIs (scheduled monthly)
# Or run manually via Actions → Cleanup AMIs
```

---

## 💰 Cost Breakdown

### One-Time Setup
- OIDC Provider: **FREE**
- IAM Roles/Policies: **FREE**
- GitHub Actions setup: **FREE**

### Per Build
- EC2 t4g.nano (15 min): **~$0.001**
- EBS during build: **~$0.001**
- **Total per build: ~$0.002**

### Monthly Storage
- AMI (8GB): **$0.10/AMI**
- Snapshot: **$0.05/GB**

**Example (3 regions, 5 versions):**
- 15 AMIs × $0.10 = **$1.50/month**

**Cost optimization:**
- Use cleanup workflow (keep latest 5)
- Build fewer regions for development
- Use manual dispatch instead of auto-builds

---

## 🔒 Security Features

### OIDC Authentication
- ✅ No long-lived AWS credentials
- ✅ No secrets to rotate
- ✅ Automatic credential expiration (1 hour)
- ✅ Repository-scoped access

### IAM Permissions
- ✅ Least privilege principle
- ✅ Scoped to EC2/AMI operations only
- ✅ Cannot access other AWS resources

### Systemd Security
- ✅ Capability restrictions (NET_ADMIN, NET_RAW only)
- ✅ Private temp directories
- ✅ Protected system paths
- ✅ No new privileges

### Network Security
- ⚠️ VXLAN accepts from any source by default
- ✅ Configure AWS Security Groups to restrict access
- ✅ Consider IPsec/WireGuard for encryption

---

## 📊 Workflow Execution Flow

```
1. Git push/tag
   ↓
2. GitHub Actions triggered
   ↓
3. Request OIDC token from GitHub
   ↓
4. Exchange token for AWS credentials (STS)
   ↓
5. Run Packer in parallel across regions
   ├─ us-east-1: Launch → Provision → AMI → Terminate
   ├─ us-west-2: Launch → Provision → AMI → Terminate
   └─ eu-west-1: Launch → Provision → AMI → Terminate
   ↓
6. Tag AMIs with metadata
   ↓
7. Make AMIs public (if release tag)
   ↓
8. Create GitHub release with AMI IDs
```

---

## 🛠️ Customization

### Change VXLAN Configuration

Edit `vxlan-setup.sh`:
```bash
VXLAN_ID="200"              # Change VXLAN ID
VXLAN_PORT="4789"           # Change port
VXLAN_IP="192.168.0.1/24"   # Change VXLAN network
```

### Add More Regions

Edit `.github/workflows/build-ami.yml`:
```yaml
matrix:
  region: 
    - us-east-1
    - us-west-2
    - eu-west-1
    - ap-south-1      # Add Mumbai
    - eu-central-1    # Add Frankfurt
```

### Change Instance Type

Edit `graviton-vxlan-ami.pkr.hcl`:
```hcl
variable "instance_type" {
  default = "t4g.micro"  # Or t4g.small, t4g.medium
}
```

---

## 🧪 Testing

### Local Packer Validation
```bash
packer init graviton-vxlan-ami.pkr.hcl
packer validate graviton-vxlan-ami.pkr.hcl
packer fmt -check graviton-vxlan-ami.pkr.hcl
```

### Local VXLAN Testing
```bash
chmod +x vxlan-setup.sh vxlan-teardown.sh
sudo ./vxlan-setup.sh
# Verify
ip link show vxlan0
ip addr show vxlan0
# Cleanup
sudo ./vxlan-teardown.sh
```

### Dry Run AMI Cleanup
```bash
# GitHub Actions → Cleanup AMIs → Run workflow
# Set: dry_run = true
```

---

## 🐛 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Could not retrieve caller identity" | Verify `AWS_ROLE_ARN` secret, check Terraform trust policy |
| "UnauthorizedOperation" | Re-run `terraform apply` to update IAM permissions |
| AMI not public after release | Verify tag starts with `v`, check workflow logs |
| Workflow doesn't trigger | Ensure `.github/workflows/` path, check YAML syntax |
| Build cost too high | Build fewer regions, use cleanup workflow |

**Full troubleshooting guides:**
- [GitHub Actions Troubleshooting](.github/workflows/README.md#troubleshooting)
- [Terraform Troubleshooting](terraform/README.md#troubleshooting)

---

## 📈 Monitoring

### View Build Status
1. GitHub → Actions tab
2. Click workflow run
3. Monitor parallel region builds
4. Check job summaries for AMI IDs

### AWS Console Verification
```bash
# List your AMIs
aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=vxlan-graviton-*"

# Check if AMI is public
aws ec2 describe-images \
  --image-ids ami-xxxxx \
  --query 'Images[0].Public'
```

### Cost Monitoring
```bash
# AWS Cost Explorer → Filter by:
# - Service: EC2
# - Tag: GitHubRepository = your-repo
```

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open pull request

---

## 📝 License

This project is provided as-is for educational and operational use.

---

## 🔗 External Resources

- [VXLAN RFC 7348](https://tools.ietf.org/html/rfc7348)
- [Packer Documentation](https://www.packer.io/docs)
- [AWS Graviton](https://aws.amazon.com/ec2/graviton/)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [systemd Documentation](https://www.freedesktop.org/software/systemd/man/)

---

## ✨ What Makes This Special?

1. **Zero Credentials**: Uses OIDC - no AWS keys to manage
2. **Production Ready**: Includes systemd, security hardening, monitoring
3. **Cost Optimized**: Cheapest instance type + automated cleanup
4. **Multi-Region**: Parallel builds across AWS regions
5. **Fully Documented**: Step-by-step guides, diagrams, troubleshooting
6. **One Command Deploy**: `git tag v1.0.0 && git push --tags`

---

## 🎉 Getting Started

**Brand new?** → Start with [QUICKSTART.md](QUICKSTART.md) (15 minutes)

**Need details?** → Read [README.md](README.md) (comprehensive guide)

**Architecture deep dive?** → Check [ARCHITECTURE.md](ARCHITECTURE.md) (diagrams)

**Setting up AWS?** → Follow [terraform/README.md](terraform/README.md)

**Using workflows?** → See [.github/workflows/README.md](.github/workflows/README.md)

---

**Ready to build? Let's go! 🚀**

```bash
git clone https://github.com/YOUR-ORG/vxlan-ami-builder.git
cd vxlan-ami-builder
# Follow QUICKSTART.md
```
