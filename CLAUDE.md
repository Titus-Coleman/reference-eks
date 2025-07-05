# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform Infrastructure as Code project for AWS EKS (Elastic Kubernetes Service) training. It creates a production-ready EKS cluster with supporting AWS infrastructure using a modular approach.

## Common Commands

### Terraform Operations
```bash
# Initialize Terraform (run first time or after module changes)
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy

# Format Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate
```

### Development Workflow
```bash
# Check current state
terraform show

# View state list
terraform state list

# Import existing resources (if needed)
terraform import <resource_type.name> <resource_id>
```

## Architecture

### Module Structure
- **Root Module** (`main.tf`): Orchestrates VPC and EKS modules
- **VPC Module** (`modules/aws/vpc/`): Creates networking infrastructure (VPC, subnets, gateways)
- **EKS Module** (`modules/aws/eks/`): Creates EKS cluster, node groups, IAM roles, and add-ons

### Key Components
- **VPC**: 10.0.0.0/16 with 3 public/private subnets across AZs
- **EKS Cluster**: With OIDC provider, encryption, and CloudWatch logging
- **Node Groups**: ARM64 instances (t4g.small) in private subnets
- **Security**: Dedicated security groups for cluster and workers
- **IRSA**: IAM Roles for Service Accounts configured
- **Add-ons**: VPC CNI, CoreDNS, Kube Proxy, EBS CSI Driver support

### Important Files
- `main.tf`: Root configuration orchestrating modules
- `modules/aws/eks/main.tf`: EKS cluster definition
- `modules/aws/eks/addons.tf`: EKS add-ons configuration
- `modules/aws/eks/irsa.tf`: IAM Roles for Service Accounts
- `modules/aws/eks/security_groups.tf`: Network security rules
- `modules/aws/vpc/main.tf`: VPC and networking setup

## Configuration

### Default Values
- **Region**: us-west-2
- **Cluster Name**: demo-cluster
- **Node Group**: 2 desired (1-3 range), t4g.small instances
- **Network**: 10.0.0.0/16 VPC with multi-AZ deployment

### Terraform Requirements
- Terraform: ~>1.12
- AWS Provider: ~> 5.100
- Kubernetes Provider: 2.37.1

## Development Notes

### Modular Design
The project follows Terraform best practices with separate modules for VPC and EKS. Each module has its own variables, outputs, and versions files.

### Security Best Practices
- KMS encryption for secrets
- Private worker nodes
- Dedicated security groups with minimal required access
- RBAC with admin role configuration
- Proper subnet tagging for Kubernetes load balancer integration

### Recent Changes
The project has been refactored to break out EKS components into separate files (addons.tf, security_groups.tf, irsa.tf) for better maintainability.