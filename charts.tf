# Helm releases managed at root level with proper provider configuration

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  # Cleanup and timeout configurations for graceful destroy
  cleanup_on_fail = true
  force_update    = true
  timeout         = 600  # 10 minutes for operations

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

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  # Cleanup and timeout configurations for graceful destroy
  cleanup_on_fail = true
  force_update    = true
  timeout         = 600  # 10 minutes for operations

  values = [
    yamlencode({
      crds = {
        enabled = true
      }
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.eks.cert_manager_irsa_role_arn
        }
      }
      # Increase to 2+ in prod
      replicaCount = 1
      
      # Enhanced cleanup configuration for cert-manager
      webhook = {
        timeoutSeconds = 30
      }
      global = {
        leaderElection = {
          namespace = "cert-manager"
        }
      }
    })
  ]

  # Ensure proper dependency order for graceful destroy
  depends_on = [
    module.eks
  ]


  # Lifecycle management for graceful operations
  lifecycle {
    create_before_destroy = false
  }
}