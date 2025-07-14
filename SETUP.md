# EKS Training Infrastructure Setup Guide

This guide provides step-by-step instructions to deploy and configure the EKS training infrastructure from scratch.

## Prerequisites

### Software Requirements

**Install the following tools:**

1. **AWS CLI** (v2.0+)
   ```bash
   # macOS
   brew install awscli
   
   # Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   
   # Verify installation
   aws --version
   ```

2. **Terraform** (~1.12)
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.12.0/terraform_1.12.0_linux_amd64.zip
   unzip terraform_1.12.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   
   # Verify installation
   terraform version
   ```

3. **kubectl** (latest)
   ```bash
   # macOS
   brew install kubectl
   
   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl
   sudo mv kubectl /usr/local/bin/
   
   # Verify installation
   kubectl version --client
   ```

4. **Git**
   ```bash
   # macOS (git is included in macOS)
   
   # Linux (Ubuntu/Debian)
   sudo apt-get update && sudo apt-get install git
   
   # Verify installation
   git --version
   ```

### AWS Account Setup

**1. AWS Account Requirements:**
- Active AWS account with billing enabled
- Admin-level access or the following minimum permissions

**2. Required IAM Permissions:**
Create an IAM user or role with these managed policies:
- `PowerUserAccess` (recommended for simplicity)
- OR specific permissions for:
  - EC2 (VPC, Subnets, Security Groups, Launch Templates)
  - EKS (Clusters, Node Groups, Add-ons)
  - IAM (Roles, Policies, OIDC Providers)
  - KMS (Key management)
  - CloudWatch (Log Groups)

**3. AWS CLI Configuration:**
```bash
aws configure
```
Enter your:
- AWS Access Key ID
- AWS Secret Access Key  
- Default region: `us-west-2`
- Output format: `json`

**4. Verify AWS Access:**
```bash
aws sts get-caller-identity
aws eks list-clusters --region us-west-2
```

## Infrastructure Deployment

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd eks-training
```

### Step 2: Review Configuration

**Check default variables in `variables.tf`:**
```hcl
variable "region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  default     = "demo-cluster"
}
```

**Customize if needed** by creating `terraform.tfvars`:
```hcl
region       = "us-east-1"
cluster_name = "my-training-cluster"
```

### Step 3: Initialize Terraform

```bash
terraform init
```

**Expected output:**
- Downloads required providers (AWS ~5.100, Kubernetes 2.37.1, Helm ~2.12)
- Initializes backend
- Success message

### Step 4: Plan Deployment

```bash
terraform plan
```

**Review the plan:**
- ~50+ resources will be created
- VPC with 6 subnets (3 public, 3 private)
- EKS cluster with managed node group
- IAM roles and security groups
- KMS key for encryption

### Step 5: Deploy Infrastructure

```bash
terraform apply
```

- Type `yes` when prompted
- Deployment takes ~10-15 minutes
- EKS cluster creation is the longest step

**Expected resources created:**
- 1 VPC with 6 subnets
- 1 EKS cluster  
- 1 Managed node group (2 t4g.small instances)
- ~20 IAM roles and policies
- Security groups and networking
- KMS key for encryption

### Step 6: Configure kubectl

```bash
aws eks update-kubeconfig --region us-west-2 --name demo-cluster
```

**Test cluster access:**
```bash
kubectl get nodes
kubectl get pods --all-namespaces
kubectl cluster-info
```

**Expected output:**
```
NAME                                       STATUS   ROLES    AGE   VERSION
ip-10-0-xx-xx.us-west-2.compute.internal   Ready    <none>   5m    v1.33.x
ip-10-0-xx-xx.us-west-2.compute.internal   Ready    <none>   5m    v1.33.x
```

## Optional: Deploy Helm Charts

The infrastructure includes IRSA roles for popular Kubernetes add-ons. Charts are defined but commented out in `charts.tf`.

### External Secrets Operator

**1. Create test secrets in AWS:**
```bash
# Secrets Manager
aws secretsmanager create-secret \
  --name "demo-cluster/app1/database-password" \
  --secret-string "super-secret-password"

# Parameter Store
aws ssm put-parameter \
  --name "/demo-cluster/app1/config" \
  --value "database-host=localhost" \
  --type "SecureString"
```

**2. Enable External Secrets chart:**
Edit `charts.tf` and uncomment the `external_secrets` resource:
```hcl
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

**3. Apply changes:**
```bash
terraform plan
terraform apply
```

**4. Verify deployment:**
```bash
kubectl get pods -n external-secrets
kubectl get sa -n external-secrets
```

### Cert-Manager

**1. Enable cert-manager chart:**
Edit `charts.tf` and uncomment the `cert_manager` resource.

**2. Apply changes:**
```bash
terraform plan
terraform apply
```

**3. Verify deployment:**
```bash
kubectl get pods -n cert-manager
kubectl get crds | grep cert-manager
```

## Verification and Testing

### Cluster Health Check

```bash
# Check node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check add-ons
kubectl get deploy -n kube-system

# Verify IRSA (if external charts deployed)
kubectl describe sa -n external-secrets external-secrets
kubectl describe sa -n cert-manager cert-manager
```

### Networking Test

```bash
# Deploy test pod
kubectl run test-pod --image=nginx --port=80

# Check pod networking
kubectl get pod test-pod -o wide
kubectl exec test-pod -- nslookup kubernetes.default

# Clean up
kubectl delete pod test-pod
```

### Storage Test

```bash
# Create PVC using EBS CSI driver
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: gp2
EOF

# Check PVC status
kubectl get pvc test-pvc

# Clean up
kubectl delete pvc test-pvc
```

## Troubleshooting

### Common Issues

**1. Terraform Init Fails**
- **Error**: Provider download issues
- **Solution**: Check internet connectivity, try `terraform init -upgrade`

**2. AWS Permission Denied**
- **Error**: `AccessDenied` during terraform apply
- **Solution**: Verify IAM permissions, check `aws sts get-caller-identity`

**3. EKS Cluster Creation Timeout**
- **Error**: Cluster stuck in `CREATING` state
- **Solution**: Check AWS service health, verify subnet configuration

**4. kubectl Access Denied**
- **Error**: `error: You must be logged in to the server`
- **Solution**: 
  ```bash
  aws eks update-kubeconfig --region us-west-2 --name demo-cluster
  aws sts get-caller-identity  # Verify AWS credentials
  ```

**5. Nodes Not Ready**
- **Error**: Nodes stuck in `NotReady` state
- **Solution**: Check node group status, verify IAM roles, check VPC DNS settings

**6. Helm Charts Fail to Deploy**
- **Error**: IRSA authentication issues
- **Solution**: Verify OIDC provider, check service account annotations

### Debug Commands

```bash
# Check Terraform state
terraform show
terraform state list

# Check AWS resources
aws eks describe-cluster --name demo-cluster
aws ec2 describe-instances --filters "Name=tag:kubernetes.io/cluster/demo-cluster,Values=owned"

# Check Kubernetes events
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl describe nodes

# Check EKS add-ons
aws eks list-addons --cluster-name demo-cluster
```

### Provider Configuration Issues

**Circular Dependency Error:**
```
Error: Provider configuration not present
```

**Solution:** Ensure all providers are configured at root level in `versions.tf`, not in modules.

**Orphaned Resources:**
```
Error: resource exists in state but not in configuration
```

**Solution:**
```bash
terraform state list | grep <resource-type>
terraform state rm <resource-name>
```

## Cost Management

### Daily Costs (Approximate)

- **EKS Cluster**: $0.10/hour = $2.40/day
- **EC2 Instances**: 2x t4g.small = ~$1.00/day  
- **NAT Gateway**: $1.07/day
- **EBS Volumes**: ~$0.20/day
- **Other**: ~$0.50/day

**Total**: ~$5.17/day

### Cost Optimization

**For extended development:**
1. **Stop nodes when not in use:**
   ```bash
   aws eks update-nodegroup --cluster-name demo-cluster \
     --nodegroup-name demo-node-group --scaling-config minSize=0,maxSize=3,desiredSize=0
   ```

2. **Scale up when needed:**
   ```bash
   aws eks update-nodegroup --cluster-name demo-cluster \
     --nodegroup-name demo-node-group --scaling-config minSize=1,maxSize=3,desiredSize=2
   ```

## Cleanup

### Destroy Infrastructure

**1. Remove Helm charts first (if deployed):**
```bash
# Comment out helm releases in charts.tf
terraform plan
terraform apply
```

**2. Destroy all infrastructure:**
```bash
terraform destroy
```

**3. Verify cleanup:**
```bash
aws eks list-clusters --region us-west-2
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*demo-cluster*"
```

### Manual Cleanup (if needed)

If terraform destroy fails, manually delete:
```bash
# Delete EKS cluster
aws eks delete-cluster --name demo-cluster

# Delete node group first if cluster deletion fails
aws eks delete-nodegroup --cluster-name demo-cluster --nodegroup-name demo-node-group

# Delete VPC resources
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=demo-cluster-vpc"
# Note VPC ID and delete associated resources through AWS console
```

## Next Steps

### Learning Objectives

After completing this setup:

1. **Kubernetes Basics**: Deploy applications, understand pods/services
2. **Storage**: Work with persistent volumes and EBS CSI driver
3. **Networking**: Understand CNI, load balancers, ingress
4. **Security**: Explore RBAC, IRSA, network policies
5. **Monitoring**: Set up logging and monitoring solutions
6. **GitOps**: Integrate with CI/CD pipelines

### Recommended Extensions

1. **Install Kubernetes Dashboard**
2. **Set up Prometheus/Grafana monitoring**
3. **Configure Ingress controllers (AWS ALB)**
4. **Implement GitOps with ArgoCD/Flux**
5. **Set up centralized logging with ELK stack**

### Production Considerations

When adapting for production:

1. **Multi-AZ NAT Gateways**: Update VPC module
2. **Private API endpoint**: Modify EKS configuration
3. **Larger instance types**: Update node group configuration
4. **Network policies**: Implement microsegmentation
5. **Backup strategies**: Set up ETCD and PV backups
6. **Monitoring/Alerting**: Comprehensive observability stack

## Support Resources

- **AWS EKS Documentation**: https://docs.aws.amazon.com/eks/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/
- **Project Issues**: Create GitHub issues for bugs or questions
- **AWS Support**: Consider AWS Support plan for production workloads

---

**Remember**: This infrastructure is designed for training and development. Always follow your organization's security and compliance requirements for production deployments.