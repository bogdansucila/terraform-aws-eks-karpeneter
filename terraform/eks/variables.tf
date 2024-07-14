variable "project" {
  description = "The name of the project. Used for tagging and naming convention"
  type        = string
}

variable "environment" {
  description = "The environment to deploy resources in (dev, qa, prod)"
  type        = string
}

variable "region" {
  description = "The region to deploy resources in"
  type        = string
}

################################################################################
# Cluster Settings
################################################################################

variable "cluster_version" {
  description = "Kubernetes `<major>.<minor>` version to use for the EKS cluster (i.e.: `1.27`)"
  type        = string
  default     = null
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

################################################################################
# VPC Settings
################################################################################

variable "vpc_id" {
  description = "ID of the VPC where the cluster security group will be provisioned"
  type        = string
  default     = null
}

variable "control_plane_subnet_ids" {
  description = "A list of subnet IDs where the EKS cluster control plane (ENIs) will be provisioned. Used for expanding the pool of subnets used by nodes/node groups without replacing the EKS control plane"
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "A list of subnet IDs where the nodes/node groups will be provisioned. If `control_plane_subnet_ids` is not provided, the EKS cluster control plane (ENIs) will be provisioned in these subnets"
  type        = list(string)
  default     = []
}

################################################################################
# Karpenter
################################################################################

variable "karpenter_chart_version" {
  description = "The version of the Karpenter chart to install"
  type        = string
  default     = "0.37.0"
}
