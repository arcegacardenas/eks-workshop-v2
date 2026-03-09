set -Eeuo pipefail

before() {
  echo "noop"
}

after() {
  # Validate Agent Space exists
  agent_spaces=$(aws devopsagent list-agent-spaces \
    --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
    --region us-east-1 --output json 2>/dev/null || echo '{"agentSpaces":[]}')
  
  expected_name="${EKS_CLUSTER_NAME}-devops-agent"
  
  if ! echo "$agent_spaces" | jq -e ".agentSpaces[] | select(.name == \"$expected_name\")" > /dev/null 2>&1; then
    >&2 echo "Error: Agent Space '$expected_name' not found"
    exit 1
  fi

  # Validate IAM roles exist
  if ! aws iam get-role --role-name DevOpsAgentRole-AgentSpace > /dev/null 2>&1; then
    >&2 echo "Error: DevOpsAgentRole-AgentSpace IAM role not found"
    exit 1
  fi

  if ! aws iam get-role --role-name DevOpsAgentRole-WebappAdmin > /dev/null 2>&1; then
    >&2 echo "Error: DevOpsAgentRole-WebappAdmin IAM role not found"
    exit 1
  fi

  # Validate EKS access entry exists
  agent_role_arn=$(aws iam get-role --role-name DevOpsAgentRole-AgentSpace --query 'Role.Arn' --output text)
  access_entries=$(aws eks list-access-entries --cluster-name "$EKS_CLUSTER_NAME" --output json)
  
  if ! echo "$access_entries" | jq -e ".accessEntries[] | select(contains(\"DevOpsAgentRole\"))" > /dev/null 2>&1; then
    >&2 echo "Error: EKS access entry for DevOpsAgentRole-AgentSpace not found"
    exit 1
  fi

  echo "DevOps Agent setup validation passed"
}

"$@"
