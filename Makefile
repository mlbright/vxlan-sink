.PHONY: help init validate build clean install-vxlan

# Default target
help:
	@echo "VXLAN + Graviton AMI Builder"
	@echo "============================="
	@echo ""
	@echo "Packer Commands:"
	@echo "  make init       - Initialize Packer plugins"
	@echo "  make validate   - Validate Packer configuration"
	@echo "  make build      - Build the AMI (uses t4g.nano by default)"
	@echo "  make build-micro - Build with t4g.micro instance"
	@echo "  make build-small - Build with t4g.small instance"
	@echo "  make fmt        - Format Packer HCL files"
	@echo ""
	@echo "VXLAN Commands:"
	@echo "  make install-vxlan - Install VXLAN systemd service (requires sudo)"
	@echo "  make test-vxlan    - Test VXLAN setup without systemd"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make clean      - Remove build artifacts"
	@echo "  make setup      - Set executable permissions on scripts"

# Initialize Packer
init:
	@echo "Initializing Packer..."
	packer init graviton-vxlan-ami.pkr.hcl

# Validate Packer configuration
validate: init
	@echo "Validating Packer configuration..."
	packer validate graviton-vxlan-ami.pkr.hcl

# Format Packer files
fmt:
	@echo "Formatting Packer HCL files..."
	packer fmt graviton-vxlan-ami.pkr.hcl
	packer fmt variables.pkrvars.hcl.example

# Build AMI with default settings (t4g.nano)
build: validate
	@echo "Building AMI with t4g.nano (cheapest Graviton instance)..."
	packer build graviton-vxlan-ami.pkr.hcl

# Build with t4g.micro
build-micro: validate
	@echo "Building AMI with t4g.micro..."
	packer build -var="instance_type=t4g.micro" graviton-vxlan-ami.pkr.hcl

# Build with t4g.small
build-small: validate
	@echo "Building AMI with t4g.small..."
	packer build -var="instance_type=t4g.small" graviton-vxlan-ami.pkr.hcl

# Build with custom region
build-region: validate
	@echo "Building AMI in $(REGION)..."
	@test -n "$(REGION)" || (echo "ERROR: REGION not set. Usage: make build-region REGION=us-west-2"; exit 1)
	packer build -var="aws_region=$(REGION)" graviton-vxlan-ami.pkr.hcl

# Setup file permissions
setup:
	@echo "Setting executable permissions on scripts..."
	chmod +x vxlan-setup.sh
	chmod +x vxlan-teardown.sh
	chmod +x install-vxlan-service.sh

# Install VXLAN systemd service
install-vxlan: setup
	@echo "Installing VXLAN systemd service..."
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "ERROR: This target must be run with sudo"; \
		echo "Usage: sudo make install-vxlan"; \
		exit 1; \
	fi
	./install-vxlan-service.sh

# Test VXLAN without systemd
test-vxlan: setup
	@echo "Testing VXLAN setup (requires sudo)..."
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "ERROR: This target must be run with sudo"; \
		echo "Usage: sudo make test-vxlan"; \
		exit 1; \
	fi
	./vxlan-setup.sh
	@echo ""
	@echo "VXLAN interface is up. Press Enter to tear down..."
	@read dummy
	./vxlan-teardown.sh

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f manifest.json
	rm -f packer-manifest.json
	rm -f crash.log
	rm -rf packer_cache/

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
