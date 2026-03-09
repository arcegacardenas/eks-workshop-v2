---
title: "EKS Access & SSM Configuration"
sidebar_position: 22
---

In this section, you'll verify that the DevOps Agent has the necessary access to your EKS cluster and that the SSM Agent is running on the Code Server instance for remote command execution.

## EKS Access Entry

The Terraform provisioned an EKS access entry that grants the `DevOpsAgentRole-AgentSpace` role access to the Kubernetes API. This allows the DevOps Agent to describe cluster objects, retrieve pod logs, and read events.

Verify the access entry exists:

```bash
$ aws eks list-access-entries --cluster-name $EKS_CLUSTER_NAME --output json | jq '.accessEntries[] | select(contains("DevOpsAgentRole"))'
```

You should see the ARN of the `DevOpsAgentRole-AgentSpace` role in the output, confirming the agent has cluster access.

## Kubernetes API Access

Confirm the agent role has the expected permissions on the cluster:

```bash test=false
$ kubectl auth can-i get pods --as-group=system:masters --all-namespaces
```

This should return `yes`, indicating cluster-admin level access is available. The DevOps Agent uses this access to inspect pods, services, ingress resources, and events when diagnosing issues.

## SSM Agent Verification

The DevOps Agent executes remediation commands on the Code Server instance via AWS Systems Manager (SSM). The SSM Agent must be running for this to work.

Check the SSM Agent status:

```bash test=false
$ sudo systemctl status amazon-ssm-agent
```

You should see `active (running)` in the output. If the SSM Agent is not running, start it:

```bash test=false
$ sudo systemctl start amazon-ssm-agent
```

:::info
The Code Server instance already has the `AmazonSSMManagedInstanceCore` IAM policy attached and is tagged with `type: eksworkshop-ide`. The DevOps Agent's SSM permissions are scoped to instances with this tag, so no additional SSM configuration is needed on the instance side.
:::

## Summary

At this point, the DevOps Agent setup is complete:

- **Agent Space** is provisioned and associated with your EKS cluster
- **IAM roles** grant the agent permissions for cluster access and SSM command execution
- **EKS access entry** allows the agent to interact with the Kubernetes API
- **SSM Agent** is running on the Code Server instance to receive remediation commands

You can now use the DevOps Agent as an alternative troubleshooting approach in the scenario labs. Look for the **DevOps Agent** tab on troubleshooting fix pages.
