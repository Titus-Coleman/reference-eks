# resource "helm_release" "external_secrets_crd" {
#   name             = "external-secrets"
#   repository       = "https://charts.external-secrets.io"
#   chart            = "external-secrets"
#   namespace        = "external-secrets"
#   create_namespace = true

#   set {
#     name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = aws_iam_role.secrets_csi_irsa.arn
#   }

# }

# resource "helm_release" "cert-manager" {
#   name             = "cert-manager"
#   repository       = "https://charts.jetstack.io"
#   chart            = "cert-manager"
#   namespace        = "cert-manager"
#   create_namespace = true

#   values = [
#     yamlencode({
#       crds = {
#         enabled = true
#       }
#       serviceAccount = {
#         annotations = {
#           "eks.amazonaws.com/role-arn" = aws_iam_role.cert_manager.arn
#         }
#       }
#       #Increase to 2+ in prod
#       replicaCount = 1
#     })
#   ]
# }
