locals {
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
  name        = var.name
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
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.vxlan_sink.id]
  key_name                    = var.key_name
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = false

  tags = local.common_tags
}
