---
title: "Create Agent Space"
sidebar_position: 21
---

In this section, you'll create an AWS DevOps Agent Space, associate your AWS account, and enable the operator app. The `prepare-environment` script already provisioned the IAM roles, EKS access entry, and SSM activation — you'll use those to configure the Agent Space.

:::info
In the troubleshooting scenario labs (ALB, DNS, etc.), all of these steps are automated by `prepare-environment`. This walkthrough teaches you the manual steps so you understand what's being provisioned.
:::

## Step 1: Patch the AWS CLI

The AWS DevOps Agent is in preview and not yet included in the standard AWS CLI. The `prepare-environment` script already patched it, but let's verify:

```bash test=false
$ aws devopsagent help
```

You should see the DevOps Agent CLI help output. If you get `Found invalid choice 'devopsagent'`, run:

```bash
$ curl -o /tmp/devopsagent.json https://d1co8nkiwcta1g.cloudfront.net/devopsagent.json
```

```bash
$ aws configure add-model --service-model "file:///tmp/devopsagent.json" --service-name devopsagent
```

## Step 2: Create the Agent Space

Create the Agent Space — this is the primary container for your DevOps Agent configuration:

```bash test=false
$ aws devopsagent create-agent-space --name "${DEVOPS_AGENT_SPACE_NAME}" --description "EKS Workshop DevOps Agent for troubleshooting" --endpoint-url "${DEVOPS_AGENT_ENDPOINT}" --region us-east-1
```

Save the agent space ID:

```bash test=false
$ export DEVOPS_AGENT_SPACE_ID=$(aws devopsagent list-agent-spaces --endpoint-url "${DEVOPS_AGENT_ENDPOINT}" --region us-east-1 --query "agentSpaces[?name=='${DEVOPS_AGENT_SPACE_NAME}'].agentSpaceId" --output text)
```

```bash test=false
$ echo "Agent Space ID: ${DEVOPS_AGENT_SPACE_ID}"
```

## Step 3: Associate your AWS Account

Associate your AWS account with the Agent Space so the DevOps Agent can monitor your EKS cluster:

```bash test=false
$ echo '{"aws":{"assumableRoleArn":"'${DEVOPS_AGENT_ROLE_ARN}'","accountId":"'${AWS_ACCOUNT_ID}'","accountType":"monitor","resources":[]}}' > /tmp/devops-agent-aws-config.json
```

```bash test=false
$ aws devopsagent associate-service --agent-space-id "${DEVOPS_AGENT_SPACE_ID}" --service-id aws --configuration file:///tmp/devops-agent-aws-config.json --endpoint-url "${DEVOPS_AGENT_ENDPOINT}" --region us-east-1
```

## Step 4: Enable the Operator App

Enable the web-based operator interface for interactive troubleshooting:

```bash test=false
$ aws devopsagent enable-operator-app --agent-space-id "${DEVOPS_AGENT_SPACE_ID}" --auth-flow iam --operator-app-role-arn "${DEVOPS_AGENT_WEBAPP_ROLE_ARN}" --endpoint-url "${DEVOPS_AGENT_ENDPOINT}" --region us-east-1
```

## Step 5: Verify and Access

Verify the Agent Space was created:

```bash test=false
$ aws devopsagent list-agent-spaces --endpoint-url "${DEVOPS_AGENT_ENDPOINT}" --region us-east-1
```

Review the IAM roles provisioned by `prepare-environment`:

```bash
$ aws iam get-role --role-name DevOpsAgentRole-AgentSpace --query 'Role.{Name:RoleName,Arn:Arn}' --output table
```

```bash
$ aws iam get-role --role-name DevOpsAgentRole-WebappAdmin --query 'Role.{Name:RoleName,Arn:Arn}' --output table
```

Access the operator app:

```bash test=false
$ echo "https://${DEVOPS_AGENT_SPACE_ID}.aidevops.global.app.aws/dashboard"
```

:::info
The operator app provides a chat-based interface where you can describe issues in natural language. The DevOps Agent will diagnose the problem by inspecting your EKS cluster and suggest or execute remediation steps via SSM on your Code Server instance.
:::
