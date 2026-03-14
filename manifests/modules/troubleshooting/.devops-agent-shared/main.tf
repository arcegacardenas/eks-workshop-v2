# -----------------------------------------------------------------------------
# Shared DevOps Agent Module
# Include this in any troubleshooting scenario's Terraform to automatically
# provision a DevOps Agent space with full EKS + SSM access.
#
# Usage in a scenario module:
#   module "devops_agent" {
#     source         = "../../../.devops-agent-shared"
#     eks_cluster_id = var.eks_cluster_id
#     addon_context  = var.addon_context
#     tags           = var.tags
#   }
# -----------------------------------------------------------------------------

variable "eks_cluster_id" {
  type = string
}

variable "addon_context" {
  type = any
}

variable "tags" {
  type = any
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id       = data.aws_caller_identity.current.account_id
  region           = data.aws_region.current.name
  agent_space_name = "${var.eks_cluster_id}-devops-agent"
  endpoint_url     = "https://api.prod.cp.aidevops.us-east-1.api.aws"

  tags = merge(var.tags, {
    module = "troubleshooting/devops-agent"
  })
}

# -----------------------------------------------------------------------------
# IAM Role: DevOpsAgentRole-AgentSpace
# -----------------------------------------------------------------------------
resource "aws_iam_role" "agent_space" {
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
  role       = aws_iam_role.agent_space.name
  policy_arn = "arn:aws:iam::aws:policy/AIOpsAssistantPolicy"
}

resource "aws_iam_role_policy" "agent_space_expanded" {
  name = "DevOpsAgentExpandedPolicy"
  role = aws_iam_role.agent_space.id

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
        Resource = ["arn:aws:ssm:${local.region}:${local.account_id}:document/AWS-RunShellScript", "arn:aws:ssm:${local.region}:${local.account_id}:document/AWS-RunPowerShellScript"]
      },
      {
        Sid      = "SSMInstances"
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = ["arn:aws:ec2:${local.region}:${local.account_id}:instance/*", "arn:aws:ssm:${local.region}:${local.account_id}:managed-instance/*"]
      },
      {
        Sid      = "SSMGetInvocation"
        Effect   = "Allow"
        Action   = "ssm:GetCommandInvocation"
        Resource = "arn:aws:ssm:${local.region}:${local.account_id}:*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Role: DevOpsAgentRole-WebappAdmin
# -----------------------------------------------------------------------------
resource "aws_iam_role" "webapp_admin" {
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
  role = aws_iam_role.webapp_admin.id

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
  principal_arn = aws_iam_role.agent_space.arn
  type          = "STANDARD"
  tags          = var.tags
}

resource "aws_eks_access_policy_association" "devops_agent" {
  cluster_name  = var.eks_cluster_id
  principal_arn = aws_iam_role.agent_space.arn
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

# -----------------------------------------------------------------------------
# DevOps Agent Space + Association + Operator App (via CLI)
# Patching the AWS CLI and calling the DevOps Agent API
# -----------------------------------------------------------------------------
resource "null_resource" "patch_cli" {
  triggers = {
    always_run = "v1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -s -o /tmp/devopsagent.json https://d1co8nkiwcta1g.cloudfront.net/devopsagent.json
      aws configure add-model --service-model "file:///tmp/devopsagent.json" --service-name devopsagent
    EOT
  }
}

resource "time_sleep" "wait_for_iam" {
  depends_on      = [aws_iam_role.agent_space, aws_iam_role_policy_attachment.agent_space_managed, aws_iam_role_policy.agent_space_expanded]
  create_duration = "15s"
}

resource "null_resource" "create_agent_space" {
  triggers = {
    agent_space_name = local.agent_space_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      # Delete any existing agent spaces with this name (clean slate)
      EXISTING_IDS=$(aws devopsagent list-agent-spaces \
        --endpoint-url "${local.endpoint_url}" \
        --region us-east-1 \
        --query "agentSpaces[?name=='${local.agent_space_name}'].agentSpaceId" \
        --output text 2>/dev/null) || true

      for OLD_ID in $EXISTING_IDS; do
        if [ -n "$OLD_ID" ] && [ "$OLD_ID" != "None" ]; then
          echo "Deleting stale Agent Space: $OLD_ID"
          aws devopsagent delete-agent-space \
            --agent-space-id "$OLD_ID" \
            --endpoint-url "${local.endpoint_url}" \
            --region us-east-1 2>/dev/null || true
        fi
      done

      # Create fresh agent space
      aws devopsagent create-agent-space \
        --name "${local.agent_space_name}" \
        --description "EKS Workshop DevOps Agent for troubleshooting" \
        --endpoint-url "${local.endpoint_url}" \
        --region us-east-1

      # Get the new agent space ID
      SPACE_ID=$(aws devopsagent list-agent-spaces \
        --endpoint-url "${local.endpoint_url}" \
        --region us-east-1 \
        --query "agentSpaces[?name=='${local.agent_space_name}'].agentSpaceId | [0]" \
        --output text)

      echo -n "$SPACE_ID" > /tmp/devops-agent-space-id.txt
      echo "Agent Space ID: $SPACE_ID"

      # Associate AWS account
      echo '{"aws":{"assumableRoleArn":"${aws_iam_role.agent_space.arn}","accountId":"${local.account_id}","accountType":"monitor","resources":[]}}' > /tmp/devops-agent-aws-config.json

      aws devopsagent associate-service \
        --agent-space-id "$SPACE_ID" \
        --service-id aws \
        --configuration file:///tmp/devops-agent-aws-config.json \
        --endpoint-url "${local.endpoint_url}" \
        --region us-east-1

      # Enable operator app
      aws devopsagent enable-operator-app \
        --agent-space-id "$SPACE_ID" \
        --auth-flow iam \
        --operator-app-role-arn "${aws_iam_role.webapp_admin.arn}" \
        --endpoint-url "${local.endpoint_url}" \
        --region us-east-1
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      curl -s -o /tmp/devopsagent.json https://d1co8nkiwcta1g.cloudfront.net/devopsagent.json
      aws configure add-model --service-model "file:///tmp/devopsagent.json" --service-name devopsagent 2>/dev/null || true

      EXISTING_IDS=$(aws devopsagent list-agent-spaces \
        --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
        --region us-east-1 \
        --query "agentSpaces[?name=='${self.triggers.agent_space_name}'].agentSpaceId" \
        --output text 2>/dev/null) || true

      for OLD_ID in $EXISTING_IDS; do
        if [ -n "$OLD_ID" ] && [ "$OLD_ID" != "None" ]; then
          aws devopsagent delete-agent-space \
            --agent-space-id "$OLD_ID" \
            --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
            --region us-east-1 2>/dev/null || true
        fi
      done
    EOT
  }

  depends_on = [null_resource.patch_cli, time_sleep.wait_for_iam]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "agent_space_name" {
  value = local.agent_space_name
}

output "agent_space_role_arn" {
  value = aws_iam_role.agent_space.arn
}

output "webapp_admin_role_arn" {
  value = aws_iam_role.webapp_admin.arn
}

output "ssm_activation_id" {
  value = aws_ssm_activation.hybrid.id
}

output "ssm_activation_code" {
  value = aws_ssm_activation.hybrid.activation_code
}

output "endpoint_url" {
  value = local.endpoint_url
}
