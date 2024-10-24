terraform {
  required_providers {
    #    kubectl = {
    #      source  = "gavinbunney/kubectl"
    #      version = ">= 1.14"
    #    }
  }
}

provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

data "aws_caller_identity" "current" {}

locals {
    account_id = data.aws_caller_identity.current.account_id
}

data "aws_vpc" "selected" {
  tags = {
    created-by = "eks-workshop-v2"
    env        = var.addon_context.eks_cluster_id
  }
}

data "aws_subnets" "public" {
  tags = {
    created-by = "eks-workshop-v2"
    env        = var.addon_context.eks_cluster_id
  }

  filter {
    name   = "tag:Name"
    values = ["*Public*"]
  }
}

data "aws_region" "current" {}

data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_id
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.2"

  enable_aws_efs_csi_driver = true
  aws_efs_csi_driver = {
    wait = true
  }

  cluster_name      = var.addon_context.eks_cluster_id
  cluster_endpoint  = var.addon_context.aws_eks_cluster_endpoint
  cluster_version   = var.eks_cluster_version
  oidc_provider_arn = var.addon_context.eks_oidc_provider_arn
}


resource "aws_efs_file_system" "efs" {
  tags = {
    Name = "eks-workshop-efs"
  }  
}

resource "aws_efs_mount_target" "mount_targets" {
  for_each = toset(data.aws_subnets.public.ids)
  file_system_id = resource.aws_efs_file_system.efs.id
  subnet_id = each.value
  security_groups = [resource.aws_security_group.efs_sg.id]
}

resource "aws_security_group" "efs_sg" {
  name        = "efs_sg"
  description = "Allow tarffic to efs"
  vpc_id      = data.aws_vpc.selected.id

  tags = {
    Name = "efs_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ipv4" {
  security_group_id = aws_security_group.efs_sg.id
  cidr_ipv4         = data.aws_vpc.selected.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}


resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.efs_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

data "template_file" "deployment_yaml" {
  template = file("/home/ec2-user/environment/eks-workshop/modules/troubleshooting/pod/crash/.workshop/terraform/deployment.yaml.tpl")

  vars = {
    filesystemid = "${resource.aws_efs_file_system.efs.id}"
  }
}

resource "local_file" "deployment_yaml" {
  filename = "/home/ec2-user/environment/eks-workshop/modules/troubleshooting/pod/crash/deployment.yaml"
  content = data.template_file.deployment_yaml.rendered
}

resource "null_resource" "kustomize_app" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ~/environment/eks-workshop/modules/troubleshooting/pod/crash/"
    when    = create
  }

  depends_on = [resource.local_file.deployment_yaml, resource.aws_efs_file_system.efs]
}