output "instance_id" {
  description = "EC2 instance ID of the VXLAN sink"
  value       = aws_instance.vxlan_sink.id
}

output "private_ip" {
  description = "Private IP address of the VXLAN sink instance"
  value       = aws_instance.vxlan_sink.private_ip
}

output "security_group_id" {
  description = "Security group ID attached to the VXLAN sink instance"
  value       = aws_security_group.vxlan_sink.id
}

output "ami_id" {
  description = "AMI ID used for the VXLAN sink instance"
  value       = var.ami_id
}

output "vxlan_endpoint" {
  description = "VXLAN endpoint in format private_ip:4789"
  value       = "${aws_instance.vxlan_sink.private_ip}:4789"
}
