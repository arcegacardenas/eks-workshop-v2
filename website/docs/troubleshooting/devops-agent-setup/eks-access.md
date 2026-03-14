---
title: "EKS Access & SSM Configuration"
sidebar_position: 22
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

In this section, you'll verify that the DevOps Agent has the necessary access to your EKS cluster and configure SSM so the agent can execute remediation commands on your environment.

## EKS Access Entry

The `prepare-environment` script provisioned an EKS access entry that grants the `DevOpsAgentRole-AgentSpace` role access to the Kubernetes API. This allows the DevOps Agent to describe cluster objects, retrieve pod logs, and read events.

Verify the access entry exists:

```bash
$ aws eks list-access-entries --cluster-name $EKS_CLUSTER_NAME --output json | jq '.accessEntries[] | select(contains("DevOpsAgentRole"))'
```

Verify the access policy grants cluster-admin level access:

```bash
$ aws eks list-associated-access-policies --cluster-name $EKS_CLUSTER_NAME \
  --principal-arn $(aws iam get-role --role-name DevOpsAgentRole-AgentSpace --query 'Role.Arn' --output text) \
  --query 'associatedAccessPolicies[].policyArn' --output text
```

You should see `arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy` in the output.

## SSM Agent Configuration

The DevOps Agent executes remediation commands on your environment via AWS Systems Manager (SSM). The setup differs depending on whether you're running in the cloud (EC2) or locally (container).

<Tabs>
<TabItem value="ec2" label="Cloud (EC2)" default>

The EC2 instance running the Code Server IDE already has:
- SSM Agent pre-installed (Amazon Linux 2023)
- `AmazonSSMManagedInstanceCore` IAM policy attached
- Instance tagged with `type: eksworkshop-ide`

Verify the SSM Agent is running:

```bash test=false
$ sudo systemctl status amazon-ssm-agent
```

You should see `active (running)`. If not, start it:

```bash test=false
$ sudo systemctl start amazon-ssm-agent
```

Verify the instance is registered with SSM:

```bash test=false
$ aws ssm describe-instance-information --query 'InstanceInformationList[?PingStatus==`Online`].InstanceId' --output text
```

</TabItem>
<TabItem value="container" label="Local (Container)">

When running locally via `make shell` or `make ide`, the container doesn't have SSM Agent installed. You need to install it and register as a hybrid managed instance.

The `prepare-environment` script created an SSM hybrid activation. The activation credentials are available as environment variables: `SSM_ACTIVATION_ID` and `SSM_ACTIVATION_CODE`.

### Install SSM Agent

```bash test=false
$ sudo yum install -y amazon-ssm-agent
```

### Register as a hybrid managed instance

```bash test=false
$ sudo amazon-ssm-agent -register -code "${SSM_ACTIVATION_CODE}" -id "${SSM_ACTIVATION_ID}" -region "${AWS_REGION}"
```

### Start the SSM Agent

```bash test=false
$ nohup sudo amazon-ssm-agent > /dev/null 2>&1 &
```

### Verify registration

```bash test=false
$ aws ssm describe-instance-information \
  --filters "Key=ActivationIds,Values=${SSM_ACTIVATION_ID}" \
  --query 'InstanceInformationList[].{InstanceId:InstanceId,PingStatus:PingStatus}' \
  --output table
```

You should see your managed instance with `PingStatus: Online`. The instance ID will start with `mi-` (managed instance) instead of `i-` (EC2 instance).

:::info
The hybrid managed instance ID (`mi-*`) is what the DevOps Agent will use to send SSM commands to your container. The DevOps Agent's SSM permissions allow commands to both EC2 instances tagged with `type: eksworkshop-ide` and managed instances registered through this activation.
:::

</TabItem>
</Tabs>

## Summary

At this point, the DevOps Agent setup is complete:

- **Agent Space** is provisioned and associated with your EKS cluster
- **IAM roles** grant the agent permissions for cluster access and SSM command execution
- **EKS access entry** allows the agent to interact with the Kubernetes API
- **SSM Agent** is configured to receive remediation commands

You can now use the DevOps Agent as an alternative troubleshooting approach in the scenario labs. Look for the **DevOps Agent** tab on troubleshooting fix pages.
