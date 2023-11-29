variable "name" {
  description = "Name for the worker node instance. This is also applied as the 'name' label in the cluster."
  type        = string
}

variable "ami" {
  description = "AMI to launch the worker node with"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type to create"
  type        = string

  default = "m5.2xlarge"

  validation {
    condition     = contains(["m5.2xlarge", "m5n.2xlarge", "m5.24xlarge", "m5n.24xlarge"], var.instance_type)
    error_message = "Allowed values are m5.2xlarge, m5n.2xlarge, m5.24xlarge, m5n.24xlarge"
  }
}

variable "iam_instance_profile" {
  description = "IAM instance profile to apply to the node. This should be a profile that allows the node to join the given EKS cluster"
  type        = string
}

variable "key_name" {
  description = "Key pair name to install on the node"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the node's primary interface"
  type        = string
}

variable "private_ip_address" {
  description = "Primary private IPv4 address for the node"
  type        = string
}

variable "security_groups" {
  description = "List of security group IDs to apply to the node's primary interface"
  type        = list(string)
}

variable "network_interfaces" {
  description = "Configuration for secondary interfaces for the node"
  type = list(object({
    subnet_id : string
    private_ip_addresses : list(string)
    security_groups : list(string)
  }))
}

variable "cluster_name" {
  description = "Name of the EKS cluster the node should join"
  type        = string
}

variable "kubelet_extra_args" {
  description = "Extra arguments to pass to kubelet when booting the node"
  type        = string
  default     = ""
}

variable "xrd_ami_data" {
  description = <<-EOT
  Data for configuring an XRd AMI generated by Packer.
  This should not be configured when using other AMIs.
  The following fields should be specified:
    hugepages_gb: Number of 1GiB hugepages to allocate.
    isolated_cores: cpuset string (e.g. "1-3") for the CPUs to isolate.
  EOT
  type = object({
    hugepages_gb : number
    isolated_cores : string
  })
  default = null
}

variable "user_data" {
  description = "Custom user data to append to the EC2 node's user data"
  type        = string
  default     = ""
}

variable "wait" {
  description = "Wait for node readiness"
  type        = bool
  default     = true
}
