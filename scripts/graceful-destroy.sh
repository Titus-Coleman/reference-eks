#!/bin/bash

# Graceful Terraform Destroy Script for EKS Training Infrastructure
# This script ensures proper cleanup order and validates destruction

set -e

CLUSTER_NAME=${1:-"demo-cluster"}
REGION=${2:-"us-west-2"}

echo "🚀 Starting graceful destroy process for cluster: $CLUSTER_NAME"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
  print_status "Checking prerequisites..."
  
  if ! command -v terraform &> /dev/null; then
    print_error "Terraform not found. Please install Terraform."
    exit 1
  fi
  
  if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl."
    exit 1
  fi
  
  if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not found. Please install AWS CLI."
    exit 1
  fi
  
  if ! command -v helm &> /dev/null; then
    print_warning "Helm not found. Skipping Helm checks."
  fi
  
  print_success "Prerequisites check completed"
}

# Check if cluster exists and is accessible
check_cluster_access() {
  print_status "Checking cluster access..."
  
  if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" &> /dev/null; then
    print_success "Cluster $CLUSTER_NAME exists"
    
    # Try to access cluster
    if kubectl get nodes &> /dev/null; then
      print_success "Cluster is accessible via kubectl"
      return 0
    else
      print_warning "Cluster exists but kubectl access failed. Continuing with destroy..."
      return 1
    fi
  else
    print_warning "Cluster $CLUSTER_NAME does not exist or is not accessible"
    return 1
  fi
}

# Check for external AWS resources that might block destroy
check_external_resources() {
  print_status "Checking for external AWS resources..."
  
  # Check for LoadBalancers
  local lb_count
  lb_count=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '$CLUSTER_NAME') || contains(Tags[?Key=='kubernetes.io/cluster/$CLUSTER_NAME'].Value, 'owned')].LoadBalancerArn" --output text --region "$REGION" | wc -l)
  
  if [ "$lb_count" -gt 0 ]; then
    print_warning "Found $lb_count LoadBalancer(s) that may be managed by Kubernetes services"
    print_warning "These may need manual cleanup if destroy fails"
  fi
  
  # Check for unmanaged EBS volumes
  local ebs_count
  ebs_count=$(aws ec2 describe-volumes --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" --query 'Volumes[?State==`available`].VolumeId' --output text --region "$REGION" | wc -w)
  
  if [ "$ebs_count" -gt 0 ]; then
    print_warning "Found $ebs_count EBS volume(s) tagged with cluster name"
  fi
  
  print_success "External resource check completed"
}

# Pre-destroy cleanup
pre_destroy_cleanup() {
  print_status "Performing pre-destroy cleanup..."
  
  if kubectl get nodes &> /dev/null; then
    # Remove services with LoadBalancer type
    print_status "Checking for LoadBalancer services..."
    local lb_services
    lb_services=$(kubectl get svc --all-namespaces -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null || echo "")
    
    if [ -n "$lb_services" ]; then
      print_warning "Found LoadBalancer services that will be cleaned up by Terraform destroy"
      echo "$lb_services"
    fi
    
    # Check for PersistentVolumes
    print_status "Checking for PersistentVolumes..."
    local pv_count
    pv_count=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
    
    if [ "$pv_count" -gt 0 ]; then
      print_warning "Found $pv_count PersistentVolume(s) - these should be cleaned up by Terraform"
    fi
  else
    print_warning "Cannot access cluster for pre-destroy cleanup. Proceeding with Terraform destroy."
  fi
  
  print_success "Pre-destroy cleanup completed"
}

# Run terraform destroy
run_terraform_destroy() {
  print_status "Running Terraform destroy..."
  print_warning "This will destroy ALL infrastructure including:"
  print_warning "- EKS Cluster: $CLUSTER_NAME"
  print_warning "- All associated AWS resources (VPC, EC2, IAM, etc.)"
  print_warning "- Any deployed Helm charts"
  
  echo
  read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
  
  if [ "$confirm" != "yes" ]; then
    print_error "Destroy cancelled by user"
    exit 1
  fi
  
  echo
  print_status "Starting Terraform destroy process..."
  
  # Run terraform destroy with auto-approve for automation, or interactive for safety
  if [ "${AUTO_APPROVE:-false}" = "true" ]; then
    terraform destroy -auto-approve
  else
    terraform destroy
  fi
  
  local destroy_exit_code=$?
  
  if [ $destroy_exit_code -eq 0 ]; then
    print_success "Terraform destroy completed successfully"
  else
    print_error "Terraform destroy failed with exit code $destroy_exit_code"
    return $destroy_exit_code
  fi
}

# Post-destroy verification
post_destroy_verification() {
  print_status "Performing post-destroy verification..."
  
  # Check if cluster still exists
  if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" &> /dev/null; then
    print_error "Cluster $CLUSTER_NAME still exists after destroy!"
    return 1
  else
    print_success "Cluster $CLUSTER_NAME successfully destroyed"
  fi
  
  # Check for leftover VPC
  local vpc_id
  vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$CLUSTER_NAME-vpc" --query 'Vpcs[0].VpcId' --output text --region "$REGION" 2>/dev/null)
  
  if [ "$vpc_id" != "None" ] && [ "$vpc_id" != "" ]; then
    print_error "VPC $vpc_id still exists after destroy!"
    return 1
  else
    print_success "VPC successfully destroyed"
  fi
  
  # Check terraform state
  local state_resources
  state_resources=$(terraform state list 2>/dev/null | wc -l)
  
  if [ "$state_resources" -gt 0 ]; then
    print_warning "Terraform state still contains $state_resources resources"
    print_status "Remaining resources:"
    terraform state list
  else
    print_success "Terraform state is clean"
  fi
  
  print_success "Post-destroy verification completed"
}

# Manual cleanup function (if needed)
manual_cleanup() {
  print_status "Manual cleanup options:"
  echo
  echo "If destroy failed or left resources behind, try these commands:"
  echo
  echo "1. Clean up LoadBalancers:"
  echo "   aws elbv2 describe-load-balancers --query \"LoadBalancers[?contains(Tags[?Key=='kubernetes.io/cluster/$CLUSTER_NAME'].Value, 'owned')].LoadBalancerArn\" --output text | xargs -I {} aws elbv2 delete-load-balancer --load-balancer-arn {}"
  echo
  echo "2. Clean up EBS volumes:"
  echo "   aws ec2 describe-volumes --filters \"Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned\" --query 'Volumes[].VolumeId' --output text | xargs -I {} aws ec2 delete-volume --volume-id {}"
  echo
  echo "3. Clean up Terraform state:"
  echo "   terraform state list | xargs -I {} terraform state rm {}"
  echo
  echo "4. Force cluster deletion:"
  echo "   aws eks delete-cluster --name $CLUSTER_NAME --region $REGION"
}

# Main execution
main() {
  echo "EKS Training Infrastructure - Graceful Destroy"
  echo "=============================================="
  echo "Cluster: $CLUSTER_NAME"
  echo "Region: $REGION"
  echo
  
  check_prerequisites
  echo
  
  local cluster_accessible=false
  if check_cluster_access; then
    cluster_accessible=true
  fi
  echo
  
  check_external_resources
  echo
  
  if [ "$cluster_accessible" = true ]; then
    pre_destroy_cleanup
    echo
  fi
  
  if run_terraform_destroy; then
    echo
    post_destroy_verification
    echo
    print_success "🎉 Graceful destroy process completed successfully!"
  else
    echo
    print_error "❌ Destroy process failed!"
    manual_cleanup
    exit 1
  fi
}

# Show usage if help requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: $0 [CLUSTER_NAME] [REGION]"
  echo
  echo "Options:"
  echo "  CLUSTER_NAME  Name of the EKS cluster (default: demo-cluster)"
  echo "  REGION        AWS region (default: us-west-2)"
  echo
  echo "Environment Variables:"
  echo "  AUTO_APPROVE  Set to 'true' to skip confirmation prompts"
  echo
  echo "Examples:"
  echo "  $0                           # Use defaults"
  echo "  $0 my-cluster us-east-1      # Custom cluster and region"
  echo "  AUTO_APPROVE=true $0         # Skip confirmations"
  exit 0
fi

# Run main function
main "$@"