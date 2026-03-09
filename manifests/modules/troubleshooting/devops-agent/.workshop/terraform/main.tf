terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.16.0"
    }
  }

  backend "kubernetes" {
    secret_suffix = "devops-agent-state"
    config_path   = "~/.kube/config"
    namespace     = "kube-system"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  tags = merge(var.tags, {
    module = "troubleshooting/devops-agent"
  })

  agent_space_name = "${var.eks_cluster_id}-devops-agent"
  account_id       = data.aws_caller_identity.current.account_id
  endpoint_url     = "https://api.prod.cp.aidevops.us-east-1.api.aws"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# -----------------------------------------------------------------------------
# IAM Role: DevOpsAgentRole-AgentSpace
# Used by the DevOps Agent service for EKS cluster access and SSM commands
# -----------------------------------------------------------------------------
resource "aws_iam_role" "agent_space_role" {
  name = "DevOpsAgentRole-AgentSpace"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "aidevops.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:aidevops:us-east-1:${local.account_id}:agent-space/*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "agent_space_managed_policy" {
  role       = aws_iam_role.agent_space_role.name
  policy_arn = "arn:aws:iam::aws:policy/AIOpsAssistantPolicy"
}

resource "aws_iam_role_policy" "agent_space_ssm" {
  name = "DevOpsAgentSSMPolicy"
  role = aws_iam_role.agent_space_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:${local.account_id}:document/AWS-RunShellScript",
          "arn:aws:ssm:${data.aws_region.current.name}:${local.account_id}:document/AWS-RunPowerShellScript"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand"
        ]
        Resource = "arn:aws:ec2:${data.aws_region.current.name}:${local.account_id}:instance/*"
        Condition = {
          StringEquals = {
            "ssm:resourceTag/type" = "eksworkshop-ide"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetCommandInvocation"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${local.account_id}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "agent_space_expanded" {
  name = "DevOpsAgentExpandedPolicy"
  role = aws_iam_role.agent_space_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aidevops:GetKnowledgeItem",
          "aidevops:ListKnowledgeItems",
          "eks:AccessKubernetesApi",
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Role: DevOpsAgentRole-WebappAdmin
# Used for the operator interface to interact with the DevOps Agent
# -----------------------------------------------------------------------------
resource "aws_iam_role" "webapp_admin_role" {
  name = "DevOpsAgentRole-WebappAdmin"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "aidevops.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:aidevops:us-east-1:${local.account_id}:agent-space/*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "webapp_admin_permissions" {
  name = "DevOpsAgentWebappAdminPolicy"
  role = aws_iam_role.webapp_admin_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aidevops:GetAgentSpace",
          "aidevops:InvokeAgent",
          "aidevops:CreateChat",
          "aidevops:StreamMessage",
          "aidevops:ListChats",
          "aidevops:GetChat",
          "aidevops:DeleteChat"
        ]
        Resource = "arn:aws:aidevops:us-east-1:${local.account_id}:agent-space/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# EKS Access Entry for DevOps Agent
# Grants the AgentSpace role access to the EKS cluster Kubernetes API
# -----------------------------------------------------------------------------
resource "aws_eks_access_entry" "devops_agent" {
  cluster_name  = var.eks_cluster_id
  principal_arn = aws_iam_role.agent_space_role.arn
  type          = "STANDARD"
  tags          = var.tags
}

resource "aws_eks_access_policy_association" "devops_agent" {
  cluster_name  = var.eks_cluster_id
  principal_arn = aws_iam_role.agent_space_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# -----------------------------------------------------------------------------
# DevOps Agent API calls via null_resource + local-exec
# No native Terraform provider exists yet for DevOps Agent
# -----------------------------------------------------------------------------
resource "null_resource" "create_agent_space" {
  triggers = {
    agent_space_name = local.agent_space_name
    account_id       = local.account_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws devopsagent create-agent-space \
        --agent-space-name "${local.agent_space_name}" \
        --endpoint-url "${local.endpoint_url}" \
        --region us-east-1 || true
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws devopsagent delete-agent-space \
        --agent-space-name "${self.triggers.agent_space_name}" \
        --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
        --region us-east-1 || true
    EOT
  }
}

resource "null_resource" "associate_service" {
  triggers = {
    agent_space_name = local.agent_space_name
    cluster_name     = var.eks_cluster_id
    agent_role_arn   = aws_iam_role.agent_space_role.arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws devopsagent associate-service \
        --agent-space-name "${local.agent_space_name}" \
        --service-type EKS \
        --service-identifier "${var.eks_cluster_id}" \
        --monitoring-role-arn "${aws_iam_role.agent_space_role.arn}" \
        --endpoint-url "${local.endpoint_url}" \
        --region us-east-1 || true
    EOT
  }

  depends_on = [
    null_resource.create_agent_space,
    aws_iam_role.agent_space_role,
    aws_eks_access_entry.devops_agent,
    aws_eks_access_policy_association.devops_agent
  ]
}

resource "null_resource" "enable_operator_app" {
  triggers = {
    agent_space_name   = local.agent_space_name
    webapp_role_arn    = aws_iam_role.webapp_admin_role.arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws devopsagent enable-operator-app \
        --agent-space-name "${local.agent_space_name}" \
        --operator-role-arn "${aws_iam_role.webapp_admin_role.arn}" \
        --endpoint-url "${local.endpoint_url}" \
        --region us-east-1 || true
    EOT
  }

  depends_on = [
    null_resource.create_agent_space,
    aws_iam_role.webapp_admin_role
  ]
}
