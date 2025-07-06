# AWS Modules

This directory contains Terraform modules specifically designed for AWS infrastructure provisioning. These modules follow AWS best practices and aim optimized for production-ready deployments.

## Module Structure

```
aws/
├── README.md          # This file
├── vpc/              # VPC networking module
│   ├── main.tf       # VPC, subnets, gateways, routing
│   ├── variables.tf  # Input variables
│   ├── outputs.tf    # Output values
│   ├── versions.tf   # Provider constraints
│   └── README.md     # VPC module documentation
└── eks/              # EKS cluster module
    ├── main.tf       # EKS cluster, node groups, IAM, RBAC
    ├── addons.tf     # EKS add-ons with IRSA
    ├── irsa.tf       # OIDC provider and service account roles
    ├── security_groups.tf # Network security rules
    ├── variables.tf  # Input variables
    ├── outputs.tf    # Output values
    ├── versions.tf   # Provider constraints
    └── README.md     # EKS module documentation
```

## Available Modules

### [VPC Module](vpc/README.md)
Creates a production-ready VPC with:
- Multi-AZ public and private subnets
- Internet Gateway and NAT Gateway
- Route tables and security groups
- EKS-optimized subnet tagging
- Configurable CIDR blocks and subnet counts

### [EKS Module](eks/README.md)
Creates a comprehensive EKS cluster with:
- Managed node groups with launch templates
- IAM roles and RBAC configuration
- Security groups with minimal required access
- Essential add-ons (VPC CNI, CoreDNS, Kube Proxy, EBS CSI)
- IRSA (IAM Roles for Service Accounts) for all add-ons
- KMS encryption and CloudWatch logging

## Design Principles

### Modularity
- **Separation of Concerns**: Each module handles a specific infrastructure domain
- **Reusability**: Modules can be used independently or together
- **Composition**: Parent modules orchestrate child modules for complex deployments

### Security
- **Least Privilege**: IAM roles with minimal required permissions
- **Network Isolation**: Private subnets for worker nodes, public for load balancers
- **Encryption**: KMS encryption for sensitive data at rest
- **Access Control**: RBAC and security groups with explicit rules

### Reliability
- **Multi-AZ**: Resources distributed across availability zones
- **Auto Scaling**: Configurable scaling policies for high availability
- **Monitoring**: CloudWatch integration for observability
- **Dependency Management**: Proper resource creation order

### Cost Optimization
- **Resource Sizing**: Sensible defaults for development, configurable for production
- **Spot Instances**: Support for cost-effective compute options
- **Single NAT Gateway**: Shared NAT for development (configurable for production HA)
- **ARM64 Support**: Graviton processors for better price/performance

## Module Dependencies

The modules are designed to work together:

```
VPC Module → EKS Module
     ↓           ↓
  vpc_id    private_subnets
public_subnets  ← used by EKS
```

### Typical Usage Pattern
```hcl
# VPC provides networking foundation
module "vpc" {
  source = "./modules/aws/vpc"
  # ... configuration
}

# EKS uses VPC outputs
module "eks" {
  source = "./modules/aws/eks"
  
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  public_subnets  = module.vpc.public_subnets
  # ... other configuration
}
```

## Common Patterns

### Tagging Strategy
All modules support consistent tagging:
```hcl
default_tags = {
  Environment = "production"
  Project     = "my-project"
  ManagedBy   = "Terraform"
  Owner       = "platform-team"
}
```

### Variable Validation
Modules include input validation:
- CIDR block format validation
- Instance type validation
- Required field enforcement

### Output Consistency
Modules provide comprehensive outputs:
- Resource IDs and ARNs
- Network configuration details
- Access credentials and endpoints

## AWS Provider Configuration

These modules require AWS Provider ~> 5.100:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

provider "aws" {
  region = var.region
  
  default_tags {
    tags = var.default_tags
  }
}
```

## Best Practices

### State Management
- Use remote state (S3 + DynamoDB) for production
- Separate state files for different environments
- State locking to prevent concurrent modifications

### Environment Separation
- Use different AWS accounts for prod/dev/staging
- Parameterize environment-specific values
- Use workspace or directory-based separation

### Security Considerations
- Never commit sensitive values to version control
- Use AWS Secrets Manager or Parameter Store for secrets
- Enable CloudTrail for audit logging
- Implement least-privilege IAM policies

### Operational Excellence
- Enable detailed monitoring and logging
- Implement backup strategies for persistent data
- Plan for disaster recovery scenarios
- Document runbooks for common operations

## Version Compatibility

- **Terraform**: ~>1.12
- **AWS Provider**: ~> 5.100
- **Kubernetes Provider**: 2.37.1 (for EKS module)
- **TLS Provider**: Latest (for OIDC certificate validation)

## Contributing

When adding new AWS modules:
1. Follow the established directory structure
2. Include comprehensive documentation
3. Add input validation where appropriate
4. Provide meaningful outputs
5. Follow AWS security best practices
6. Include example usage in README
7. Test with multiple scenarios

## Support

For issues with these modules:
1. Check the individual module README files
2. Validate your AWS permissions
3. Ensure provider versions are compatible
4. Review AWS service limits and quotas