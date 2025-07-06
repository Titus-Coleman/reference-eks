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

## Architecture Deep Dive

### Module Dependencies and Data Flow
- **VPC → EKS Dependency**: EKS module depends on VPC outputs (`vpc_id`, `private_subnets`, `public_subnets`)
- **Root Module Orchestration**: Root module passes `cluster_name` consistently to both modules for naming
- **Output Patterns**: VPC uses `for` expressions for dynamic subnet lists

### IRSA Implementation Pattern
- **Single OIDC Provider**: Created using EKS cluster's identity issuer URL
- **Service Account Binding**: Each addon has dedicated IRSA role with specific conditions:
  - VPC CNI: `system:serviceaccount:kube-system:aws-node`
  - EBS CSI: `system:serviceaccount:kube-system:ebs-csi-controller-sa`
  - CoreDNS: `system:serviceaccount:kube-system:coredns` 
  - Kube Proxy: `system:serviceaccount:kube-system:kube-proxy`
- **URL Processing**: Uses `replace()` to strip `https://` from OIDC URLs in conditions

### Security Group Architecture
- **Bi-directional Communication**: Separate SGs for cluster and nodes with explicit inter-group rules
- **Minimal Access**: Specific ports only (443, 10250, 8443, 53, ephemeral range)
- **Kubernetes Tags**: Node SG tagged with `kubernetes.io/cluster/${cluster_name}` = "owned"

### Addon Management Pattern
- **Version Resolution**: Data sources get compatible versions based on cluster Kubernetes version
- **Conflict Handling**: All addons use `OVERWRITE` for create/update conflicts
- **IRSA Integration**: Each addon linked via `service_account_role_arn`
- **Dependencies**: All addons depend on node groups for proper creation order

### Networking Strategy
- **Multi-AZ Design**: Dynamic AZ selection using `data.aws_availability_zones.available`
- **CIDR Calculation**: Uses `cidrsubnet()` with configurable additional bits (default 4)
- **LB Tags**: Public subnets tagged for ELB, private for internal-ELB
- **Cost Optimization**: Single NAT gateway in first public subnet

### IAM and RBAC Patterns
- **Dual Authentication**: `API_AND_CONFIG_MAP` mode supports both methods
- **Admin Bootstrap**: Cluster creator gets automatic admin permissions
- **aws-auth ConfigMap**: Managed via Kubernetes provider with predefined role/user mappings

### Security and Encryption
- **KMS Integration**: Dedicated key for secrets encryption with rotation enabled
- **Launch Template Security**: IMDSv2 enforced, metadata hop limit 2, tags enabled
- **Node Placement**: Workers only in private subnets

### Terraform Conventions
- **Naming Pattern**: `${var.cluster_name}-component-type` throughout
- **Tag Strategy**: Uses `merge()` for combining default and resource-specific tags
- **For-Each Usage**: Node groups use `for_each` with object variables for flexibility
- **Data Source Leverage**: Dynamic values from AZs, addon versions, partition data

### Recent Changes
The project has been refactored to break out EKS components into separate files (addons.tf, security_groups.tf, irsa.tf) for better maintainability. All EKS addons now have dedicated IRSA roles following security best practices.