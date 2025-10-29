# Architecture Overview

This document provides visual diagrams and explanations of the automated AMI building and publishing system.

## System Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                        │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Packer Files │  │ VXLAN Scripts│  │  Workflows   │          │
│  │   (.hcl)     │  │    (.sh)     │  │   (.yml)     │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              │ 1. Git Push / Tag
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                       GitHub Actions                              │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Workflow Execution                       │ │
│  │                                                             │ │
│  │  validate → build-ami (multi-region) → create-release     │ │
│  │                                                             │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              │ 2. Request JWT Token
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub OIDC Provider                          │
│                 (token.actions.githubusercontent.com)            │
│                                                                   │
│  Issues JWT token with claims:                                   │
│  - Repository: your-org/your-repo                                │
│  - Ref: refs/tags/v1.0.0                                         │
│  - SHA: abc123...                                                │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              │ 3. AssumeRoleWithWebIdentity
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                           AWS STS                                │
│                                                                   │
│  Validates JWT token and returns temporary credentials           │
│  - Access Key ID                                                 │
│  - Secret Access Key                                             │
│  - Session Token (expires in 1 hour)                             │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              │ 4. Use Credentials
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                        IAM Role                                  │
│              GitHubActions-PackerAMIBuilder                      │
│                                                                   │
│  Permissions:                                                     │
│  - EC2: Launch instances, create AMIs                            │
│  - EC2: Modify image attributes (make public)                    │
│  - EC2: Create/delete snapshots                                  │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              │ 5. Execute Packer
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                        AWS EC2                                   │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  us-east-1   │  │  us-west-2   │  │  eu-west-1   │          │
│  │              │  │              │  │              │          │
│  │ 1. Launch    │  │ 1. Launch    │  │ 1. Launch    │          │
│  │    t4g.nano  │  │    t4g.nano  │  │    t4g.nano  │          │
│  │              │  │              │  │              │          │
│  │ 2. Provision │  │ 2. Provision │  │ 2. Provision │          │
│  │    VXLAN     │  │    VXLAN     │  │    VXLAN     │          │
│  │              │  │              │  │              │          │
│  │ 3. Create    │  │ 3. Create    │  │ 3. Create    │          │
│  │    AMI       │  │    AMI       │  │    AMI       │          │
│  │              │  │              │  │              │          │
│  │ 4. Make      │  │ 4. Make      │  │ 4. Make      │          │
│  │    Public    │  │    Public    │  │    Public    │          │
│  │              │  │              │  │              │          │
│  │ 5. Terminate │  │ 5. Terminate │  │ 5. Terminate │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              │ 6. Return AMI IDs
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub Release                              │
│                                                                   │
│  Release: v1.0.0                                                 │
│                                                                   │
│  AMI IDs:                                                         │
│  - us-east-1: ami-0abc123...                                     │
│  - us-west-2: ami-0def456...                                     │
│  - eu-west-1: ami-0ghi789...                                     │
│                                                                   │
│  Attachments:                                                     │
│  - manifest-us-east-1.json                                       │
│  - manifest-us-west-2.json                                       │
│  - manifest-eu-west-1.json                                       │
└─────────────────────────────────────────────────────────────────┘
```

## Workflow Trigger Flowchart

```text
                    ┌─────────────┐
                    │ Git Action  │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
        ┌─────▼─────┐ ┌───▼────┐ ┌────▼─────┐
        │   Push    │ │  Tag   │ │    PR    │
        │ to main   │ │  v*    │ │          │
        └─────┬─────┘ └───┬────┘ └────┬─────┘
              │           │            │
              │           │            │
        ┌─────▼─────┐ ┌───▼────┐ ┌────▼─────┐
        │ Validate  │ │Validate│ │ Validate │
        │           │ │        │ │   ONLY   │
        └─────┬─────┘ └───┬────┘ └──────────┘
              │           │
        ┌─────▼─────┐ ┌───▼────┐
        │Build AMIs │ │Build   │
        │(private)  │ │AMIs    │
        └───────────┘ │(public)│
                      └───┬────┘
                          │
                    ┌─────▼─────┐
                    │  Create   │
                    │  Release  │
                    └───────────┘
```

## OIDC Authentication Flow

```text
┌─────────────┐
│  Workflow   │
│   Starts    │
└──────┬──────┘
       │
       │ 1. Request OIDC token
       ↓
┌──────────────────┐
│ GitHub generates │
│    JWT token     │
│                  │
│  Contains:       │
│  - repo name     │
│  - ref/branch    │
│  - commit SHA    │
│  - workflow      │
└──────┬───────────┘
       │
       │ 2. Send token to AWS STS
       ↓
┌──────────────────┐
│   AWS verifies   │
│   JWT signature  │
│                  │
│   Checks:        │
│   - Valid issuer │
│   - Not expired  │
│   - Audience     │
└──────┬───────────┘
       │
       │ 3. Match against IAM Role trust policy
       ↓
┌──────────────────┐
│  Trust Policy    │
│   validates:     │
│                  │
│  - Correct repo? │
│  - Allowed ref?  │
└──────┬───────────┘
       │
       │ 4. If valid, issue credentials
       ↓
┌──────────────────┐
│  Temporary AWS   │
│   Credentials    │
│                  │
│  Valid for:      │
│  1 hour          │
└──────┬───────────┘
       │
       │ 5. Use for Packer operations
       ↓
┌──────────────────┐
│   Build AMI      │
└──────────────────┘
```

## AMI Build Process (Per Region)

```text
START
  │
  ├──> 1. Launch EC2 instance (t4g.nano)
  │      - Ubuntu 22.04 ARM64 base AMI
  │      - Temporary security group
  │
  ├──> 2. Wait for instance ready
  │      - SSH connectivity
  │      - Cloud-init complete
  │
  ├──> 3. Provision instance
  │      ├──> Update packages
  │      ├──> Install dependencies
  │      │      - bridge-utils
  │      │      - iproute2
  │      │      - nftables
  │      ├──> Copy VXLAN scripts
  │      ├──> Install systemd service
  │      └──> Configure sysctl
  │
  ├──> 4. Create AMI
  │      ├──> Stop instance
  │      ├──> Create image
  │      └──> Create snapshot
  │
  ├──> 5. Tag AMI
  │      - GitHubRepository
  │      - GitHubRef
  │      - GitHubSHA
  │      - Version
  │      - BuildDate
  │
  ├──> 6. Make AMI public (if release)
  │      - Modify image attributes
  │      - Add launch permissions
  │
  ├──> 7. Cleanup
  │      ├──> Terminate instance
  │      └──> Delete security group
  │
END (Return AMI ID)
```

## Multi-Region Build Timeline

```text
Time: 0min                                                15min
      │                                                    │
      ├────────────────────────────────────────────────────┤
      │                                                    │
US-1  ├══════════════════════════════════════════════════►│ ami-0abc...
      │                                                    │
US-2  ├══════════════════════════════════════════════════►│ ami-0def...
      │                                                    │
EU-1  ├══════════════════════════════════════════════════►│ ami-0ghi...
      │                                                    │
      └────────────────────────────────────────────────────┘
                      Parallel Execution
```

## Security Boundaries

```text
┌─────────────────────────────────────────────────────────────┐
│                    Trust Boundary                            │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                 GitHub Actions                        │  │
│  │                                                       │  │
│  │  No AWS credentials stored                           │  │
│  │  Only repo-specific OIDC tokens                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                 │
│                           │ Ephemeral JWT                   │
│                           ↓                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                     AWS STS                           │  │
│  │                                                       │  │
│  │  Validates token signature                           │  │
│  │  Issues temporary credentials (1 hour TTL)           │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                 │
│                           │ Temporary credentials           │
│                           ↓                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │               IAM Role (Least Privilege)             │  │
│  │                                                       │  │
│  │  Permissions:                                         │  │
│  │  ✓ Launch EC2 instances                              │  │
│  │  ✓ Create AMIs/snapshots                             │  │
│  │  ✓ Make AMIs public                                  │  │
│  │  ✗ Access other AWS resources                        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Security Features:
1. No long-lived credentials
2. Repository-scoped access
3. Time-limited sessions
4. Auditable via CloudTrail
5. Principle of least privilege
```

## Data Flow

```text
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│              │     │              │     │              │
│   Scripts    │────▶│   Packer     │────▶│   AWS EC2    │
│  (Git repo)  │     │  (builds)    │     │  (creates)   │
│              │     │              │     │              │
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │
                                                  │
                                          ┌───────▼────────┐
                                          │                │
                                          │   AMI Image    │
                                          │   + Snapshots  │
                                          │                │
                                          └───────┬────────┘
                                                  │
                                          ┌───────▼────────┐
                                          │                │
                                          │ GitHub Release │
                                          │  (AMI IDs +    │
                                          │   manifests)   │
                                          │                │
                                          └────────────────┘
```

## Cost Breakdown

```text
┌─────────────────────────────────────────────────────────────┐
│                    Cost Components                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Infrastructure Setup (One-time)                            │
│  ├─ OIDC Provider ...................... FREE              │
│  ├─ IAM Roles/Policies ................. FREE              │
│  └─ GitHub Actions (setup) ............. FREE              │
│                                                              │
│  Per AMI Build                                              │
│  ├─ EC2 t4g.nano (15 min) .............. $0.001           │
│  ├─ EBS during build ................... $0.001           │
│  └─ Network transfer ................... Negligible        │
│      TOTAL PER BUILD: ~$0.002                              │
│                                                              │
│  Ongoing Storage (Monthly)                                  │
│  ├─ AMI (8GB) .......................... $0.10/AMI        │
│  └─ Snapshot ........................... $0.05/GB          │
│      EXAMPLE (3 regions × 5 AMIs):                         │
│      15 AMIs × $0.10 = $1.50/month                         │
│                                                              │
│  GitHub Actions                                             │
│  ├─ Free tier .......................... 2,000 min/month   │
│  └─ Each build ......................... ~15 minutes        │
│      (Can build ~130 AMIs/month for free)                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Cost Optimization Tips:
1. Use AMI cleanup workflow (keep only recent 5)
2. Build in fewer regions during development
3. Use manual workflow dispatch instead of auto-builds
```

## Component Responsibilities

| Component | Responsibility | Configuration Location |
|-----------|---------------|----------------------|
| **GitHub Actions Workflow** | Orchestrate build process | `.github/workflows/build-ami.yml` |
| **OIDC Provider** | Federated authentication | `terraform/github-oidc.tf` |
| **IAM Role** | AWS permissions | `terraform/github-oidc.tf` |
| **Packer** | Build AMI | `graviton-vxlan-ami.pkr.hcl` |
| **VXLAN Scripts** | Configure networking | `vxlan-setup.sh`, `vxlan-teardown.sh` |
| **Systemd Service** | Auto-start VXLAN | `vxlan.service` |
| **Cleanup Workflow** | Cost optimization | `.github/workflows/cleanup-amis.yml` |

## Lifecycle States

```text
AMI Lifecycle:

Development Build (push to main)
├─ State: Private
├─ Name: vxlan-graviton-dev-YYYYMMDD-{SHA}
├─ Tags: BuildDate, GitHubSHA
└─ Retention: Manual (or cleanup workflow)

Release Build (tag v*)
├─ State: Public
├─ Name: vxlan-graviton-{VERSION}
├─ Tags: Version, BuildDate, GitHubRef
├─ GitHub Release: Created
└─ Retention: Permanent (typically)

Cleanup (monthly or manual)
├─ Keep: Most recent N AMIs (default: 5)
├─ Delete: Older AMIs
└─ Also deletes: Associated snapshots
```

## References

- [Main README](README.md)
- [Quick Start Guide](QUICKSTART.md)
- [GitHub Actions Details](.github/workflows/README.md)
- [Terraform Setup](terraform/README.md)
