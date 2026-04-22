.PHONY: help init validate build clean clean-builders install-vxlan azure-setup azure-init azure-validate azure-build

# Default target
help:
	@echo "VXLAN sink AMI Builder"
	@echo "============================="
	@echo ""
	@echo "AWS Packer Commands:"
	@echo "  make init       - Initialize Packer plugins"
	@echo "  make validate   - Validate Packer configuration"
	@echo "  make build      - Build the AMI (uses t4g.nano by default)"
	@echo "  make build-nano - Build with t4g.nano instance"
	@echo "  make build-micro - Build with t4g.micro instance"
	@echo "  make build-small - Build with t4g.small instance"
	@echo "  make fmt        - Format Packer HCL files"
	@echo ""
	@echo "Azure Packer Commands:"
	@echo "  make azure-setup    - Create Azure resource group, gallery, and image definition"
	@echo "  make azure-init     - Initialize Azure Packer plugins"
	@echo "  make azure-validate - Validate Azure Packer configuration"
	@echo "  make azure-build    - Build the Azure image (setup + init + validate + build)"
	@echo ""
	@echo "VXLAN Commands:"
	@echo "  make install-vxlan - Install VXLAN systemd service (requires sudo)"
	@echo "  make test-vxlan    - Test VXLAN setup without systemd"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make clean          - Remove build artifacts"
	@echo "  make clean-builders - Terminate orphan Packer EC2 instances + delete temp keypairs/SGs"
	@echo "  make setup          - Set executable permissions on scripts"

# Initialize Packer
init:
	@echo "Initializing Packer..."
	packer init ami/graviton-vxlan-ami.pkr.hcl

# Validate Packer configuration
validate: init
	@echo "Validating Packer configuration..."
	packer validate ami/graviton-vxlan-ami.pkr.hcl

# Format Packer files
fmt:
	@echo "Formatting Packer HCL files..."
	packer fmt ami/graviton-vxlan-ami.pkr.hcl
	packer fmt ami/variables.pkrvars.hcl.example

# Build AMI with default settings (t4g.nano)
build: validate
	@echo "Building AMI with t4g.nano (cheapest Graviton instance)..."
	packer build ami/graviton-vxlan-ami.pkr.hcl

# Build with t4g.micro
build-nano: validate
	@echo "Building AMI with t4g.nano..."
	packer build -var="instance_type=t4g.nano" ami/graviton-vxlan-ami.pkr.hcl

# Build with t4g.micro
build-micro: validate
	@echo "Building AMI with t4g.micro..."
	packer build -var="instance_type=t4g.micro" ami/graviton-vxlan-ami.pkr.hcl

# Build with t4g.small
build-small: validate
	@echo "Building AMI with t4g.small..."
	packer build -var="instance_type=t4g.small" ami/graviton-vxlan-ami.pkr.hcl

# Build with custom region
build-region: validate
	@echo "Building AMI in $(REGION)..."
	@test -n "$(REGION)" || (echo "ERROR: REGION not set. Usage: make build-region REGION=us-west-2"; exit 1)
	packer build -var="aws_region=$(REGION)" ami/graviton-vxlan-ami.pkr.hcl

# Setup file permissions
setup:
	@echo "Setting executable permissions on scripts..."
	chmod +x ami/vxlan-setup.sh
	chmod +x ami/vxlan-teardown.sh
	chmod +x ami/install-vxlan-service.sh

# Install VXLAN systemd service
install-vxlan: setup
	@echo "Installing VXLAN systemd service..."
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "ERROR: This target must be run with sudo"; \
		echo "Usage: sudo make install-vxlan"; \
		exit 1; \
	fi
	./ami/install-vxlan-service.sh

# Test VXLAN without systemd
test-vxlan: setup
	@echo "Testing VXLAN setup (requires sudo)..."
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "ERROR: This target must be run with sudo"; \
		echo "Usage: sudo make test-vxlan"; \
		exit 1; \
	fi
	./ami/vxlan-setup.sh
	@echo ""
	@echo "VXLAN interface is up. Press Enter to tear down..."
	@read dummy
	./ami/vxlan-teardown.sh

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f manifest.json
	rm -f packer-manifest.json
	rm -f crash.log
	rm -rf packer_cache/

# Clean up any leftover Packer builder resources in AWS (instances, keypairs, SGs).
# Useful when a build was interrupted (Ctrl+C, killed terminal) and Packer's
# automatic cleanup did not run. Filters on the run_tags applied by the Packer
# build (Purpose=AMI Build) and the packer_* naming convention for keypairs/SGs.
AWS_REGION ?= us-east-1
clean-builders:
	@echo "Cleaning up orphan Packer resources in $(AWS_REGION)..."
	@INSTANCES=$$(aws ec2 describe-instances --region $(AWS_REGION) \
	  --filters 'Name=tag:Purpose,Values=AMI Build' \
	            'Name=instance-state-name,Values=pending,running,stopping,stopped' \
	  --query 'Reservations[].Instances[].InstanceId' --output text); \
	if [ -n "$$INSTANCES" ]; then \
	  echo "Terminating instances: $$INSTANCES"; \
	  aws ec2 terminate-instances --region $(AWS_REGION) --instance-ids $$INSTANCES >/dev/null; \
	  echo "Waiting for instances to terminate..."; \
	  aws ec2 wait instance-terminated --region $(AWS_REGION) --instance-ids $$INSTANCES; \
	else \
	  echo "No orphan builder instances found."; \
	fi
	@SGS=$$(aws ec2 describe-security-groups --region $(AWS_REGION) \
	  --filters 'Name=group-name,Values=packer_*' \
	  --query 'SecurityGroups[].GroupId' --output text); \
	for sg in $$SGS; do \
	  echo "Deleting security group $$sg"; \
	  aws ec2 delete-security-group --region $(AWS_REGION) --group-id $$sg || true; \
	done
	@KPS=$$(aws ec2 describe-key-pairs --region $(AWS_REGION) \
	  --filters 'Name=key-name,Values=packer_*' \
	  --query 'KeyPairs[].KeyName' --output text); \
	for kp in $$KPS; do \
	  echo "Deleting key pair $$kp"; \
	  aws ec2 delete-key-pair --region $(AWS_REGION) --key-name $$kp || true; \
	done
	@echo "Cleanup complete."

# Check AWS credentials
check-aws:
	@echo "Checking AWS credentials..."
	@aws sts get-caller-identity || (echo "ERROR: AWS credentials not configured"; exit 1)
	@echo "AWS credentials OK"

# Show AMI info from manifest
show-ami:
	@if [ -f manifest.json ]; then \
		echo "Latest built AMI:"; \
		jq -r '.builds[-1] | "AMI ID: \(.artifact_id)\nRegion: \(.custom_data.region)\nInstance Type: \(.custom_data.instance_type)\nName: \(.custom_data.ami_name)"' manifest.json; \
	else \
		echo "No manifest.json found. Build an AMI first with 'make build'"; \
	fi

# =============================================================================
# Azure Targets
# =============================================================================

AZURE_RESOURCE_GROUP ?= vxlan-sink-images
AZURE_LOCATION ?= eastus2
AZURE_GALLERY ?= dev_builds
AZURE_IMAGE_DEF ?= vxlan-sink

# Create Azure resource group, compute gallery, and image definition
azure-setup:
	@echo "Creating Azure resources for image build..."
	az group create \
		--name $(AZURE_RESOURCE_GROUP) \
		--location $(AZURE_LOCATION) \
		--output table
	@echo "Creating compute gallery '$(AZURE_GALLERY)'..."
	az sig create \
		--resource-group $(AZURE_RESOURCE_GROUP) \
		--gallery-name $(AZURE_GALLERY) \
		--location $(AZURE_LOCATION) \
		--output table 2>/dev/null || echo "Gallery '$(AZURE_GALLERY)' already exists"
	@echo "Creating image definition '$(AZURE_IMAGE_DEF)'..."
	az sig image-definition create \
		--resource-group $(AZURE_RESOURCE_GROUP) \
		--gallery-name $(AZURE_GALLERY) \
		--gallery-image-definition $(AZURE_IMAGE_DEF) \
		--publisher cpacket \
		--offer vxlan-sink \
		--sku ubuntu-2404-lts \
		--os-type Linux \
		--os-state Generalized \
		--hyper-v-generation V2 \
		--output table 2>/dev/null || echo "Image definition '$(AZURE_IMAGE_DEF)' already exists"

# Initialize Azure Packer plugins
azure-init:
	@echo "Initializing Azure Packer plugins..."
	packer init azure-vxlan-image.pkr.hcl

# Validate Azure Packer configuration
azure-validate: azure-init
	@echo "Validating Azure Packer configuration..."
	packer validate azure-vxlan-image.pkr.hcl

# Build Azure image (full pipeline: setup + validate + build)
azure-build: azure-setup azure-validate
	@echo "Building Azure image..."
	packer build azure-vxlan-image.pkr.hcl
