variable "region" {
  type        = string
  description = "Target AWS region"
}

variable "cluster_name" {
  type        = string
  default     = "demo-cluster"
  description = "Name of the EKS cluster"
}

variable "global_tags" {
  type = map(string)
  default = {
    "ManagedBy"   = "Terraform"
    "Environment" = "dev"
  }
}

variable "domain_names" {
  type        = list(string)
  description = "List of the domain names to be used be the cluster"
}

variable "acme_email" {
  type        = string
  description = "Email for ACME registration"
}

