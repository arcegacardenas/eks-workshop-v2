# -----------------------------------------------------------------------------
# DevOps Agent Setup Module (Educational)
#
# This module patches the AWS CLI and cleans up any stale Agent Space
# from previous runs so the learner can create a fresh one.
# It also creates the IAM roles and EKS access entry needed for the
# manual walkthrough.
# -----------------------------------------------------------------------------

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

# Patch the AWS CLI with the DevOps Agent service model
resource "null_resource" "patch_cli" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -s -o /tmp/devopsagent.json https://d1co8nkiwcta1g.cloudfront.net/devopsagent.json
      aws configure add-model --service-model "file:///tmp/devopsagent.json" --service-name devopsagent
    EOT
  }
}

# Clean up any stale Agent Space from previous runs
resource "null_resource" "cleanup_stale_agent_space" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      SPACE_ID=$(aws devopsagent list-agent-spaces \
        --endpoint-url "${local.endpoint_url}" \
        --region us-east-1 \
        --query "agentSpaces[?name=='${local.agent_space_name}'].agentSpaceId" \
        --output text 2>/dev/null) || true

      if [ -n "$SPACE_ID" ] && [ "$SPACE_ID" != "None" ]; then
        echo "Deleting stale Agent Space: $SPACE_ID"
        aws devopsagent delete-agent-space \
          --agent-space-id "$SPACE_ID" \
          --endpoint-url "${local.endpoint_url}" \
          --region us-east-1 2>/dev/null || true
      fi
    EOT
  }

  depends_on = [null_resource.patch_cli]
}

# -----------------------------------------------------------------------------
# IAM Role: DevOpsAgentRole-AgentSpace
# Created here so the learner can reference it during the manual walkthrough
# -----------------------------------------------------------------------------
resource "aws_iam_role" "agent_space_role" {
  name = "DevOpsAgentRole-AgentSpace"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "aidevops.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:aidevops:us-east-1:${local.account_id}:agentspace/*" }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "agent_space_managed" {
  role       = aws_iam_role.agent_space_role.name
  policy_arn = "arn:aws:iam::aws:policy/AIOpsAssistantPolicy"
}

resource "aws_iam_role_policy" "agent_space_expanded" {
  name = "DevOpsAgentExpandedPolicy"
  role = aws_iam_role.agent_space_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EKSAndAIDevOps"
        Effect   = "Allow"
        Action   = ["aidevops:GetKnowledgeItem", "aidevops:ListKnowledgeItems", "eks:AccessKubernetesApi", "eks:DescribeCluster", "eks:ListClusters"]
        Resource = "*"
      },
      {
        Sid      = "SSMDocuments"
        Effect   = "Allow"
        Action   = ["ssm:SendCommand", "ssm:GetCommandInvocation"]
        Resource = ["arn:aws:ssm:${data.aws_region.current.name}:${local.account_id}:document/AWS-RunShellScript", "arn:aws:ssm:${data.aws_region.current.name}:${local.account_id}:document/AWS-RunPowerShellScript"]
      },
      {
        Sid      = "SSMInstances"
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = ["arn:aws:ec2:${data.aws_region.current.name}:${local.account_id}:instance/*", "arn:aws:ssm:${data.aws_region.current.name}:${local.account_id}:managed-instance/*"]
      },
      {
        Sid      = "SSMGetInvocation"
        Effect   = "Allow"
        Action   = "ssm:GetCommandInvocation"
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${local.account_id}:*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Role: DevOpsAgentRole-WebappAdmin
# -----------------------------------------------------------------------------
resource "aws_iam_role" "webapp_admin_role" {
  name = "DevOpsAgentRole-WebappAdmin"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "aidevops.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:aidevops:us-east-1:${local.account_id}:agentspace/*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "webapp_admin_permissions" {
  name = "AIDevOpsBasicOperatorActionsPolicy"
  role = aws_iam_role.webapp_admin_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OperatorActions"
        Effect = "Allow"
        Action = [
          "aidevops:GetAgentSpace", "aidevops:GetAssociation", "aidevops:ListAssociations",
          "aidevops:CreateBacklogTask", "aidevops:GetBacklogTask", "aidevops:UpdateBacklogTask",
          "aidevops:ListBacklogTasks", "aidevops:ListChildExecutions", "aidevops:ListJournalRecords",
          "aidevops:DiscoverTopology", "aidevops:InvokeAgent", "aidevops:ListGoals",
          "aidevops:ListRecommendations", "aidevops:ListExecutions", "aidevops:GetRecommendation",
          "aidevops:UpdateRecommendation", "aidevops:CreateKnowledgeItem", "aidevops:ListKnowledgeItems",
          "aidevops:GetKnowledgeItem", "aidevops:UpdateKnowledgeItem", "aidevops:ListPendingMessages",
          "aidevops:InitiateChatForCase", "aidevops:EndChatForCase", "aidevops:DescribeSupportLevel",
          "aidevops:ListChats", "aidevops:CreateChat", "aidevops:StreamMessage"
        ]
        Resource = "arn:aws:aidevops:us-east-1:${local.account_id}:agentspace/*"
      },
      {
        Sid      = "SupportActions"
        Effect   = "Allow"
        Action   = ["support:DescribeCases", "support:InitiateChatForCase", "support:DescribeSupportLevel"]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# EKS Access Entry
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
# SSM Hybrid Activation (for local container testing)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ssm_hybrid" {
  name = "${var.eks_cluster_id}-devops-agent-ssm-hybrid"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ssm.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_hybrid_managed" {
  role       = aws_iam_role.ssm_hybrid.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_ssm_activation" "hybrid" {
  name               = "${var.eks_cluster_id}-devops-agent-hybrid"
  description        = "SSM activation for DevOps Agent local container"
  iam_role           = aws_iam_role.ssm_hybrid.id
  registration_limit = 5

  depends_on = [aws_iam_role_policy_attachment.ssm_hybrid_managed]
}
