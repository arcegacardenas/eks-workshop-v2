---
title: "Create Agent Space"
sidebar_position: 21
---

The `prepare-environment` script has already provisioned the Agent Space and IAM roles using Terraform. In this section, you'll patch the AWS CLI with the DevOps Agent service model and verify the resources were created correctly.

## Step 1: Patch the AWS CLI

The AWS DevOps Agent is not yet included in the standard AWS CLI. Download the service model and register it:

```bash
$ curl -o /tmp/devopsagent.json https://d1co8nkiwcta1g.cloudfront.net/devopsagent.json
```

```bash
$ aws configure add-model --service-model "file:///tmp/devopsagent.json" --service-name devopsagent
```

## Step 2: Verify the CLI patch

Confirm the `devopsagent` subcommand is available:

```bash test=false
$ aws devopsagent help
```

You should see the DevOps Agent CLI help output listing available commands such as `create-agent-space`, `list-agent-spaces`, and `associate-service`.

## Step 3: Review the Agent Space

The Agent Space was created by the `prepare-environment` Terraform. Verify it exists:

```bash hook=setup
$ aws devopsagent list-agent-spaces \
  --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
  --region us-east-1
```

You should see an agent space named `${EKS_CLUSTER_NAME}-devops-agent` in the output.

## Step 4: Review IAM Roles

Two IAM roles were created by Terraform for the DevOps Agent:

**AgentSpace role** — used by the DevOps Agent service for EKS cluster access and SSM command execution:

```bash
$ aws iam get-role --role-name DevOpsAgentRole-AgentSpace --query 'Role.Arn' --output text
```

**WebappAdmin role** — used for the operator app web interface:

```bash
$ aws iam get-role --role-name DevOpsAgentRole-WebappAdmin --query 'Role.Arn' --output text
```

Both roles have trust policies for the `aidevops.amazonaws.com` service principal, scoped to your account.

## Step 5: Review Account Association

The Terraform also associated your AWS account's EKS cluster with the Agent Space using `associate-service`. This allows the DevOps Agent to monitor and interact with your cluster.

```bash test=false
$ aws devopsagent list-service-associations \
  --agent-space-name "${DEVOPS_AGENT_SPACE_NAME}" \
  --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
  --region us-east-1
```

You should see an association with `serviceType: EKS` and your cluster name as the `serviceIdentifier`.

## Step 6: Review Operator App

The operator app was enabled during provisioning, giving you a web-based interface to interact with the DevOps Agent:

```bash test=false
$ aws devopsagent get-operator-app \
  --agent-space-name "${DEVOPS_AGENT_SPACE_NAME}" \
  --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
  --region us-east-1
```

## Step 7: Access the Operator App

You can access the DevOps Agent operator app web interface at:

```text
https://us-east-1.console.aws.amazon.com/devopsagent/home?region=us-east-1#/agent-spaces
```

From there, select your agent space (`${EKS_CLUSTER_NAME}-devops-agent`) to start interactive troubleshooting sessions through the browser.

:::info
The operator app provides a chat-based interface where you can describe issues in natural language. The DevOps Agent will diagnose the problem by inspecting your EKS cluster and suggest or execute remediation steps.
:::
