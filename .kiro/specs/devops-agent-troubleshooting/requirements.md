# Requirements Document

## Introduction

This feature integrates AWS DevOps Agent into the EKS Workshop troubleshooting module. Learners will provision an Agent Space using Terraform, configure EKS cluster access and SSM-based remediation, and then use the DevOps Agent as an alternative troubleshooting approach alongside the existing manual CLI steps. Each troubleshooting scenario page gains a tabbed interface with a "Manual" tab (existing content) and a "DevOps Agent" tab (AI-assisted troubleshooting via the agent). The Code Server EC2 instance is configured for SSM command execution so the DevOps Agent can run remediation commands. The initial implementation targets the "ALB Not Creating" scenario (`alb_fix_1.md`).

## Glossary

- **Workshop_Site**: The Docusaurus-based EKS Workshop website that renders markdown content into interactive lab pages
- **Troubleshooting_Module**: The section of the Workshop_Site located at `website/docs/troubleshooting/` containing scenario-based troubleshooting labs
- **DevOps_Agent**: The AWS DevOps Agent service that diagnoses and remediates operational issues by connecting to EKS clusters and executing commands via SSM on target instances
- **Agent_Space**: The primary configuration container for the DevOps Agent, provisioned via Terraform, that defines the scope and permissions for the agent's operations
- **Tab_Component**: The Docusaurus `Tabs` and `TabItem` components used to present alternative content views within a single page
- **Manual_Tab**: The tab containing existing step-by-step CLI commands for manual troubleshooting
- **DevOps_Agent_Tab**: The tab containing instructions for AI-assisted troubleshooting using the AWS DevOps Agent
- **Code_Server_Instance**: The EC2 instance running the workshop IDE (code-server), provisioned via CloudFormation at `lab/cfn/eks-workshop-vscode-cfn.yaml`
- **SSM_Agent**: The AWS Systems Manager Agent running on the Code_Server_Instance that enables remote command execution
- **Prepare_Environment_Script**: The `prepare-environment` shell function that resets the workshop environment, applies Terraform, and configures the lab for a given module
- **ALB_Scenario**: The ALB Controller troubleshooting scenario located at `website/docs/troubleshooting/alb/`
- **DevOps_Agent_Terraform_Module**: The Terraform configuration that provisions the Agent_Space, IAM roles, and account associations, following the pattern from the reference repository `github.com/aws-samples/sample-aws-devops-agent-terraform`
- **DevOpsAgentRole_AgentSpace**: The IAM role created by the DevOps_Agent_Terraform_Module for monitoring and cluster access
- **DevOpsAgentRole_WebappAdmin**: The IAM role created by the DevOps_Agent_Terraform_Module for the operator interface

## Requirements

### Requirement 1: DevOps Agent Setup Section

**User Story:** As a workshop learner, I want a setup section in the troubleshooting module that guides me through provisioning and configuring the AWS DevOps Agent, so that I can use it for AI-assisted troubleshooting in subsequent labs.

#### Acceptance Criteria

1. THE Workshop_Site SHALL display a DevOps Agent setup page in the Troubleshooting_Module before all scenario pages, with a `sidebar_position` value that places it after the module index and before existing scenario pages
2. WHEN a learner navigates to the DevOps Agent setup page, THE Workshop_Site SHALL present step-by-step instructions for creating an Agent_Space using Terraform, following the pattern from the reference repository `github.com/aws-samples/sample-aws-devops-agent-terraform`
3. THE setup page SHALL include instructions for configuring EKS cluster access so the DevOps_Agent can describe cluster objects, retrieve pod logs, and read events
4. THE setup page SHALL include instructions for configuring SSM access so the DevOps_Agent can execute remediation commands on the Code_Server_Instance
5. THE setup page SHALL note that the AWS DevOps Agent is available in the us-east-1 region only (preview)
6. THE setup page SHALL follow the same markdown and frontmatter conventions used by other pages in the Troubleshooting_Module

### Requirement 2: DevOps Agent Terraform Infrastructure

**User Story:** As a workshop learner, I want Terraform configurations that provision the DevOps Agent infrastructure, so that the `prepare-environment` script can set up the agent automatically.

#### Acceptance Criteria

1. THE DevOps_Agent_Terraform_Module SHALL provision an Agent_Space, the DevOpsAgentRole_AgentSpace IAM role, and the DevOpsAgentRole_WebappAdmin IAM role
2. THE DevOps_Agent_Terraform_Module SHALL configure the Agent_Space with EKS cluster access permissions to describe Kubernetes objects, retrieve pod logs, and read cluster events, using an EKS Access Entry (`aws_eks_access_entry`) with the DevOpsAgentRole_AgentSpace as the principal and an associated EKS Access Policy for Kubernetes API access
3. THE DevOps_Agent_Terraform_Module SHALL configure the Agent_Space with SSM permissions to send commands to the Code_Server_Instance
4. THE DevOps_Agent_Terraform_Module SHALL reside in `manifests/modules/troubleshooting/devops-agent/.workshop/terraform/` following the existing module Terraform directory pattern
5. WHEN the Prepare_Environment_Script runs for the DevOps Agent module, THE DevOps_Agent_Terraform_Module SHALL be applied to provision all required infrastructure
6. THE DevOps_Agent_Terraform_Module SHALL use standard Terraform variable conventions (`vars.tf` with `addon_context`, `eks_cluster_version`, `tags`) consistent with other workshop Terraform modules

### Requirement 3: SSM Configuration on Code Server Instance

**User Story:** As a workshop learner, I want the Code Server instance to accept SSM commands from the DevOps Agent, so that the agent can execute remediation commands on my behalf.

#### Acceptance Criteria

1. THE Code_Server_Instance SHALL have the SSM_Agent installed and running to accept remote command execution
2. THE Code_Server_Instance IAM role SHALL include permissions for the SSM_Agent to communicate with the Systems Manager service (the existing `AmazonSSMManagedInstanceCore` managed policy satisfies this)
3. THE DevOps_Agent_Terraform_Module SHALL grant the DevOpsAgentRole_AgentSpace IAM role permission to call `ssm:SendCommand` and `ssm:GetCommandInvocation` targeting the Code_Server_Instance
4. IF the SSM_Agent is not running on the Code_Server_Instance, THEN THE setup page SHALL provide instructions to verify and start the SSM_Agent

### Requirement 4: Tabbed Troubleshooting Interface

**User Story:** As a workshop learner, I want each troubleshooting scenario page to offer both manual and DevOps Agent approaches in separate tabs, so that I can choose my preferred troubleshooting method.

#### Acceptance Criteria

1. THE Workshop_Site SHALL render each troubleshooting fix page with a Tab_Component containing two tabs: Manual_Tab and DevOps_Agent_Tab
2. WHEN a learner selects the Manual_Tab, THE Workshop_Site SHALL display the existing manual troubleshooting steps unchanged
3. WHEN a learner selects the DevOps_Agent_Tab, THE Workshop_Site SHALL display instructions for troubleshooting the same scenario using the DevOps_Agent
4. THE Manual_Tab SHALL be the default selected tab on page load
5. THE Tab_Component SHALL use Docusaurus `Tabs` and `TabItem` imports consistent with existing workshop patterns (as used in `website/docs/introduction/navigating-labs.md`)

### Requirement 5: ALB Not Creating — DevOps Agent Troubleshooting Content

**User Story:** As a workshop learner, I want DevOps Agent instructions for the "ALB Not Creating" scenario, so that I can learn how to use AI-assisted troubleshooting for subnet tagging and ALB creation issues.

#### Acceptance Criteria

1. THE DevOps_Agent_Tab for the "ALB Not Creating" page (`website/docs/troubleshooting/alb/alb_fix_1.md`) SHALL guide the learner to use the DevOps_Agent to diagnose why the ALB is not being created
2. THE DevOps_Agent_Tab SHALL instruct the learner to initiate a troubleshooting session with the DevOps_Agent, providing context about the ingress resource in the `ui` namespace
3. THE DevOps_Agent_Tab SHALL show a representative example of the DevOps_Agent diagnosis output identifying the missing subnet tags (`kubernetes.io/role/elb=1`)
4. THE DevOps_Agent_Tab SHALL describe how the DevOps_Agent executes the remediation (tagging public subnets, restarting the Load Balancer Controller) via SSM commands on the Code_Server_Instance
5. WHEN the learner follows the DevOps_Agent_Tab instructions, THE learner SHALL arrive at the same resolution (public subnets tagged with `kubernetes.io/role/elb=1` and Load Balancer Controller restarted) as the Manual_Tab
6. THE DevOps_Agent_Tab SHALL preserve all existing manual troubleshooting content in the Manual_Tab without modification

### Requirement 6: Content Consistency and Navigation

**User Story:** As a workshop learner, I want the new DevOps Agent content to integrate seamlessly with the existing troubleshooting module, so that my navigation experience remains consistent.

#### Acceptance Criteria

1. THE Workshop_Site SHALL maintain the existing troubleshooting module navigation structure with the DevOps Agent setup page added before scenario pages
2. THE Workshop_Site SHALL preserve all existing manual troubleshooting content without modification to its substance
3. THE DevOps_Agent_Tab content SHALL follow the EKS Workshop style guide for terminal commands, code blocks, and explanatory text
4. IF a learner has not completed the DevOps Agent setup, THEN THE DevOps_Agent_Tab SHALL include a note directing the learner to the setup page
5. THE DevOps Agent setup page and tab content SHALL clearly distinguish this approach from any other AI-assisted troubleshooting approaches (such as Kiro CLI) that may exist in the workshop

### Requirement 7: DevOps Agent Setup Prepare Environment Integration

**User Story:** As a workshop learner, I want the DevOps Agent infrastructure to be provisioned when I run `prepare-environment` for the troubleshooting module, so that the agent is ready to use when I reach the troubleshooting scenarios.

#### Acceptance Criteria

1. WHEN the learner runs `prepare-environment troubleshooting/devops-agent`, THE Prepare_Environment_Script SHALL apply the DevOps_Agent_Terraform_Module to provision the Agent_Space and associated IAM roles
2. THE Prepare_Environment_Script output SHALL indicate the DevOps Agent infrastructure provisioning status
3. WHEN the DevOps_Agent_Terraform_Module is destroyed (via cleanup), THE cleanup process SHALL remove the Agent_Space and associated IAM roles
4. THE DevOps_Agent_Terraform_Module SHALL include a `cleanup.sh` script in `manifests/modules/troubleshooting/devops-agent/.workshop/` following the existing cleanup pattern

### Requirement 8: DevOps Agent Configuration Persistence Across Labs

**User Story:** As a workshop learner, I want the DevOps Agent configuration (Agent Space, IAM roles, account associations) to persist when I switch between troubleshooting labs, so that I do not need to re-provision the agent for each scenario.

#### Acceptance Criteria

1. WHEN the Prepare_Environment_Script runs for a different troubleshooting scenario (e.g., `prepare-environment troubleshooting/alb`), THE DevOps_Agent infrastructure (Agent_Space, IAM roles, account associations) SHALL NOT be destroyed or modified
2. THE DevOps_Agent_Terraform_Module SHALL use Terraform state isolation so that other module Terraform executions do not affect the DevOps Agent resources
3. THE DevOps_Agent_Terraform_Module SHALL NOT use `timestamp()` or other force-recreation triggers on the Agent_Space or IAM role resources, ensuring idempotent `terraform apply` runs do not recreate existing resources
4. IF the DevOps Agent infrastructure has already been provisioned, THEN subsequent `prepare-environment troubleshooting/devops-agent` runs SHALL be idempotent and not recreate existing resources
5. THE DevOps Agent resources SHALL only be destroyed when the learner explicitly runs the cleanup script for the DevOps Agent module

### Requirement 9: AWS DevOps Agent CLI Setup and Automated Testing

**User Story:** As a workshop developer, I want the DevOps Agent CLI to be installed and configured in the lab environment, and I want automated test hooks that validate the setup and troubleshooting outcomes, so that the workshop content can be continuously tested.

#### Acceptance Criteria

1. THE DevOps Agent setup page SHALL include steps to patch the AWS CLI with the DevOps Agent service model using `aws configure add-model --service-model "file://devopsagent.json" --service-name devopsagent`, following the CLI onboarding guide pattern
2. THE DevOps Agent setup page SHALL include a verification step using `aws devopsagent list-agent-spaces` with the `--endpoint-url` and `--region us-east-1` flags to confirm the CLI is functional
3. THE DevOps Agent setup pages SHALL include test hook scripts in `website/docs/troubleshooting/devops-agent-setup/tests/` that validate the Agent Space was created, IAM roles exist, and the EKS access entry is configured
4. THE DevOps Agent tab content in `alb_fix_1.md` SHALL use the `aws devopsagent` CLI commands (e.g., `invoke-agent` or `create-chat`/`stream-message`) to initiate troubleshooting, so that the automated test framework can extract and execute these commands
5. THE DevOps Agent tab content SHALL include test hook scripts in `website/docs/troubleshooting/alb/tests/` that validate the troubleshooting outcome (subnets tagged with `kubernetes.io/role/elb=1`, ingress has an ALB address) after the DevOps Agent completes remediation
6. COMMANDS in the DevOps Agent tab that are interactive or non-deterministic (e.g., waiting for agent response) SHALL use the `test=false` annotation to skip them in automated testing, while verification commands SHALL remain testable
7. THE `hook-suite.sh` for the DevOps Agent setup module SHALL follow the existing pattern (calling `prepare-environment` in the `after()` function) to reset the environment after tests complete
