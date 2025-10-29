packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Variables
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t4g.nano" # Cheapest Graviton instance type
}

variable "ami_name_prefix" {
  type    = string
  default = "vxlan-graviton"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "volume_size" {
  type    = number
  default = 8
}

# Data source for latest Ubuntu ARM64 AMI
data "amazon-ami" "ubuntu_arm64" {
  filters = {
    name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID
  region      = var.aws_region
}

# Source configuration
source "amazon-ebs" "graviton_vxlan" {
  # AMI Configuration
  ami_name        = "${var.ami_name_prefix}-{{timestamp}}"
  ami_description = "Ubuntu 22.04 ARM64 with VXLAN support on Graviton"
  
  # Instance Configuration
  instance_type = var.instance_type
  region        = var.aws_region
  source_ami    = data.amazon-ami.ubuntu_arm64.id
  
  # SSH Configuration
  ssh_username = var.ssh_username
  ssh_timeout  = "10m"
  
  # EBS Volume Configuration
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }
  
  # AMI Block Device Mappings
  ami_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }
  
  # Tags
  tags = {
    Name         = "${var.ami_name_prefix}-{{timestamp}}"
    OS           = "Ubuntu 22.04"
    Architecture = "ARM64"
    Processor    = "Graviton"
    Purpose      = "VXLAN Network"
    BuildDate    = "{{timestamp}}"
  }
  
  # Run tags (tags applied to the builder instance)
  run_tags = {
    Name    = "Packer Builder - ${var.ami_name_prefix}"
    Purpose = "AMI Build"
  }
  
  # Snapshot tags
  snapshot_tags = {
    Name         = "${var.ami_name_prefix}-snapshot-{{timestamp}}"
    Purpose      = "VXLAN Network AMI Snapshot"
  }
}

# Build configuration
build {
  name    = "graviton-vxlan-ami"
  sources = ["source.amazon-ebs.graviton_vxlan"]
  
  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo 'Cloud-init completed'"
    ]
  }
  
  # Update system packages
  provisioner "shell" {
    inline = [
      "echo 'Updating system packages...'",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'",
      "echo 'System packages updated'"
    ]
  }
  
  # Install required packages
  provisioner "shell" {
    inline = [
      "echo 'Installing required packages...'",
      "sudo apt-get install -y bridge-utils iproute2 nftables net-tools tcpdump",
      "echo 'Required packages installed'"
    ]
  }
  
  # Copy VXLAN scripts
  provisioner "file" {
    source      = "vxlan-setup.sh"
    destination = "/tmp/vxlan-setup.sh"
  }
  
  provisioner "file" {
    source      = "vxlan-teardown.sh"
    destination = "/tmp/vxlan-teardown.sh"
  }
  
  provisioner "file" {
    source      = "vxlan.service"
    destination = "/tmp/vxlan.service"
  }
  
  # Install VXLAN configuration
  provisioner "shell" {
    inline = [
      "echo 'Installing VXLAN configuration...'",
      "sudo install -m 755 /tmp/vxlan-setup.sh /usr/local/bin/vxlan-setup.sh",
      "sudo install -m 755 /tmp/vxlan-teardown.sh /usr/local/bin/vxlan-teardown.sh",
      "sudo install -m 644 /tmp/vxlan.service /etc/systemd/system/vxlan.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable vxlan.service",
      "echo 'VXLAN service installed and enabled'",
      "rm /tmp/vxlan-setup.sh /tmp/vxlan-teardown.sh /tmp/vxlan.service"
    ]
  }
  
  # Enable IP forwarding for VXLAN
  provisioner "shell" {
    inline = [
      "echo 'Configuring IP forwarding...'",
      "sudo tee /etc/sysctl.d/99-vxlan.conf > /dev/null <<EOF",
      "# IP forwarding for VXLAN",
      "net.ipv4.ip_forward = 1",
      "net.ipv6.conf.all.forwarding = 1",
      "EOF",
      "sudo sysctl -p /etc/sysctl.d/99-vxlan.conf",
      "echo 'IP forwarding configured'"
    ]
  }
  
  # Clean up
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "history -c",
      "echo 'Cleanup completed'"
    ]
  }
  
  # Post-processor to create manifest
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      ami_name      = "${var.ami_name_prefix}-{{timestamp}}"
      instance_type = var.instance_type
      region        = var.aws_region
    }
  }
}
