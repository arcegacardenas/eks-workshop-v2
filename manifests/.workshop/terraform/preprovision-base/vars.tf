# tflint-ignore: terraform_unused_declarations
variable "eks_cluster_id" {
  description = "EKS cluster name, used as the per-environment suffix for the Identity Center user, group and secret"
  type        = string
}

# tflint-ignore: terraform_unused_declarations
variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = any
}

# Set when something outside Terraform has already provisioned the Identity Center
# instance for this environment, which at a Workshop Studio event is the team
# CloudFormation stack (a native `AWS::SSO::Instance`).
#
# Creating an instance is the one part of this module the Workshop Studio SCP
# denies: `sso:CreateInstance` is refused for every role in a team account except
# the deployment role CloudFormation itself runs as, so a native resource in the
# team stack succeeds where this module's `aws sso-admin create-instance` cannot.
# See the comment at the top of main.tf for how the two paths differ.
#
# Empty means nothing else owns an instance, so this module creates one: that is
# the GitHub Actions module tests and anyone running `make pre-provision` in their
# own account. Both paths converge afterwards -- the user, group, secret and
# activation below are identical, and labs discover all of it through data sources
# either way.
variable "idc_instance_arn" {
  description = "ARN of an Identity Center instance provisioned for this environment outside Terraform. Empty means this module creates and owns one."
  type        = string
  default     = ""
}
