#!/bin/bash

set -e

logmessage "Cleaning up DevOps Agent resources..."

tf_dir="/eks-workshop/terraform"

export TF_DATA_DIR="/eks-workshop/terraform-data"
export TF_VAR_eks_cluster_id="$EKS_CLUSTER_NAME"

logmessage "Destroying DevOps Agent Terraform state..."

terraform -chdir="$tf_dir" init -upgrade
terraform -chdir="$tf_dir" destroy --auto-approve

logmessage "Removing EKS access entry for DevOps Agent if it exists..."

AGENT_ROLE_ARN=$(aws iam get-role --role-name DevOpsAgentRole-AgentSpace --query 'Role.Arn' --output text 2>/dev/null || true)

if [ ! -z "$AGENT_ROLE_ARN" ]; then
  aws eks delete-access-entry --cluster-name "$EKS_CLUSTER_NAME" --principal-arn "$AGENT_ROLE_ARN" 2>/dev/null || true
fi
