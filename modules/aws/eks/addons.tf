############################################################################################################
# PLUGINS
############################################################################################################
data "aws_eks_addon_version" "latest" {
  for_each = toset(var.cluster_addons)

  addon_name         = each.key
  kubernetes_version = aws_eks_cluster.main.version
}

resource "aws_eks_addon" "main" {
  for_each = toset(var.cluster_addons)

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = each.key
  addon_version               = data.aws_eks_addon_version.latest[each.key].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on = [
    aws_eks_node_group.main
  ]
}

# resource "aws_eks_addon" "vpc_cni" {
#   for_each = toset(var.cluster_addons)

#   cluster_name                = aws_eks_cluster.main.name
#   addon_name                  = each.key
#   addon_version               = data.aws_eks_addon_version.latest[each.key].version
#   resolve_conflicts_on_create = "OVERWRITE"
#   resolve_conflicts_on_update = "OVERWRITE"
#   depends_on = [
#     aws_eks_node_group.main
#   ]
# }


# resource "aws_eks_addon" "aws-ebs-csi-driver" {
#   for_each = toset(var.cluster_addons)

#   cluster_name                = aws_eks_cluster.main.name
#   addon_name                  = each.key
#   addon_version               = data.aws_eks_addon_version.latest[each.key].version
#   resolve_conflicts_on_create = "OVERWRITE"
#   resolve_conflicts_on_update = "OVERWRITE"
#   depends_on = [
#     aws_eks_node_group.main
#   ]
# }
