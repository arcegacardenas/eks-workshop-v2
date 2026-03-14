#!/bin/bash

# This script creates the DevOps Agent IAM roles, EKS access entry, and
# SSM hybrid activation via AWS CLI commands. These resources are NOT managed
# by Terraform so they persist across `prepare-environment` lab switches.
#
# Usage: bash setup-devops-agent.sh

set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

echo "Setting up DevOps Agent infrastructure..."
echo "Account: ${ACCOUNT_ID}"
echo "Region: ${REGION}"
echo "Cluster: ${EKS_CLUSTER_NAME}"

# ---- IAM Role: DevOpsAgentRole-AgentSpace ----
if aws iam get-role --role-name DevOpsAgentRole-AgentSpace &>/dev/null; then
  echo "IAM role DevOpsAgentRole-AgentSpace already exists, skipping creation."
else
  echo "Creating IAM role DevOpsAgentRole-AgentSpace..."

  cat > /tmp/devops-agent-trust-policy.json << TRUSTEOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "aidevops.amazonaws.com" },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": { "aws:SourceAccount": "${ACCOUNT_ID}" },
        "ArnLike": { "aws:SourceArn": "arn:aws:aidevops:us-east-1:${ACCOUNT_ID}:agentspace/*" }
      }
    }
  ]
}
TRUSTEOF

  aws iam create-role \
    --role-name DevOpsAgentRole-AgentSpace \
    --assume-role-policy-document file:///tmp/devops-agent-trust-policy.json \
    --tags Key=module,Value=troubleshooting/devops-agent

  aws iam attach-role-policy \
    --role-name DevOpsAgentRole-AgentSpace \
    --policy-arn arn:aws:iam::aws:policy/AIOpsAssistantPolicy

  cat > /tmp/devops-agent-inline-policy.json << INLINEEOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowExpandedAIOpsAssistantPolicy",
      "Effect": "Allow",
      "Action": [
        "aidevops:GetKnowledgeItem",
        "aidevops:ListKnowledgeItems",
        "eks:AccessKubernetesApi",
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowSSMSendCommand",
      "Effect": "Allow",
      "Action": ["ssm:SendCommand", "ssm:GetCommandInvocation"],
      "Resource": [
        "arn:aws:ssm:${REGION}:${ACCOUNT_ID}:document/AWS-RunShellScript",
        "arn:aws:ssm:${REGION}:${ACCOUNT_ID}:document/AWS-RunPowerShellScript"
      ]
    },
    {
      "Sid": "AllowSSMSendCommandToInstances",
      "Effect": "Allow",
      "Action": "ssm:SendCommand",
      "Resource": [
        "arn:aws:ec2:${REGION}:${ACCOUNT_ID}:instance/*",
        "arn:aws:ssm:${REGION}:${ACCOUNT_ID}:managed-instance/*"
      ]
    },
    {
      "Sid": "AllowSSMGetCommandInvocation",
      "Effect": "Allow",
      "Action": "ssm:GetCommandInvocation",
      "Resource": "arn:aws:ssm:${REGION}:${ACCOUNT_ID}:*"
    }
  ]
}
INLINEEOF

  aws iam put-role-policy \
    --role-name DevOpsAgentRole-AgentSpace \
    --policy-name DevOpsAgentExpandedPolicy \
    --policy-document file:///tmp/devops-agent-inline-policy.json
fi

AGENT_ROLE_ARN=$(aws iam get-role --role-name DevOpsAgentRole-AgentSpace --query 'Role.Arn' --output text)
echo "AgentSpace Role ARN: ${AGENT_ROLE_ARN}"

# ---- IAM Role: DevOpsAgentRole-WebappAdmin ----
if aws iam get-role --role-name DevOpsAgentRole-WebappAdmin &>/dev/null; then
  echo "IAM role DevOpsAgentRole-WebappAdmin already exists, skipping creation."
else
  echo "Creating IAM role DevOpsAgentRole-WebappAdmin..."

  aws iam create-role \
    --role-name DevOpsAgentRole-WebappAdmin \
    --assume-role-policy-document file:///tmp/devops-agent-trust-policy.json \
    --tags Key=module,Value=troubleshooting/devops-agent

  cat > /tmp/devops-agent-webapp-policy.json << WEBAPPEOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowBasicOperatorActions",
      "Effect": "Allow",
      "Action": [
        "aidevops:GetAgentSpace", "aidevops:GetAssociation", "aidevops:ListAssociations",
        "aidevops:CreateBacklogTask", "aidevops:GetBacklogTask", "aidevops:UpdateBacklogTask",
        "aidevops:ListBacklogTasks", "aidevops:ListChildExecutions", "aidevops:ListJournalRecords",
        "aidevops:DiscoverTopology", "aidevops:InvokeAgent", "aidevops:ListGoals",
        "aidevops:ListRecommendations", "aidevops:ListExecutions", "aidevops:GetRecommendation",
        "aidevops:UpdateRecommendation", "aidevops:CreateKnowledgeItem", "aidevops:ListKnowledgeItems",
        "aidevops:GetKnowledgeItem", "aidevops:UpdateKnowledgeItem", "aidevops:ListPendingMessages",
        "aidevops:InitiateChatForCase", "aidevops:EndChatForCase", "aidevops:DescribeSupportLevel",
        "aidevops:ListChats", "aidevops:CreateChat", "aidevops:StreamMessage"
      ],
      "Resource": "arn:aws:aidevops:us-east-1:${ACCOUNT_ID}:agentspace/*"
    },
    {
      "Sid": "AllowSupportOperatorActions",
      "Effect": "Allow",
      "Action": ["support:DescribeCases", "support:InitiateChatForCase", "support:DescribeSupportLevel"],
      "Resource": "*"
    }
  ]
}
WEBAPPEOF

  aws iam put-role-policy \
    --role-name DevOpsAgentRole-WebappAdmin \
    --policy-name AIDevOpsBasicOperatorActionsPolicy \
    --policy-document file:///tmp/devops-agent-webapp-policy.json
fi

WEBAPP_ROLE_ARN=$(aws iam get-role --role-name DevOpsAgentRole-WebappAdmin --query 'Role.Arn' --output text)
echo "WebappAdmin Role ARN: ${WEBAPP_ROLE_ARN}"

# ---- EKS Access Entry ----
EXISTING_ENTRY=$(aws eks list-access-entries --cluster-name "${EKS_CLUSTER_NAME}" \
  --query "accessEntries[?contains(@, 'DevOpsAgentRole-AgentSpace')]" --output text 2>/dev/null || true)

if [ -z "$EXISTING_ENTRY" ]; then
  echo "Creating EKS access entry..."
  aws eks create-access-entry \
    --cluster-name "${EKS_CLUSTER_NAME}" \
    --principal-arn "${AGENT_ROLE_ARN}" \
    --type STANDARD

  echo "Associating EKS access policy..."
  aws eks associate-access-policy \
    --cluster-name "${EKS_CLUSTER_NAME}" \
    --principal-arn "${AGENT_ROLE_ARN}" \
    --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy" \
    --access-scope type=cluster
else
  echo "EKS access entry already exists, skipping."
fi

# ---- SSM Hybrid Activation ----
SSM_ROLE_NAME="${EKS_CLUSTER_NAME}-devops-agent-ssm-hybrid"

if aws iam get-role --role-name "${SSM_ROLE_NAME}" &>/dev/null; then
  echo "SSM hybrid role already exists, skipping creation."
else
  echo "Creating SSM hybrid role..."
  aws iam create-role \
    --role-name "${SSM_ROLE_NAME}" \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ssm.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

  aws iam attach-role-policy \
    --role-name "${SSM_ROLE_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
fi

# Check for existing activation
EXISTING_ACTIVATION=$(aws ssm describe-activations \
  --filters "FilterKey=DefaultInstanceName,FilterValues=${EKS_CLUSTER_NAME}-devops-agent-hybrid" \
  --query 'ActivationList[?Expired==`false`].ActivationId' --output text 2>/dev/null || true)

if [ -z "$EXISTING_ACTIVATION" ]; then
  echo "Creating SSM hybrid activation..."
  SSM_HYBRID_ROLE_ARN=$(aws iam get-role --role-name "${SSM_ROLE_NAME}" --query 'Role.Arn' --output text)

  ACTIVATION_RESULT=$(aws ssm create-activation \
    --default-instance-name "${EKS_CLUSTER_NAME}-devops-agent-hybrid" \
    --iam-role "${SSM_HYBRID_ROLE_ARN}" \
    --registration-limit 5)

  SSM_ACTIVATION_ID=$(echo "$ACTIVATION_RESULT" | jq -r '.ActivationId')
  SSM_ACTIVATION_CODE=$(echo "$ACTIVATION_RESULT" | jq -r '.ActivationCode')
else
  SSM_ACTIVATION_ID="$EXISTING_ACTIVATION"
  SSM_ACTIVATION_CODE="(already created - check SSM console)"
fi

echo ""
echo "============================================"
echo "DevOps Agent setup complete!"
echo "============================================"
echo "Agent Space Name: ${EKS_CLUSTER_NAME}-devops-agent"
echo "AgentSpace Role: ${AGENT_ROLE_ARN}"
echo "WebappAdmin Role: ${WEBAPP_ROLE_ARN}"
echo "SSM Activation ID: ${SSM_ACTIVATION_ID}"
echo ""
echo "Exporting environment variables..."

cat > ~/.bashrc.d/devops-agent.bash << ENVEOF
export DEVOPS_AGENT_SPACE_NAME="${EKS_CLUSTER_NAME}-devops-agent"
export DEVOPS_AGENT_ROLE_ARN="${AGENT_ROLE_ARN}"
export DEVOPS_AGENT_WEBAPP_ROLE_ARN="${WEBAPP_ROLE_ARN}"
export DEVOPS_AGENT_REGION="us-east-1"
export DEVOPS_AGENT_ENDPOINT="https://api.prod.cp.aidevops.us-east-1.api.aws"
export SSM_ACTIVATION_ID="${SSM_ACTIVATION_ID}"
export SSM_ACTIVATION_CODE="${SSM_ACTIVATION_CODE}"
ENVEOF

source ~/.bashrc.d/devops-agent.bash

echo "Done! Environment variables saved to ~/.bashrc.d/devops-agent.bash"
