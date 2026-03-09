# Implementation Plan: DevOps Agent Troubleshooting Integration

## Overview

Integrate the AWS DevOps Agent into the EKS Workshop troubleshooting module by creating Terraform infrastructure with isolated state (`secret_suffix = "devops-agent-state"`), Docusaurus setup pages, a tabbed ALB fix page, IAM policy updates, and a cleanup script. All Terraform follows existing workshop patterns; the key design decision is state isolation so Agent Space resources persist across `prepare-environment` cycles.

## Tasks

- [x] 1. Create Terraform module for DevOps Agent infrastructure
  - [x] 1.1 Create `manifests/modules/troubleshooting/devops-agent/.workshop/terraform/vars.tf`
    - Declare the standard workshop variables matching `manifests/modules/troubleshooting/alb/.workshop/terraform/vars.tf` exactly:
      - `eks_cluster_id` (string), `eks_cluster_version` (string), `cluster_security_group_id` (any), `addon_context` (any), `tags` (any), `resources_precreated` (bool)
    - Include `# tflint-ignore: terraform_unused_declarations` comments on each variable
    - _Requirements: 2.6_

  - [x] 1.2 Create `manifests/modules/troubleshooting/devops-agent/.workshop/terraform/main.tf`
    - Add `terraform` block with `backend "kubernetes"` using `secret_suffix = "devops-agent-state"`, `config_path = "~/.kube/config"`, `namespace = "kube-system"` — this is the critical state isolation mechanism
    - Add an AWS provider alias with `region = "us-east-1"` for DevOps Agent resources (the service is only available in us-east-1 preview)
    - Define `aws_devopsagent_agent_space` resource named `"${var.addon_context.eks_cluster_id}-devops-agent"`
    - Define `aws_iam_role` for `DevOpsAgentRole-AgentSpace` with:
      - Trust policy for the DevOps Agent service principal
      - Inline policy for `ssm:SendCommand` and `ssm:GetCommandInvocation` scoped to Code Server instance tag (`type: eksworkshop-ide`)
    - Define `aws_iam_role` for `DevOpsAgentRole-WebappAdmin` with trust policy for same-account IAM principals and DevOps Agent read/write permissions
    - Define `aws_devopsagent_account_association` linking the AWS account to the Agent Space
    - Define `aws_eks_access_entry` for the DevOpsAgentRole-AgentSpace following the pattern from `manifests/modules/networking/eks-hybrid-nodes/.workshop/terraform/main.tf`:
      - `cluster_name = var.eks_cluster_id`
      - `principal_arn` = the DevOpsAgentRole-AgentSpace IAM role ARN
      - `type = "STANDARD"` (not HYBRID_LINUX)
      - `tags = var.tags`
    - Define `aws_eks_access_policy_association` to grant Kubernetes API access:
      - Associate `arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy` (or `AmazonEKSViewPolicy`) with the access entry
      - This grants the agent ability to describe objects, read pod logs, and list events
    - Do NOT use `timestamp()` or other force-recreation triggers on any resource (idempotent applies)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.3, 8.3_

  - [x] 1.3 Create `manifests/modules/troubleshooting/devops-agent/.workshop/terraform/outputs.tf`
    - Export `environment_variables` map with `DEVOPS_AGENT_SPACE_NAME` and `DEVOPS_AGENT_REGION` (us-east-1)
    - Follow the output format used by other workshop Terraform modules
    - _Requirements: 2.5_

  - [ ]\* 1.4 Write property test for Terraform variable consistency (Property 1)
    - **Property 1: Terraform variable consistency across modules**
    - Parse `vars.tf` from the DevOps Agent module and the ALB module, verify both declare the same standard variable names
    - Use `fast-check` with file content parsing
    - **Validates: Requirements 2.6**

  - [ ]\* 1.5 Write property test for Terraform state isolation (Property 5)
    - **Property 5: Terraform state isolation**
    - Parse the DevOps Agent `main.tf` backend configuration and verify `secret_suffix` is not `"state"`
    - **Validates: Requirements 8.1, 8.2**

  - [ ]\* 1.6 Write property test for no force-recreation triggers (Property 6)
    - **Property 6: No force-recreation triggers on persistent resources**
    - Parse all resource blocks in the DevOps Agent `main.tf` and verify none contain `timestamp()` in triggers
    - **Validates: Requirements 8.3**

- [x] 2. Create cleanup script and update IAM policy
  - [x] 2.1 Create `manifests/modules/troubleshooting/devops-agent/.workshop/cleanup.sh`
    - Add `#!/bin/bash` and `set -e`
    - Run `terraform destroy` against the DevOps Agent state directory
    - Follow the pattern from `manifests/modules/troubleshooting/alb/.workshop/cleanup.sh`
    - _Requirements: 7.3, 7.4, 8.5_

  - [x] 2.2 Add DevOps Agent IAM statements to `lab/iam/policies/troubleshoot.yaml`
    - Add statement granting `devopsagent:*` scoped to the Agent Space resource ARN pattern
    - Add IAM role management permissions for DevOps Agent role ARN patterns (`DevOpsAgentRole-*`)
    - Add `ssm:SendCommand` and `ssm:GetCommandInvocation` permissions
    - Add EKS access entry permissions (`eks:CreateAccessEntry`, `eks:DeleteAccessEntry`, `eks:DescribeAccessEntry`, `eks:CreateAccessPolicy`, `eks:AssociateAccessPolicy`, `eks:DisassociateAccessPolicy`)
    - Follow existing YAML structure and `!Sub` patterns in the file
    - _Requirements: 2.1, 2.2, 3.3_

- [x] 3. Checkpoint - Verify Terraform and IAM changes
  - Ensure all Terraform files are syntactically valid and follow workshop conventions, ask the user if questions arise.

- [x] 4. Create DevOps Agent setup pages
  - [x] 4.1 Create `website/docs/troubleshooting/devops-agent-setup/index.md`
    - Set frontmatter: `title: "DevOps Agent Setup"`, `sidebar_position: 20`, `sidebar_custom_props: { "module": true }`
    - Add overview explaining the AWS DevOps Agent and its role in AI-assisted troubleshooting
    - Include `:::caution` admonition noting us-east-1 region requirement (preview)
    - Include `prepare-environment troubleshooting/devops-agent` command in a `:::tip Before you start` block
    - Clearly distinguish this from other AI-assisted approaches (e.g., Kiro CLI) that may exist in the workshop
    - _Requirements: 1.1, 1.5, 1.6, 6.1, 6.5, 7.1, 7.2_

  - [x] 4.2 Create `website/docs/troubleshooting/devops-agent-setup/create-agent-space.md`
    - Set frontmatter: `title: "Create Agent Space"`, `sidebar_position: 21`
    - Include steps to patch the AWS CLI with the DevOps Agent service model:
      - Download: `curl -o devopsagent.json https://d1co8nkiwcta1g.cloudfront.net/devopsagent.json`
      - Patch: `aws configure add-model --service-model "file://${PWD}/devopsagent.json" --service-name devopsagent`
      - Verify: `aws devopsagent help`
    - Add step-by-step instructions for creating the Agent Space using `aws devopsagent create-agent-space` CLI commands with `--endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" --region us-east-1`
    - Include IAM role creation steps following the CLI onboarding guide (trust policy with `aidevops.amazonaws.com` service principal, `AIOpsAssistantPolicy` managed policy)
    - Include account association using `aws devopsagent associate-service`
    - Include operator app enablement using `aws devopsagent enable-operator-app`
    - Include verification using `aws devopsagent list-agent-spaces`
    - _Requirements: 1.2, 2.5, 9.1, 9.2_

  - [x] 4.3 Create `website/docs/troubleshooting/devops-agent-setup/eks-access.md`
    - Set frontmatter: `title: "EKS Access & SSM Configuration"`, `sidebar_position: 22`
    - Add instructions for verifying EKS cluster access (describe objects, pod logs, events)
    - Add SSM Agent verification: `sudo systemctl status amazon-ssm-agent` and restart instructions if not running
    - Note that the Code Server instance already has `AmazonSSMManagedInstanceCore` policy and is tagged with `type: eksworkshop-ide`
    - _Requirements: 1.3, 1.4, 3.1, 3.2, 3.4_

  - [ ]\* 4.4 Write property test for sidebar position ordering (Property 4)
    - **Property 4: Sidebar position ordering**
    - Parse frontmatter from all troubleshooting module pages and verify DevOps Agent setup pages (positions 20-22) are between the index (position 1) and scenario pages (position 30+)
    - **Validates: Requirements 1.1, 6.1**

- [x] 5. Checkpoint - Verify setup pages and navigation
  - Ensure all new markdown pages have correct frontmatter, sidebar ordering is correct, and content follows workshop style guide. Ask the user if questions arise.

- [x] 6. Modify ALB fix page with tabbed interface
  - [x] 6.1 Add tab imports and wrap existing content in `website/docs/troubleshooting/alb/alb_fix_1.md`
    - Add `import Tabs from '@theme/Tabs';` and `import TabItem from '@theme/TabItem';` after frontmatter, following the pattern from `website/docs/introduction/navigating-labs.md`
    - Keep the intro paragraph and `![ingress]` image OUTSIDE the tabs
    - Wrap the `## Let's start troubleshooting` section (Step 1 through end of file) inside a `<Tabs>` component
    - Place all existing troubleshooting content inside `<TabItem value="manual" label="Manual" default>` — preserve every line unchanged
    - _Requirements: 4.1, 4.2, 4.4, 4.5, 5.6, 6.2_

  - [x] 6.2 Write DevOps Agent tab content in `website/docs/troubleshooting/alb/alb_fix_1.md`
    - Add `<TabItem value="devops-agent" label="DevOps Agent">` as the second tab
    - Include `:::info` admonition directing learners to the DevOps Agent setup page if not yet completed
    - Add instructions to initiate a troubleshooting session with the DevOps Agent using `aws devopsagent` CLI commands (e.g., `create-chat`/`stream-message` or `invoke-agent`) with `--endpoint-url` and `--region us-east-1`
    - Mark interactive/non-deterministic agent commands with `test=false` annotation so the automated test framework skips them
    - Add representative example of DevOps Agent diagnosis output identifying missing `kubernetes.io/role/elb=1` subnet tags
    - Describe how the DevOps Agent executes remediation via SSM commands on the Code Server instance (tagging public subnets, restarting Load Balancer Controller)
    - Add testable verification steps (without `test=false`) matching the manual tab outcome (check ingress address for ALB DNS name, verify subnet tags)
    - Close with `</TabItem>` and `</Tabs>`
    - _Requirements: 4.3, 5.1, 5.2, 5.3, 5.4, 5.5, 6.3, 6.4, 9.4, 9.6_

  - [ ]\* 6.3 Write property test for tab structure (Property 2)
    - **Property 2: Tab structure with manual default on fix pages**
    - Parse `alb_fix_1.md` and verify exactly two `TabItem` components with `value="manual"` (default) and `value="devops-agent"`
    - **Validates: Requirements 4.1, 4.4**

  - [ ]\* 6.4 Write property test for manual content preservation (Property 3)
    - **Property 3: Manual content preservation**
    - Compare the Manual tab content against the original `alb_fix_1.md` troubleshooting steps (from `## Let's start troubleshooting` to end) to verify no substantive changes
    - **Validates: Requirements 4.2, 5.6, 6.2**

- [x] 7. Create automated test hooks
  - [x] 7.1 Create `website/docs/troubleshooting/devops-agent-setup/tests/hook-suite.sh`
    - Follow the existing pattern from `website/docs/troubleshooting/alb/tests/hook-suite.sh`
    - `before()` — noop
    - `after()` — call `prepare-environment` to reset the environment after tests
    - _Requirements: 9.7_

  - [x] 7.2 Create `website/docs/troubleshooting/devops-agent-setup/tests/hook-setup.sh`
    - `before()` — noop
    - `after()` — validate the Agent Space was created by running `aws devopsagent list-agent-spaces --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" --region us-east-1` and checking the output contains the expected agent space name
    - Validate IAM roles exist using `aws iam get-role --role-name DevOpsAgentRole-AgentSpace`
    - Validate EKS access entry exists using `aws eks list-access-entries --cluster-name $EKS_CLUSTER_NAME` and checking for the agent role ARN
    - Exit with non-zero code if any validation fails
    - _Requirements: 9.3_

  - [x] 7.3 Create `website/docs/troubleshooting/alb/tests/hook-fix-1-agent.sh`
    - Follow the same validation pattern as the existing `hook-fix-1.sh`
    - `before()` — noop
    - `after()` — validate subnets are tagged with `kubernetes.io/role/elb=1`, validate ingress events no longer show `FailedBuildModel` with subnet discovery error
    - This hook validates the DevOps Agent tab outcome matches the manual tab outcome
    - _Requirements: 9.5_

- [x] 8. Update spelling dictionary and validate formatting
  - [x] 8.1 Add new terms to `.spelling` if needed (e.g., `devopsagent`, `DevOpsAgentRole`, `WebappAdmin`, `AgentSpace`, `aidevops`)
    - _Requirements: 6.3_
  - [x] 8.2 Run `yarn format:fix` to ensure formatting compliance
  - [x] 8.3 Run `yarn spelling:check` to verify no spelling errors in new content
  - [x] 8.4 Run `yarn markdown:check` to verify markdown formatting
    - _Requirements: 6.3_

- [x] 9. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- The Terraform module uses `secret_suffix = "devops-agent-state"` for state isolation — this is the most critical design decision ensuring Agent Space persists across `prepare-environment` cycles
- The DevOps Agent is currently available in us-east-1 only (preview); the Terraform provider needs `region = "us-east-1"` explicitly
- The EKS access entry uses `type = "STANDARD"` (not HYBRID_LINUX) following the pattern from the hybrid-nodes module
- The Code Server instance already has SSM Agent and `AmazonSSMManagedInstanceCore` policy; the instance is tagged with `type: eksworkshop-ide`
- The AWS CLI must be patched with the DevOps Agent service model (`devopsagent.json`) before `aws devopsagent` commands work
- All `aws devopsagent` commands require `--endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" --region us-east-1`
- The IAM service principal is `aidevops.amazonaws.com` and the managed policy is `AIOpsAssistantPolicy`
- Automated testing: deterministic CLI commands (setup, verification) are testable; interactive agent conversations use `test=false` annotation. Test hooks validate setup and outcomes.
- Property tests use `fast-check` consistent with the Node.js/Yarn workspace toolchain
- Each task references specific requirements for traceability
