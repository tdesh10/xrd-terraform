variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  nullable    = false
  default     = "xrd-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version to use in the cluster"
  type        = string
  nullable    = false
  default     = "1.27"
}

variable "create_bastion" {
  description = "Whether to create a bastion (gateway) node."
  type        = bool
  nullable    = false
  default     = true
}

variable "create_nodes" {
  description = "Whether to create any worker nodes."
  type        = bool
  nullable    = false
  default     = true
}

variable "node_ami" {
  description = "AMI ID to use on worker nodes. If empty, will attempt to find an AMI generated by XRd Packer. This _must_ be an AMI generated by XRd Packer."
  type        = string
  default     = null
}

variable "node_instance_type" {
  description = "Instance type to be used for worker nodes."
  type        = string
  nullable    = false
  default     = "m5.2xlarge"

  validation {
    condition     = contains(["m5.2xlarge", "m5n.2xlarge", "m5.24xlarge", "m5n.24xlarge"], var.node_instance_type)
    error_message = "Allowed values are m5.2xlarge, m5n.2xlarge, m5.24xlarge, m5n.24xlarge"
  }
}

variable "node_count" {
  description = "Number of worker nodes to create."
  type        = number
  nullable    = false

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 15 && floor(var.node_count) == var.node_count
    error_message = "Accepted values: 1-15"
  }
}

variable "node_names" {
  description = "Explicit values to use for the node label in Kubernetes. If empty, these are generated as 'nodeN'"
  type        = list(string)
  nullable    = false
  default     = []
}

variable "interface_count" {
  description = "Number of interfaces to create on each worker node. Each of these are in a separate subnet."
  type        = number
  nullable    = false

  validation {
    condition     = var.interface_count >= 0 && var.interface_count <= 15 && floor(var.interface_count) == var.interface_count
    error_message = "Accepted values: 0-15"
  }
}

variable "create_helm_chart" {
  description = "Whether to create wrapper Helm chart with default values for interface IPs"
  type        = bool
  nullable    = false
  default     = true
}

variable "xrd_platform" {
  description = "Which XRd platform to create the Helm chart for"
  type        = string
  nullable    = false
  default     = "vRouter"

  validation {
    condition     = contains(["ControlPlane", "vRouter"], var.xrd_platform)
    error_message = "Allowed values are \"ControlPlane\" or \"vRouter\""
  }
}

variable "xr_root_user" {
  description = "Root user name to use on XRd instances"
  type        = string
  nullable    = false
}

variable "xr_root_password" {
  description = "Root user password to use on XRd instances"
  type        = string
  nullable    = false
}

variable "image_repository" {
  description = "Image repository where the XRd container image is hosted"
  type        = string
  default     = null
}

variable "image_tag" {
  description = "Tag of the XRd container image in the repository."
  type        = string
  nullable    = false
  default     = "latest"
}