data "aws_partition" "current" {}

# Fetch current AWS account details
data "aws_caller_identity" "current" {}

provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

############################################################################################################
### EKS CLUSTER
############################################################################################################
resource "aws_eks_cluster" "main" {
  name                      = var.cluster_name
  role_arn                  = aws_iam_role.eks_cluster_role.arn
  enabled_cluster_log_types = var.enabled_cluster_log_types

  vpc_config {
    subnet_ids             = concat(var.private_subnets, var.public_subnets)
    security_group_ids     = [aws_security_group.eks_cluster_sg.id]
    endpoint_public_access = true

  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_encryption.arn
    }
    resources = ["secrets"]
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}

data "aws_eks_cluster_auth" "main" {
  name = var.cluster_name
}

############################################################################################################
### KMS KEY
############################################################################################################
resource "aws_kms_key" "eks_encryption" {
  description         = "KMS key for EKS cluster encryption"
  policy              = data.aws_iam_policy_document.kms_key_policy.json
  enable_key_rotation = true
}

# alias
resource "aws_kms_alias" "eks_encryption" {
  name          = "alias/eks/${var.cluster_name}"
  target_key_id = aws_kms_key.eks_encryption.id
}

data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid = "Key Administrators"
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:TagResource"
    ]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
        data.aws_caller_identity.current.arn
      ]
    }
    resources = ["*"]
  }

  statement {
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    resources = ["*"]
  }
}


resource "aws_iam_policy" "cluster_encryption" {
  name        = "${var.cluster_name}-encryption-policy"
  description = "IAM policy for EKS cluster encryption"
  policy      = data.aws_iam_policy_document.cluster_encryption.json
}

data "aws_iam_policy_document" "cluster_encryption" {
  statement {
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ListGrants",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.eks_encryption.arn]
  }
}

# Granting the EKS Cluster role the ability to use the KMS key
resource "aws_iam_role_policy_attachment" "cluster_encryption" {
  policy_arn = aws_iam_policy.cluster_encryption.arn
  role       = aws_iam_role.eks_cluster_role.name
}

############################################################################################################
### MANAGED NODE GROUPS
############################################################################################################
resource "aws_eks_node_group" "main" {
  for_each = var.managed_node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = each.value.name
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = var.private_subnets

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  launch_template {
    id      = aws_launch_template.eks_node_group.id
    version = "$Latest"
  }

  instance_types       = each.value.instance_types
  ami_type             = var.default_ami_type
  capacity_type        = var.default_capacity_type
  force_update_version = true
}

############################################################################################################
### LAUNCH TEMPLATE
############################################################################################################  
resource "aws_launch_template" "eks_node_group" {
  name_prefix = "${var.cluster_name}-eks-node-group-lt"
  description = "Launch template for ${var.cluster_name} EKS node group"

  vpc_security_group_ids = [aws_security_group.eks_nodes_sg.id]

  # key_name = "terraform"

  tag_specifications {
    resource_type = "instance"
    tags = {
      "Name" = "${var.cluster_name}-eks-node-group"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda" # Adjusted to the common root device name for Linux AMIs

    ebs {
      volume_size           = 20    # Disk size specified here
      volume_type           = "gp3" # Example volume type, adjust as necessary
      delete_on_termination = true
    }
  }

  tags = {
    "Name"                                      = "${var.cluster_name}-eks-node-group"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  lifecycle {
    create_before_destroy = true
  }
}





############################################################################################################
### IAM ROLES
############################################################################################################
# EKS Cluster role
resource "aws_iam_role" "eks_cluster_role" {
  name               = "${var.cluster_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json
}

data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# EKS Cluster Policies
resource "aws_iam_role_policy_attachment" "eks_cloudwatch_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}

# # Managed Node Group role
resource "aws_iam_instance_profile" "eks_node" {
  name = "${var.cluster_name}-node-role"
  role = aws_iam_role.node_role.name
}

resource "aws_iam_role" "node_role" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Node Group Policies
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}




############################################################################################################
### CLUSTER ROLE BASE ACCESS CONTROL
############################################################################################################
# Define IAM Role for EKS Administrators
resource "aws_iam_role" "eks_admins_role" {
  name = "${var.cluster_name}-eks-admins-role"

  assume_role_policy = data.aws_iam_policy_document.eks_admins_assume_role_policy_doc.json
}

# IAM Policy Document for assuming the eks-admins role
data "aws_iam_policy_document" "eks_admins_assume_role_policy_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    effect = "Allow"
  }
}

# Define IAM Policy for administrative actions on EKS
data "aws_iam_policy_document" "eks_admin_policy_doc" {
  statement {
    actions   = ["eks:*", "ec2:Describe*", "iam:ListRoles", "iam:ListRolePolicies", "iam:GetRole"]
    resources = ["*"]
  }
}

# Create IAM Policy based on the above document
resource "aws_iam_policy" "eks_admin_policy" {
  name   = "${var.cluster_name}-eks-admin-policy"
  policy = data.aws_iam_policy_document.eks_admin_policy_doc.json
}

# Attach IAM Policy to the EKS Administrators Role
resource "aws_iam_role_policy_attachment" "eks_admin_role_policy_attach" {
  role       = aws_iam_role.eks_admins_role.name
  policy_arn = aws_iam_policy.eks_admin_policy.arn
}

# EKS Access Entries (API Mode)
resource "aws_eks_access_entry" "admin_role" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.eks_admins_role.arn
  type          = "STANDARD"
  
  tags = {
    Name = "${var.cluster_name}-admin-access-entry"
  }
}

# Access Policy Association for Admin Role
resource "aws_eks_access_policy_association" "admin_policy" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.eks_admins_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  
  access_scope {
    type = "cluster"
  }
}

# Access Policy Association for Cluster Creator (automatically created by bootstrap)
resource "aws_eks_access_policy_association" "cluster_creator_policy" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  
  access_scope {
    type = "cluster"
  }
}


