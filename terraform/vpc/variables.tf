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

variable "vpc_cidr" {
  description = "The CIDR range of the VPC where the EKS cluster will be deployed"
  type        = string
}