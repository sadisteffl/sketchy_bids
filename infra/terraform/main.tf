provider "aws" {
  region = "us-east-1"
}

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.13"
    }
  }
}


data "aws_caller_identity" "current" {}

data "aws_region" "current" {}


data "aws_partition" "current" {}

data "aws_eks_cluster" "sketchy_bids_clusterr" {
  name = aws_eks_cluster.sketchy_bids_cluster.name
}

