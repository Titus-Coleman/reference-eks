output "cluster" {
  description = "The EKS cluster resource block"
  value       = aws_eks_cluster.main
}

output "cluster_id" {
  description = "The EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster API"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "The security group ID of the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].security_group_ids
}

output "node_group_role_arn" {
  description = "The ARN of the IAM role used by the node group"
  value       = aws_iam_role.node_role.arn
}

output "cluster_admins_arn" {
  description = "The ARN of the role for EKS cluster admins"
  value       = aws_iam_role.eks_admins_role.arn
}

output "cluster_certificate_authority_data" {
  description = "The base64 encoded certificate data required to communicate with the cluster"
  value       = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
}

output "cluster_auth_token" {
  description = "The token required to authenticate with the cluster"
  value       = data.aws_eks_cluster_auth.main.token
}

output "oidc_provider_arn" {
  description = "The OIDC ARN of the Cluster"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_id" {
  description = "The OIDC ID of the Cluster"
  value       = aws_iam_openid_connect_provider.eks.id
}

output "admin_access_entry_arn" {
  description = "ARN of the admin role access entry"
  value       = aws_eks_access_entry.admin_role.access_entry_arn
}

output "admin_policy_association" {
  description = "Admin policy association details"
  value = {
    policy_arn = aws_eks_access_policy_association.admin_policy.policy_arn
    access_scope_type = aws_eks_access_policy_association.admin_policy.access_scope[0].type
  }
}

output "cluster_creator_policy_association" {
  description = "Cluster creator policy association details"
  value = {
    policy_arn = aws_eks_access_policy_association.cluster_creator_policy.policy_arn
    access_scope_type = aws_eks_access_policy_association.cluster_creator_policy.access_scope[0].type
  }
}

output "secrets_csi_irsa_role_arn" {
  description = "ARN of the Secrets Store CSI Driver IRSA role"
  value       = aws_iam_role.secrets_csi_irsa.arn
}

output "secrets_csi_policy_arn" {
  description = "ARN of the Secrets Store CSI Driver IAM policy"
  value       = aws_iam_policy.secrets_csi_policy.arn
}
