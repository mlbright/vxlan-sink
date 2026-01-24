# GitHub Actions AMI Publishing Workflow

Automated workflow to build and publish Graviton VXLAN AMIs using GitHub Actions with AWS OIDC authentication.

## Features

✅ **OIDC Authentication** - No long-lived AWS credentials  
✅ **Multi-Region** - Build AMIs in US East, US West, and EU West simultaneously  
✅ **Automatic Publishing** - Make AMIs public on tagged releases  
✅ **Validation** - Packer validation on all PRs  
✅ **GitHub Releases** - Automatic release creation with AMI IDs  
✅ **Artifacts** - Packer manifests saved for 90 days  
✅ **Parallel Builds** - Regional builds run concurrently  

## Workflow Triggers

### Automatic Triggers

| Trigger | When | What Happens |
|---------|------|--------------|
| **Push to `main`** | Code merged to main | Builds dev AMIs (not public) |
| **Push tag `v*`** | Release tag created | Builds AMIs in all regions, makes them public, creates GitHub release |
| **Pull Request** | PR opened/updated | Validates Packer config only (no build) |

### Manual Trigger

You can also trigger builds manually:

1. Go to **Actions** → **Build and Publish Graviton VXLAN AMI**
2. Click **Run workflow**
3. Select branch
4. Optionally customize:
   - **Regions**: Comma-separated list (e.g., `us-east-1,ap-south-1`)
   - **Make Public**: Check to make AMI public

## Workflow Structure

```
.github/workflows/build-ami.yml
├── validate       - Validate Packer config (runs on PRs)
├── build-ami      - Build AMI in matrix of regions
│   ├── us-east-1
│   ├── us-west-2
│   └── eu-west-1
├── create-release - Create GitHub release (only on tags)
└── notify-failure - Send notification on failure
```

## Setup Prerequisites

Before the workflow can run, you must:

1. ✅ **Setup AWS OIDC** (see [terraform/README.md](../terraform/README.md))
2. ✅ **Add GitHub Secret**: `AWS_ROLE_ARN` with the IAM role ARN
3. ✅ **Commit files** to your repository

## Usage Examples

### Release a New AMI Version

```bash
# Create a release tag
git tag -a v1.0.0 -m "Release v1.0.0 - Initial public release"
git push origin v1.0.0
```

This will:
1. ✅ Build AMI in 3 regions
2. ✅ Make AMIs public
3. ✅ Create GitHub release with AMI IDs
4. ✅ Tag AMIs with version info

### Build Development AMI

```bash
# Just push to main
git push origin main
```

This will:
1. ✅ Build AMI in 3 regions
2. ❌ AMIs remain private (not public)
3. ❌ No GitHub release created

### Test Without Building

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
- VXLAN interface pre-configured (vxlan0)
- Systemd service for automatic startup
- UDP port 4789 configured for VXLAN traffic
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
Format: vxlan-graviton-{VERSION}

Examples:
- Tagged release: vxlan-graviton-v1.0.0
- Dev build:      vxlan-graviton-dev-20251029-a1b2c3d
```

Where:
- `VERSION` = Git tag (e.g., `v1.0.0`)
- `dev-YYYYMMDD-SHA` = Date + short commit SHA for non-tag builds

## AMI Tags

Each AMI is tagged with metadata:

```yaml
GitHubRepository: "your-org/your-repo"
GitHubRef:        "refs/tags/v1.0.0"
GitHubSHA:        "a1b2c3d4e5f..."
GitHubRunId:      "1234567890"
BuildDate:        "2025-10-29T15:30:00Z"
Version:          "v1.0.0"
```

Use these tags to track AMI provenance.

## Making AMIs Public

AMIs are made public automatically when:

1. ✅ **Tagged release** - Any tag starting with `v` (e.g., `v1.0.0`)
2. ✅ **Manual dispatch** - When "Make Public" is checked

AMIs remain **private** for:
- ❌ Pushes to main/branches (dev builds)
- ❌ Pull requests

### Security Note

⚠️ **Making AMIs public means anyone can launch instances from them.**

Ensure:
- No sensitive data in the AMI
- Properly configured security groups on launch
- User data or initialization handles security

## Monitoring Workflow

### View Running Workflows

1. Go to **Actions** tab
2. Click on the workflow run
3. View job progress in real-time

### Check AMI Build Progress

Each job outputs a summary:

```
### AMI Build Complete 🚀

**Region:** us-east-1
**AMI ID:** `ami-0123456789abcdef0`
**Version:** v1.0.0
**Public:** true

#### Launch Command
aws ec2 run-instances \
  --region us-east-1 \
  --image-id ami-0123456789abcdef0 \
  --instance-type t4g.nano \
  --key-name YOUR_KEY \
  --security-group-ids YOUR_SG
```

### Download Manifests

Packer manifests are saved as artifacts for 90 days:

1. Go to workflow run
2. Scroll to **Artifacts**
3. Download `ami-manifest-{region}`
4. Contains complete build metadata

## Troubleshooting

### Error: "could not retrieve caller identity"

**Cause**: AWS OIDC not set up correctly

**Fix**:
1. Verify `AWS_ROLE_ARN` secret exists
2. Check role trust policy allows your repo
3. See [terraform/README.md](../terraform/README.md)

### Error: "UnauthorizedOperation: You are not authorized"

**Cause**: IAM role lacks permissions

**Fix**:
```bash
cd terraform/
terraform apply  # Reapply to update permissions
```

### Error: "AMI already exists"

**Cause**: You're rebuilding with same tag/version

**Fix**:
- Delete old AMI, or
- Use a new version tag

### Build Succeeds but AMI Not Public

**Check**:
1. Was it a tagged release? (`v*`)
2. Or manual dispatch with "Make Public" checked?

**Verify**:
```bash
aws ec2 describe-images \
  --image-ids ami-XXXXX \
  --query 'Images[0].Public'
```

### Packer Validation Fails

**Common causes**:
- Syntax error in `graviton-vxlan-ami.pkr.hcl`
- Missing required plugins
- Invalid HCL2 formatting

**Fix**:
```bash
# Locally validate
packer init graviton-vxlan-ami.pkr.hcl
packer validate graviton-vxlan-ami.pkr.hcl
packer fmt graviton-vxlan-ami.pkr.hcl
```

### Workflow Doesn't Trigger

**Check**:
1. Workflow file is in `.github/workflows/`
2. File is named with `.yml` or `.yaml` extension
3. File is on the branch you're pushing to
4. No YAML syntax errors

**Validate locally**:
```bash
# Check YAML syntax
yamllint .github/workflows/build-ami.yml
```

## Cost Optimization

### Reduce Build Costs

1. **Fewer Regions**: Build in 1 region for testing
   ```yaml
   matrix:
     region: 
       - us-east-1  # Only this region
   ```

2. **Skip Builds on Draft PRs**: Add condition
   ```yaml
   if: github.event.pull_request.draft == false
   ```

3. **Manual Builds**: Don't auto-build on every push
   - Remove `push:` trigger
   - Use `workflow_dispatch` only

### Estimated Costs

Per build (t4g.nano for ~15 minutes):
- **Compute**: ~$0.001 (negligible)
- **EBS**: ~$0.10 per month per AMI
- **Snapshots**: ~$0.05 per GB per month

Example for 3 regions:
- **Initial build**: ~$0.003
- **Monthly storage**: ~$0.30 (3 AMIs × $0.10)

## Security Best Practices

1. ✅ **Use OIDC** - No long-lived credentials
2. ✅ **Least Privilege** - IAM role has minimal permissions
3. ✅ **Audit Logs** - CloudTrail logs all AMI operations
4. ✅ **Code Review** - Validate PR changes before merge
5. ✅ **Signed Commits** - Require signed commits (optional)
6. ✅ **Branch Protection** - Protect main branch

### Recommended GitHub Settings

```yaml
Branch Protection Rules (main):
✓ Require pull request reviews
✓ Require status checks (validate job)
✓ Require linear history
✓ Require signed commits (optional)
```

## Advanced Usage

### Build for Additional Architectures

Currently builds ARM64 (Graviton). To also build x86_64:

1. Add source in Packer config
2. Update workflow matrix:
   ```yaml
   matrix:
     region: [us-east-1, us-west-2]
     architecture: [arm64, x86_64]
   ```

### Integrate with Terraform

Use the included Terraform module to deploy VXLAN sink instances:

```hcl
module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  vpc_id             = "vpc-xxx"
  subnet_id          = "subnet-xxx"
  vxlan_source_cidrs = ["10.0.0.0/8"]
}
```

See [Terraform Module](#terraform-module) section below for detailed usage.

## Terraform Module

This repository includes a Terraform module for deploying VXLAN sink instances into existing AWS VPCs.

### Module Source

```hcl
source = "github.com/mlbright/vxlan-sink//terraform"
```

### Usage: Automatic AMI Lookup

The module can automatically find the latest VXLAN AMI by name prefix:

```hcl
module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  # AMI lookup by prefix (default: "vxlan-graviton")
  ami_name_prefix    = "vxlan-graviton"

  # Required: Network configuration
  vpc_id             = "vpc-0123456789abcdef0"
  subnet_id          = "subnet-0123456789abcdef0"

  # Required: VXLAN source CIDRs
  vxlan_source_cidrs = ["10.0.0.0/8"]

  # Optional: Enable SSH access (disabled by default)
  # ssh_source_cidrs = ["10.0.0.0/8"]
  # key_name         = "my-key-pair"

  tags = {
    Environment = "production"
  }
}
```

### Usage: Explicit AMI ID

If you know the specific AMI ID to use:

```hcl
module "vxlan_sink" {
  source = "github.com/mlbright/vxlan-sink//terraform"

  # Explicit AMI ID
  ami_id             = "ami-0123456789abcdef0"

  # Required: Network configuration
  vpc_id             = "vpc-0123456789abcdef0"
  subnet_id          = "subnet-0123456789abcdef0"

  # Required: VXLAN source CIDRs
  vxlan_source_cidrs = ["10.0.0.0/8"]
}
```

### Module Inputs

| Variable | Type | Default | Required | Description |
|----------|------|---------|----------|-------------|
| `ami_id` | string | `null` | No | Explicit AMI ID (if null, uses lookup) |
| `ami_name_prefix` | string | `"vxlan-graviton"` | No | AMI name prefix for automatic lookup |
| `instance_type` | string | `"t4g.nano"` | No | EC2 instance type (ARM64/Graviton) |
| `vpc_id` | string | - | **Yes** | VPC ID to deploy into |
| `subnet_id` | string | - | **Yes** | Subnet ID for the instance |
| `key_name` | string | `null` | No | SSH key pair name |
| `vxlan_source_cidrs` | list(string) | - | **Yes** | CIDRs allowed VXLAN traffic (UDP 4789) |
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
| `ami_id` | Resolved AMI ID |
| `vxlan_endpoint` | VXLAN endpoint (`private_ip:4789`) |

### Examples

See [terraform/examples/](terraform/examples/) for complete working examples:

- [explicit-ami](terraform/examples/explicit-ami/) - Deploy with a known AMI ID
- [ami-lookup](terraform/examples/ami-lookup/) - Deploy with automatic AMI discovery

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS OIDC with GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Packer Documentation](https://www.packer.io/docs)
- [AWS EC2 AMI Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)

## Support

If you encounter issues:

1. Check [Troubleshooting](#troubleshooting) section
2. Review workflow logs in Actions tab
3. Check CloudTrail for AWS API errors
4. Verify IAM permissions in AWS Console

## License

This workflow configuration is provided as-is for educational and operational use.
