# # Helm releases managed at root level with proper provider configuration

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  # Cleanup and timeout configurations for graceful destroy
  cleanup_on_fail = true
  force_update    = true
  timeout         = 600 # 10 minutes for operations

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.secrets_csi_irsa_role_arn
  }

  # Ensure proper dependency order for graceful destroy
  depends_on = [
    module.eks
  ]


  # Lifecycle management for graceful operations
  lifecycle {
    create_before_destroy = false
  }
}

# AWS Load Balancer Controller Helm Release
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system" # Standard namespace for AWS Load Balancer Controller
  #version    = "1.8.1" # Latest version compatible with Kubernetes 1.33

  # Cleanup and timeout configurations for graceful destroy
  cleanup_on_fail = true
  force_update    = true
  wait            = true
  wait_for_jobs   = true
  timeout         = 600

  # Values equivalent to your helm install command
  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = module.eks.load_balancer_controller_irsa_name
  }

  set {
    name  = "enableServiceMutatorWebhook"
    value = "false"
  }


  # Ensure proper dependency order for graceful destroy
  depends_on = [
    module.eks
  ]

  # Lifecycle management for graceful operations
  lifecycle {
    create_before_destroy = false
  }
}
