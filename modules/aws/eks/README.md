# EKS Module

This Terraform module creates a production-ready AWS EKS cluster with managed node groups, comprehensive security configurations, IAM roles, and essential add-ons using IRSA (IAM Roles for Service Accounts).

## Architecture

The module provisions:
- **EKS Cluster** with OIDC provider and encryption
- **Managed Node Groups** with launch templates
- **IAM Roles** for cluster, nodes, and service accounts (IRSA)
- **Security Groups** with minimal required access
- **Add-ons** (VPC CNI, CoreDNS, Kube Proxy, EBS CSI Driver)
- **KMS Encryption** for cluster secrets
- **RBAC Configuration** with admin roles and aws-auth ConfigMap

## Features

- **IRSA Integration**: Dedicated IAM roles for all add-ons with least privilege access
- **Security Hardened**: IMDSv2 enforced, private workers, minimal security group rules
- **Auto-Scaling**: Configurable node group scaling with launch templates
- **Encryption**: KMS key with automatic rotation for secrets encryption
- **Multi-AZ Deployment**: Node groups span private subnets across AZs
- **CloudWatch Logging**: Configurable cluster log types (audit, api, authenticator)
- **RBAC Ready**: Bootstrap admin permissions and aws-auth ConfigMap management

## File Structure

- `main.tf` - EKS cluster, node groups, launch template, IAM roles, and RBAC
- `addons.tf` - EKS add-ons configuration with IRSA integration
- `irsa.tf` - OIDC provider and IAM Roles for Service Accounts
- `security_groups.tf` - Network security rules for cluster and worker communication
- `variables.tf` - Input variable definitions
- `outputs.tf` - Output values for cluster connection and integration
- `versions.tf` - Terraform and provider version constraints

**Note**: Helm chart deployments are now managed at the root level in `charts.tf`

## Usage

```hcl
module "eks" {
  source = "./modules/aws/eks"

  region          = "us-west-2"
  cluster_name    = "my-cluster"
  private_subnets = module.vpc.private_subnets
  public_subnets  = module.vpc.public_subnets
  vpc_id          = module.vpc.vpc_id

  managed_node_groups = {
    main = {
      name           = "main-node-group"
      desired_size   = 2
      min_size       = 1
      max_size       = 4
      instance_types = ["t4g.medium"]
    }
  }

  enabled_cluster_log_types = ["audit", "api", "authenticator"]
}
```

## Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | `string` | *required* | AWS region |
| `cluster_name` | `string` | *required* | Name of the EKS cluster |
| `vpc_id` | `string` | *required* | VPC ID where cluster will be deployed |
| `private_subnets` | `list(string)` | *required* | Private subnet IDs for worker nodes |
| `public_subnets` | `list(string)` | *required* | Public subnet IDs for load balancers |
| `managed_node_groups` | `map(object)` | `{}` | Configuration for managed node groups |
| `default_ami_type` | `string` | `"AL2023_ARM_64_STANDARD"` | AMI type for worker nodes |
| `default_capacity_type` | `string` | `"ON_DEMAND"` | Capacity type (ON_DEMAND or SPOT) |
| `cluster_addons` | `list(string)` | `["vpc-cni", "kube-proxy", "coredns", "aws-ebs-csi-driver"]` | List of cluster add-ons |
| `enabled_cluster_log_types` | `list(string)` | `["audit", "api", "authenticator"]` | CloudWatch log types to enable |

## Outputs

| Name | Description |
|------|-------------|
| `cluster` | Complete EKS cluster resource |
| `cluster_id` | EKS cluster ID |
| `cluster_endpoint` | Kubernetes API server endpoint |
| `cluster_security_group_id` | Cluster security group IDs |
| `node_group_role_arn` | ARN of the node group IAM role |
| `cluster_admins_arn` | ARN of the admin IAM role |
| `cluster_certificate_authority_data` | Base64 decoded CA certificate |
| `cluster_auth_token` | Authentication token for cluster access |
| `oidc_provider_arn` | OIDC provider ARN for IRSA |
| `oidc_provider_id` | OIDC provider ID |
| `secrets_csi_irsa_role_arn` | ARN of Secrets Store CSI Driver IRSA role |
| `cert_manager_irsa_role_arn` | ARN of cert-manager IRSA role |
| `secrets_csi_policy_arn` | ARN of Secrets Store CSI Driver policy |
| `cert_manager_policy_arn` | ARN of cert-manager policy |

## Module Outputs Usage

### **Provider Configuration Outputs**
Used by root-level provider configuration in `versions.tf`:

```hcl
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority_data  
  token                  = module.eks.cluster_auth_token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = module.eks.cluster_certificate_authority_data
    token                  = module.eks.cluster_auth_token
  }
}
```

### **IRSA Integration Outputs**
Used by root-level Helm charts in `charts.tf`:

```hcl
resource "helm_release" "external_secrets" {
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.secrets_csi_irsa_role_arn  # ← Module output
  }
}

resource "helm_release" "cert_manager" {
  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.eks.cert_manager_irsa_role_arn  # ← Module output
        }
      }
    })
  ]
}
```

### **Informational Outputs**
Available for reference but not typically used externally:
- `cluster_id`, `oidc_provider_arn`, `admin_access_entry_arn`
- Useful for debugging or integration with other tools

### **EKS Add-on Outputs**
**Note**: EKS managed add-ons (VPC CNI, CoreDNS, Kube Proxy, EBS CSI, Load Balancer Controller) do **not** need module outputs since they're fully managed by EKS and use IRSA roles internally.

## Security Configuration

### Network Security
- **Bi-directional Security Groups**: Separate SGs for cluster and nodes with explicit communication rules
- **Minimal Port Access**: Only required ports (443, 10250, 8443, 53, ephemeral range)
- **Private Workers**: All worker nodes deployed in private subnets only

### Encryption and Access
- **KMS Encryption**: Dedicated KMS key for secrets with rotation enabled
- **IMDSv2 Enforced**: Instance metadata security with hop limit and token requirements
- **RBAC Integration**: Dual authentication mode (API_AND_CONFIG_MAP)
- **Bootstrap Admin**: Cluster creator gets automatic admin permissions

### Authentication Configuration  

**Dual Authentication Mode: API_AND_CONFIG_MAP**
```hcl
access_config {
  authentication_mode                         = "API_AND_CONFIG_MAP"
  bootstrap_cluster_creator_admin_permissions = true
}
```

**Benefits:**
- **New API Method**: Uses EKS access entries (recommended)  
- **Legacy Support**: Maintains aws-auth ConfigMap compatibility
- **Smooth Migration**: Both methods work simultaneously
- **Bootstrap Access**: Cluster creator gets immediate admin access

**Access Management:**
- **API Mode**: Managed via `aws_eks_access_entry` and `aws_eks_access_policy_association`
- **ConfigMap Mode**: Traditional aws-auth ConfigMap (backwards compatibility)
- **Automatic Bootstrap**: `bootstrap_cluster_creator_admin_permissions = true` ensures immediate access

**Access Entry Example:**
```hcl
resource "aws_eks_access_entry" "admin_role" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.eks_admins_role.arn  # IAM role ARN
  type          = "STANDARD"  # For IAM roles/users
}

resource "aws_eks_access_policy_association" "admin_policy" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.eks_admins_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  
  access_scope {
    type = "cluster"  # Cluster-wide permissions
  }
}
```

### IRSA (IAM Roles for Service Accounts)
Each add-on has dedicated IAM roles with minimal required permissions:
- **VPC CNI**: `system:serviceaccount:kube-system:aws-node`
- **EBS CSI**: `system:serviceaccount:kube-system:ebs-csi-controller-sa`
- **CoreDNS**: `system:serviceaccount:kube-system:coredns`
- **Kube Proxy**: `system:serviceaccount:kube-system:kube-proxy`
- **Load Balancer Controller**: `system:serviceaccount:kube-system:aws-load-balancer-controller`
- **Secrets CSI**: `system:serviceaccount:kube-system:secrets-store-csi-driver` (external chart)
- **Cert-Manager**: `system:serviceaccount:cert-manager:cert-manager` (external chart)

## Node Group Configuration

### Launch Template Features
- **Security Groups**: Dedicated security group for worker communication
- **Block Device Mapping**: 20GB GP3 EBS volumes with termination protection
- **Metadata Options**: IMDSv2 enforced with proper hop limits
- **Lifecycle Management**: `create_before_destroy` for zero-downtime updates

### Default Configuration
- **Instance Type**: t4g.small (ARM64 Graviton processors)
- **AMI**: Amazon Linux 2023 ARM64
- **Capacity**: ON_DEMAND instances
- **Scaling**: 2 desired, 1-3 range (configurable)

## Add-ons Management

### Version Resolution
- **Dynamic Versioning**: Uses data sources to get compatible versions based on cluster Kubernetes version
- **Conflict Resolution**: All add-ons configured with `OVERWRITE` for seamless updates
- **Dependency Management**: Proper creation order with node group dependencies

### Supported Add-ons
1. **VPC CNI**: Pod networking with IRSA role
2. **CoreDNS**: DNS resolution with IRSA role  
3. **Kube Proxy**: Network proxy with IRSA role
4. **EBS CSI Driver**: Persistent volume support with IRSA role
5. **AWS Load Balancer Controller**: ALB/NLB management with IRSA role

### IRSA Roles for External Charts
The module creates IRSA roles for common external charts (deployed at root level):
1. **Secrets Store CSI Driver**: Access to AWS Secrets Manager and Parameter Store
2. **Cert-Manager**: Integration with AWS Certificate Manager and Route53

### IRSA Permissions Summary
**EKS Add-ons (Managed):**
- VPC CNI → AmazonEKS_CNI_Policy
- EBS CSI → AmazonEBSCSIDriverPolicy  
- CoreDNS → (No additional permissions required)
- Kube Proxy → (No additional permissions required)
- Load Balancer Controller → Custom policy (EC2, ELB operations)

**External Charts (Root-level):**
- Secrets CSI → Custom policy (SecretsManager, SSM read-only)
- Cert-Manager → Custom policy (ACM, Route53 operations)

## IAM Configuration

### Cluster Roles
- **EKS Cluster Role**: With required AWS managed policies
- **EKS Admin Role**: For administrative access with assume role policy
- **Node Group Role**: For worker nodes with required permissions

### Managed Policies Applied
- `AmazonEKSClusterPolicy`
- `AmazonEKSVPCResourceController`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`
- `CloudWatchFullAccess`

## RBAC and Access Control

### aws-auth ConfigMap
Automatically configured with:
- **Admin Role Mapping**: EKS admin role → `system:masters` group
- **Node Role Mapping**: Worker nodes → `system:bootstrappers`, `system:nodes` groups  
- **User Mapping**: Cluster creator → `system:masters` group

### Authentication Modes
- **API Mode**: Standard Kubernetes RBAC
- **ConfigMap Mode**: aws-auth ConfigMap for IAM integration
- **Bootstrap**: Cluster creator gets automatic admin permissions

## Connecting to the Cluster

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name my-cluster

# Verify connection
kubectl get nodes
kubectl get pods --all-namespaces

# Check cluster info
kubectl cluster-info
```

## AWS Secrets Integration

The module includes AWS Secrets Store CSI Driver for secure access to AWS secrets and parameters.

### Secret Naming Requirements

The CSI driver can **only** access secrets and parameters that follow the cluster naming convention:

#### Secrets Manager
- **Path format**: `${cluster-name}/path/to/secret`
- **Prefix format**: `${cluster-name}-secret-name`

**Examples for cluster "demo-cluster":**
```
demo-cluster/database/password
demo-cluster/app1/api-keys
demo-cluster-redis-auth
demo-cluster-shared-config
```

#### Parameter Store
- **Path format**: `/${cluster-name}/path/to/parameter`
- **Prefix format**: `/${cluster-name}-parameter-name`

**Examples for cluster "demo-cluster":**
```
/demo-cluster/database/connection-string
/demo-cluster/app1/config
/demo-cluster-shared-settings
```

### Security Isolation

- **Cluster-Scoped Access**: Each cluster can only access its own secrets
- **Multi-Tenancy Safe**: Multiple clusters in same AWS account are isolated
- **Least Privilege**: Read-only access to cluster-specific secrets only

### Usage Example

```yaml
apiVersion: v1
kind: SecretProviderClass
metadata:
  name: app-secrets
  namespace: default
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "demo-cluster/app1/database-password"
        objectType: "secretsmanager"
      - objectName: "/demo-cluster/app1/config"
        objectType: "ssmparameter"
```

### Required AWS Resources

Before using the CSI driver, ensure your secrets exist in AWS:

```bash
# Create secret in Secrets Manager
aws secretsmanager create-secret \
  --name "demo-cluster/app1/database-password" \
  --secret-string "your-secret-value"

# Create parameter in Parameter Store  
aws ssm put-parameter \
  --name "/demo-cluster/app1/config" \
  --value "your-config-value" \
  --type "SecureString"
```

## Monitoring and Logging

### CloudWatch Integration
- **Cluster Logs**: audit, api, authenticator logs sent to CloudWatch
- **Log Groups**: Automatically created with retention policies
- **Metrics**: EKS control plane metrics available

### Observability
- **OIDC Integration**: Ready for external monitoring tools
- **Service Mesh Ready**: Prepared for Istio, Linkerd integration
- **CNI Metrics**: VPC CNI provides detailed networking metrics

## Production Considerations

### High Availability
- **Multi-AZ**: Worker nodes distributed across availability zones
- **Auto Scaling**: Configurable min/max scaling policies
- **Rolling Updates**: Launch template updates with zero downtime

### Cost Optimization
- **ARM64 Instances**: Graviton processors for better price/performance
- **Spot Instances**: Configurable capacity type for cost savings
- **Right-sizing**: Start with t4g.small, scale as needed

### Security Hardening
- **Private API Endpoint**: Consider for production workloads
- **Pod Security Standards**: Ready for PSS implementation
- **Network Policies**: CNI supports Kubernetes network policies
- **Secrets Encryption**: KMS integration for enhanced security

## Dependencies

- **VPC Module**: Requires VPC with proper subnet configuration
- **AWS Provider**: ~> 5.100 with appropriate permissions
- **TLS Provider**: For OIDC certificate validation

**Note**: This module is provider-agnostic for Kubernetes/Helm providers. Those should be configured at the root level using this module's outputs.

### EKS Add-on Dependencies
**EKS Managed Add-ons** (no external dependencies):
- VPC CNI, CoreDNS, Kube Proxy, EBS CSI Driver, AWS Load Balancer Controller
- All IRSA roles and permissions managed internally by this module
- No root-level outputs or integration required

**External Charts** (require root-level integration):
- External Secrets, Cert-Manager → Use module IRSA outputs in root `charts.tf`

## Root-Level Integration

This module is designed to work with root-level Helm chart deployments:

```hcl
# Root charts.tf uses module outputs
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.secrets_csi_irsa_role_arn
  }

  depends_on = [module.eks]
}
```