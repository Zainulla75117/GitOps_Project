variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "cluster_name" {
  type    = string
  default = "gitops-cluster"
}

variable "node_instance_type" {
  type    = string
  default = "c7i-flex.large"
}

variable "node_desired_size" {
  type    = number
  default = 1
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 2
}

variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "argocd_chart_version" {
  type    = string
  default = "7.4.3"
}

variable "github_repo" {
  type = string
}

variable "ecr_repo_prefix" {
  type    = string
  default = "gitops"
}
