---
title: "DevOps Agent Setup"
chapter: true
sidebar_position: 20
sidebar_custom_props: { "module": true }
---

::required-time

In this lab, you'll set up the AWS DevOps Agent to enable AI-assisted troubleshooting for your EKS cluster. The DevOps Agent connects to your cluster to diagnose operational issues — inspecting Kubernetes objects, reading pod logs, and analyzing events — then executes remediation commands on your Code Server instance via AWS Systems Manager (SSM).

Once configured, you can use the DevOps Agent as an alternative approach in the troubleshooting scenario labs alongside the manual CLI steps.

:::caution Preview
The AWS DevOps Agent is currently available in the **us-east-1** region only (preview). All `aws devopsagent` CLI commands require `--endpoint-url` and `--region us-east-1` flags.
:::

:::tip Before you start
Prepare your environment for this section:

```bash timeout=600 wait=10
$ prepare-environment troubleshooting/devops-agent
```

You can view the Terraform that applies these changes [here](https://github.com/VAR::MANIFESTS_OWNER/VAR::MANIFESTS_REPOSITORY/tree/VAR::MANIFESTS_REF/manifests/modules/troubleshooting/devops-agent/.workshop/terraform).
:::

:::info
The `prepare-environment` script provisions the following resources using Terraform:

- An **Agent Space** for the DevOps Agent scoped to your EKS cluster
- **IAM roles** (`DevOpsAgentRole-AgentSpace` and `DevOpsAgentRole-WebappAdmin`) with trust policies for the `aidevops.amazonaws.com` service principal
- An **EKS access entry** granting the Agent Space role Kubernetes API access to your cluster
- An **account association** linking your AWS account to the Agent Space
- **SSM permissions** allowing the agent to execute commands on the Code Server instance

These resources use isolated Terraform state (`secret_suffix = "devops-agent-state"`) so they persist when you switch between troubleshooting labs.
:::

## What We'll Cover

- Patching the AWS CLI with the DevOps Agent service model
- Reviewing the Agent Space created by `prepare-environment`
- Verifying IAM roles and EKS access configuration
- Confirming SSM Agent connectivity on the Code Server instance

## Prerequisites

Before proceeding, ensure you have:

- Access to the EKS cluster (`kubectl` configured)
- AWS CLI installed and configured
- Completed the `prepare-environment` step above

:::note
This lab configures the **AWS DevOps Agent**, a managed service that uses AI to diagnose and remediate EKS operational issues. This is distinct from other AI-assisted approaches (such as IDE-based tools) that may appear elsewhere in the workshop.
:::
