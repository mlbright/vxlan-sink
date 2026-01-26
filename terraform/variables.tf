variable "ami_id" {
  description = "AMI ID for the VXLAN sink instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. Must be ARM64/Graviton compatible."
  type        = string
  default     = "t4g.nano"
}

variable "vpc_id" {
  description = "VPC ID where the VXLAN sink instance will be deployed."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the VXLAN sink instance."
  type        = string
}

variable "key_name" {
  description = "SSH key pair name for instance access. Optional."
  type        = string
  default     = null
}

variable "ssh_source_cidrs" {
  description = "List of CIDR blocks allowed SSH access (TCP 22). Empty list disables SSH access."
  type        = list(string)
  default     = []
}

variable "iam_instance_profile" {
  description = "IAM instance profile name to attach to the instance. Optional."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "name" {
  description = "Name prefix for resources created by this module."
  type        = string
  default     = "vxlan-sink"
}
