# EKS Training - Terraform Infrastructure

This repository contains Terraform Infrastructure as Code for deploying a production-ready AWS EKS (Elastic Kubernetes Service) cluster with supporting AWS infrastructure using a modular approach.

## Architecture Overview

The infrastructure is organized into reusable Terraform modules:

- **Root Module**: Orchestrates VPC and EKS modules with shared configuration
- **VPC Module**: Creates networking infrastructure (VPC, subnets, gateways, routing)
- **EKS Module**: Creates EKS cluster, node groups, IAM roles, security groups, and add-ons

## Quick Start

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name demo-cluster

# Verify cluster
kubectl get nodes
```

## Default Configuration

- **Region**: us-west-2
- **Cluster Name**: demo-cluster
- **VPC CIDR**: 10.0.0.0/16
- **Subnets**: 3 public + 3 private across multiple AZs
- **Node Group**: 2 t4g.small ARM64 instances (1-3 range)
- **Add-ons**: VPC CNI, CoreDNS, Kube Proxy, EBS CSI Driver

## Security Features

- **Private Worker Nodes**: All workers deployed in private subnets
- **KMS Encryption**: Secrets encrypted with dedicated KMS key
- **IRSA Configured**: IAM Roles for Service Accounts for all add-ons
- **Security Groups**: Minimal required access between cluster and nodes
- **IMDSv2 Enforced**: Instance metadata security enabled
- **RBAC**: Admin role and aws-auth ConfigMap configured

## Directory Structure

```
├── README.md                    # This file
├── CLAUDE.md                   # Claude Code guidance
├── main.tf                     # Root module configuration
├── variables.tf                # Root module variables
├── outputs.tf                  # Root module outputs (if exists)
├── versions.tf                 # Terraform and provider versions
└── modules/
    └── aws/                    # AWS-specific modules
        ├── vpc/                # VPC networking module
        └── eks/                # EKS cluster module
```

## Terraform Requirements

- **Terraform**: ~>1.12
- **AWS Provider**: ~> 5.100
- **Kubernetes Provider**: 2.37.1

## Common Commands

```bash
# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# View current state
terraform show

# List resources
terraform state list

# Destroy infrastructure
terraform destroy
```

## Module Documentation

- [`modules/aws/`](modules/aws/README.md) - AWS provider modules
- [`modules/aws/vpc/`](modules/aws/vpc/README.md) - VPC networking module
- [`modules/aws/eks/`](modules/aws/eks/README.md) - EKS cluster module

## Cost Considerations

This configuration is optimized for development/training with cost-effective choices:
- Single NAT Gateway (vs per-AZ)
- t4g.small instances (ARM64 graviton)
- 2 worker nodes (minimum for HA)
- Public API endpoint (no private endpoint costs)

For production, consider:
- Multiple NAT Gateways for HA
- Larger instance types
- More worker nodes
- Private API endpoint
- Additional monitoring and logging

## Cleanup

```bash
terraform destroy
```

**Note**: Ensure you have appropriate AWS credentials configured and necessary IAM permissions before deployment.