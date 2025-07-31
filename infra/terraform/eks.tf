resource "aws_iam_role" "sketchy_bids_eks_cluster_role" {
  name = "sketchy_bids_eks_cluster_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sketchy_bids_eks_cluster_policy" {
  role       = aws_iam_role.sketchy_bids_eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "sketchy_bids_eks_service_policy" {
  role       = aws_iam_role.sketchy_bids_eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_eks_cluster" "sketchy_bids_cluster" {
  name    = "sketchy-bids-cluster"
  version = "1.29"

  role_arn = aws_iam_role.sketchy_bids_eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private_az1.id,
      aws_subnet.private_az2.id,
      aws_subnet.public_az1.id,
      aws_subnet.public_az2.id
    ]
    endpoint_public_access  = false
    endpoint_private_access = true
  }
  encryption_config {
    provider {
      key_arn = aws_kms_key.mainkey.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
}

resource "aws_iam_role" "sketchy_bids_eks_node_role" {
  name = "sketchy-bids-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.sketchy_bids_eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.sketchy_bids_eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_only_policy" {
  role       = aws_iam_role.sketchy_bids_eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_node_group" "sketchy_bids_nodes" {
  cluster_name    = aws_eks_cluster.sketchy_bids_cluster.name
  node_group_name = "sketchy_bids_nodes"
  node_role_arn   = aws_iam_role.sketchy_bids_eks_node_role.arn
  subnet_ids      = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]

  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  ami_type      = "AL2023_x86_64_STANDARD"
  capacity_type = "ON_DEMAND"


  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only_policy
  ]
}

resource "aws_iam_role" "csi_secrets_store_role" {
  name               = "csi-secrets-store-role"
  assume_role_policy = data.aws_iam_policy_document.csi_driver_trust_policy.json
}

data "aws_iam_policy_document" "csi_driver_trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:csi-secrets-store-provider-aws"]
    }
  }
}