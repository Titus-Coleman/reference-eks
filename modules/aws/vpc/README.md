# VPC Module

This Terraform module creates a production-ready AWS VPC with public and private subnets across multiple Availability Zones, designed specifically for EKS cluster deployment.

## Architecture

The module provisions:
- **VPC** with configurable CIDR block (default: 10.0.0.0/16)
- **Multi-AZ Deployment** across 3 availability zones
- **Public Subnets** (3) with internet gateway routing
- **Private Subnets** (3) with NAT gateway routing
- **Internet Gateway** for public subnet internet access
- **NAT Gateway** (optional, single for cost optimization)
- **Route Tables** with proper public/private routing
- **Default Security Group** (restrictive by default)

## Features

- **Dynamic AZ Selection**: Uses `data.aws_availability_zones.available` for automatic AZ discovery
- **Flexible CIDR Calculation**: Uses `cidrsubnet()` function with configurable additional bits
- **Kubernetes Integration**: Proper subnet tagging for EKS load balancer support
- **Cost Optimized**: Single NAT gateway shared across private subnets
- **DNS Enabled**: Support for DNS resolution and hostnames
- **Tag Management**: Merge strategy for default and resource-specific tags

## Usage

```hcl
module "vpc" {
  source = "./modules/aws/vpc"

  vpc_name             = "my-cluster-vpc"
  cidr_block           = "10.0.0.0/16"
  nat_gateway          = true
  enable_dns_support   = true
  enable_dns_hostnames = true

  public_subnet_count  = 3
  private_subnet_count = 3
  
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  default_tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
```

## Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `vpc_name` | `string` | *required* | Name of the VPC |
| `cidr_block` | `string` | `"10.0.0.0/16"` | IPv4 CIDR block for VPC |
| `nat_gateway` | `bool` | `false` | Deploy NAT Gateway for private subnet internet access |
| `enable_dns_support` | `bool` | `true` | Enable DNS support in VPC |
| `enable_dns_hostnames` | `bool` | `false` | Enable DNS hostnames in VPC |
| `public_subnet_count` | `number` | `3` | Number of public subnets to create |
| `private_subnet_count` | `number` | `3` | Number of private subnets to create |
| `public_subnet_additional_bits` | `number` | `4` | Additional bits for public subnet CIDR calculation |
| `private_subnet_additional_bits` | `number` | `4` | Additional bits for private subnet CIDR calculation |
| `public_subnet_tags` | `map(string)` | `{}` | Additional tags for public subnets |
| `private_subnet_tags` | `map(string)` | `{}` | Additional tags for private subnets |
| `default_tags` | `map(string)` | `{}` | Default tags applied to all resources |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | The ID of the VPC |
| `public_subnets` | List of public subnet IDs |
| `private_subnets` | List of private subnet IDs |
| `aws_internet_gateway` | Internet Gateway resource |
| `aws_route_table_public` | ID of the public route table |
| `aws_route_table_private` | ID of the private route table |
| `nat_gateway_ipv4_address` | Public IP address of NAT Gateway (if created) |

## CIDR Allocation

With default settings (CIDR: 10.0.0.0/16, additional_bits: 4):

**Public Subnets:**
- 10.0.0.0/20 (AZ-1)
- 10.0.16.0/20 (AZ-2) 
- 10.0.32.0/20 (AZ-3)

**Private Subnets:**
- 10.0.48.0/20 (AZ-1)
- 10.0.64.0/20 (AZ-2)
- 10.0.80.0/20 (AZ-3)

## EKS Integration

The module is designed for seamless EKS integration:

**Subnet Tagging:**
- Public subnets tagged with `kubernetes.io/role/elb` for external load balancers
- Private subnets tagged with `kubernetes.io/role/internal-elb` for internal load balancers
- Cluster-specific tags added by parent module

**Networking:**
- Private subnets for worker nodes (security best practice)
- Public subnets for load balancers and NAT gateway
- Proper routing for pod-to-internet communication via NAT

## Security Considerations

- **Default Security Group**: Restrictive by default (no ingress/egress rules)
- **Private Workers**: EKS nodes deployed in private subnets only
- **NAT Gateway**: Single gateway for cost optimization (consider multiple for production HA)
- **DNS**: Enabled for proper Kubernetes service discovery

## Cost Optimization

- **Single NAT Gateway**: Shared across all private subnets (vs per-AZ)
- **Configurable Resources**: Optional NAT gateway with `nat_gateway = false`
- **Right-sized Subnets**: /20 subnets provide 4,096 IPs each (adjust `additional_bits` as needed)

## Files

- `main.tf` - VPC, subnets, gateways, and routing configuration
- `variables.tf` - Input variable definitions with validation
- `outputs.tf` - Output values for use by other modules
- `versions.tf` - Terraform and provider version constraints
- `README.md` - This documentation

## Validation

The module includes input validation:
- **CIDR Block**: Validates using `can(cidrnetmask(var.cidr_block))`
- **Required Fields**: `vpc_name` is non-nullable

## Dependencies

- **AWS Provider**: Uses AWS availability zones data source  
- **Terraform**: Compatible with Terraform ~>1.12

## Integration Notes

This module is designed for seamless integration with the EKS module and root-level configurations. All networking is properly configured for Kubernetes workloads with appropriate subnet tagging and routing.