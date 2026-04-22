packer {
  required_plugins {
    azure = {
      version = ">= 2.0.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

# Variables
variable "location" {
  type    = string
  default = "East US 2"
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "resource_group" {
  type    = string
  default = "vxlan-sink-images"
}

variable "gallery_name" {
  type    = string
  default = "dev_builds"
}

variable "image_name" {
  type    = string
  default = "vxlan-sink"
}

locals {
  image_version = formatdate("YYYY.MMDD.hhmm", timestamp())
}

# Source configuration
source "azure-arm" "vxlan" {
  use_azure_cli_auth = true

  # Source image: Ubuntu 24.04 LTS (Gen2)
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"

  # VM configuration
  location = var.location
  vm_size  = var.vm_size

  # Managed image (intermediate artifact)
  managed_image_name                = "vxlan-sink-${formatdate("YYYYMMDDhhmm", timestamp())}"
  managed_image_resource_group_name = var.resource_group

  # Publish to Azure Compute Gallery
  shared_image_gallery_destination {
    resource_group = var.resource_group
    gallery_name   = var.gallery_name
    image_name     = var.image_name
    image_version  = local.image_version
    replication_regions = [var.location]
  }

  # Tags applied to build resources
  azure_tags = {
    Name      = "vxlan-sink"
    Purpose   = "VXLAN Network"
    BuildDate = timestamp()
  }
}

# Build configuration
build {
  name    = "azure-vxlan-image"
  sources = ["source.azure-arm.vxlan"]

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
      "sudo apt-get install -y iproute2 nftables net-tools tcpdump",
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
      "echo 'Cleanup completed'"
    ]
  }

  # Deprovision the Azure VM agent (required for Azure images)
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
  }
}
