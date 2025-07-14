############################################################################################################
### OIDC CONFIGURATION
############################################################################################################

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}


# Example External OIDC Provider Example
# resource "aws_eks_identity_provider_config" "external" {
#   cluster_name = aws_eks_cluster.main.name
#   oidc {
#     identity_provider_config_name = "external-oidc"
#     client_id                    = "your-external-client-id"
#     issuer_url                   = "https://your-external-provider.com"  # Different from EKS issuer
#     username_claim               = "email"
#     groups_claim                 = "groups"
#   }
# }

resource "aws_iam_role" "cni_irsa" {
  name = "${var.cluster_name}-cni-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:kube-system:aws-node"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-cni-irsa"
    Component   = "vpc-cni"
    ServiceType = "addon"
  }
}

resource "aws_iam_role_policy_attachment" "cni_irsa_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.cni_irsa.name
}

# EBS CSI Driver IRSA Role
resource "aws_iam_role" "ebs_csi_irsa" {
  name = "${var.cluster_name}-ebs-csi-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-irsa"
    Component   = "ebs-csi-driver"
    ServiceType = "addon"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_irsa_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_irsa.name
}

# CoreDNS IRSA Role
resource "aws_iam_role" "coredns_irsa" {
  name = "${var.cluster_name}-coredns-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:kube-system:coredns"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-coredns-irsa"
    Component   = "coredns"
    ServiceType = "addon"
  }
}

# Kube Proxy IRSA Role
resource "aws_iam_role" "kube_proxy_irsa" {
  name = "${var.cluster_name}-kube-proxy-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:kube-system:kube-proxy"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-kube-proxy-irsa"
    Component   = "kube-proxy"
    ServiceType = "addon"
  }
}

# Secrets Store CSI Driver IRSA Role
resource "aws_iam_role" "secrets_csi_irsa" {
  name = "${var.cluster_name}-secrets-csi-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:kube-system:secrets-store-csi-driver"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-secrets-csi-irsa"
    Component   = "secrets-store-csi-driver"
    ServiceType = "csi-driver"
  }
}

# IAM Policy for Secrets Store CSI Driver (Read-Only)
resource "aws_iam_policy" "secrets_csi_policy" {
  name        = "${var.cluster_name}-secrets-csi-policy"
  description = "Read-only policy for Secrets Store CSI Driver to access AWS secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/*",
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}-*",
          "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.cluster_name}/*",
          "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.cluster_name}-*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-secrets-csi-policy"
    Component   = "secrets-store-csi-driver"
    ServiceType = "csi-driver"
  }
}

resource "aws_iam_role_policy_attachment" "secrets_csi_irsa_policy" {
  policy_arn = aws_iam_policy.secrets_csi_policy.arn
  role       = aws_iam_role.secrets_csi_irsa.name
}

# IAM Role for cert-manager with IRSA
resource "aws_iam_role" "cert_manager" {
  name = "${var.cluster_name}-cert-manager-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:cert-manager:cert-manager"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-cert-manager-irsa"
    Component   = "cert-manager"
    ServiceType = "certificate-management"
  }
}

# IAM Policy for cert-manager
resource "aws_iam_policy" "cert_manager" {
  name        = "${var.cluster_name}-cert-manager-policy"
  description = "Policy for cert-manager to manage ACM certificates"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "acm:RequestCertificate",
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "acm:AddTagsToCertificate"
        ]
        Resource = "*"
      },
      {
        # Only allow deletion of certificates tagged with this cluster
        Effect = "Allow"
        Action = [
          "acm:DeleteCertificate"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange",
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = concat([
          "arn:aws:route53:::change/*"
          ], [
          for zone_id in local.all_zone_ids :
          "arn:aws:route53:::hostedzone/${zone_id}"
        ])
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cert_manager_isra_policy" {
  role       = aws_iam_role.cert_manager.name
  policy_arn = aws_iam_policy.cert_manager.arn
}
