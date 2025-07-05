module "vpc" {
  source = "./modules/aws/vpc"

  vpc_name             = "${var.cluster_name}-vpc"
  cidr_block           = "10.0.0.0/16"
  nat_gateway          = true
  enable_dns_support   = true
  enable_dns_hostnames = true

  public_subnet_count  = 3
  private_subnet_count = 3
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

# resource "aws_security_group" "eks_cluster_sg" {
#   name        = "${var.cluster_name}-eks-cluster-sg"
#   description = "Security group for EKS cluster control plane communication with worker nodes"
#   vpc_id      = module.vpc.vpc_id
#   tags = {
#     Name = "${var.cluster_name}-eks-cluster-sg"
#   }
# }

# resource "aws_security_group" "eks_nodes_sg" {
#   name        = "${var.cluster_name}-eks-nodes-sg"
#   description = "Security group for all nodes in the cluster"
#   vpc_id      = module.vpc.vpc_id
#   tags = {
#     Name                                        = "${var.cluster_name}-eks-nodes-sg"
#     "kubernetes.io/cluster/${var.cluster_name}" = "owned"
#   }
# }


# resource "aws_security_group_rule" "eks_cluster_ingress_nodes" {
#   type                     = "ingress"
#   from_port                = 443
#   to_port                  = 443
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.eks_cluster_sg.id
#   source_security_group_id = aws_security_group.eks_nodes_sg.id
#   description              = "Allow inbound traffic from the worker nodes on the Kubernetes API endpoint port"
# }

# resource "aws_security_group_rule" "eks_cluster_egress_kublet" {
#   type                     = "egress"
#   from_port                = 10250
#   to_port                  = 10250
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.eks_cluster_sg.id
#   source_security_group_id = aws_security_group.eks_nodes_sg.id
#   description              = "Allow control plane to node egress for kubelet"
# }

# resource "aws_security_group_rule" "worker_node_ingress_kublet" {
#   type                     = "ingress"
#   from_port                = 10250
#   to_port                  = 10250
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.eks_nodes_sg.id
#   source_security_group_id = aws_security_group.eks_cluster_sg.id
#   description              = "Allow control plane to node ingress for kubelet"
# }

# resource "aws_security_group_rule" "worker_node_to_worker_node_ingress_ephemeral" {
#   type              = "ingress"
#   from_port         = 1025
#   to_port           = 65535
#   protocol          = "tcp"
#   self              = true
#   security_group_id = aws_security_group.eks_nodes_sg.id
#   description       = "Allow workers nodes to communicate with each other on ephemeral ports"
# }

# resource "aws_security_group_rule" "worker_node_egress_internet" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.eks_nodes_sg.id
#   description       = "Allow outbound internet access"
# }

# resource "aws_security_group_rule" "worker_node_to_worker_node_ingress_coredns_tcp" {
#   type              = "ingress"
#   from_port         = 53
#   to_port           = 53
#   protocol          = "tcp"
#   security_group_id = aws_security_group.eks_nodes_sg.id
#   self              = true
#   description       = "Allow workers nodes to communicate with each other for coredns TCP"
# }

# resource "aws_security_group_rule" "worker_node_to_worker_node_ingress_coredns_udp" {
#   type              = "ingress"
#   from_port         = 53
#   to_port           = 53
#   protocol          = "udp"
#   security_group_id = aws_security_group.eks_nodes_sg.id
#   self              = true
#   description       = "Allow workers nodes to communicate with each other for coredns UDP"
# }

