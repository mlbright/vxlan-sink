# Look up the latest VXLAN sink AMI when ami_id is not explicitly provided
data "aws_ami" "vxlan" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["${var.ami_name_prefix}-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  ami_id = coalesce(var.ami_id, try(data.aws_ami.vxlan[0].id, null))

  common_tags = merge(
    {
      Name      = var.name
      ManagedBy = "terraform"
      Purpose   = "vxlan-sink"
    },
    var.tags
  )
}

# Security group for VXLAN sink instance
resource "aws_security_group" "vxlan_sink" {
  name        = "${var.name}-sg"
  description = "Security group for VXLAN sink instance"
  vpc_id      = var.vpc_id

  tags = local.common_tags
}

# Inbound VXLAN traffic (UDP 4789)
resource "aws_security_group_rule" "vxlan_ingress" {
  type              = "ingress"
  from_port         = 4789
  to_port           = 4789
  protocol          = "udp"
  cidr_blocks       = var.vxlan_source_cidrs
  security_group_id = aws_security_group.vxlan_sink.id
  description       = "Allow VXLAN traffic from specified CIDRs"
}

# Inbound SSH traffic (TCP 22) - only when ssh_source_cidrs is non-empty
resource "aws_security_group_rule" "ssh_ingress" {
  count = length(var.ssh_source_cidrs) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_source_cidrs
  security_group_id = aws_security_group.vxlan_sink.id
  description       = "Allow SSH from specified CIDRs"
}

# Outbound traffic (all)
resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vxlan_sink.id
  description       = "Allow all outbound traffic"
}

# VXLAN sink EC2 instance
resource "aws_instance" "vxlan_sink" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.vxlan_sink.id]
  key_name                    = var.key_name
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = false

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = local.ami_id != null
      error_message = "AMI ID could not be determined. Either provide ami_id or ensure an AMI matching ami_name_prefix exists."
    }
  }
}
