output "environment_variables" {
  description = "Environment variables to be added to the IDE shell"
  value = {
    DEVOPS_AGENT_SPACE_NAME      = local.agent_space_name
    DEVOPS_AGENT_ROLE_ARN        = aws_iam_role.agent_space_role.arn
    DEVOPS_AGENT_WEBAPP_ROLE_ARN = aws_iam_role.webapp_admin_role.arn
    DEVOPS_AGENT_REGION          = "us-east-1"
    DEVOPS_AGENT_ENDPOINT        = local.endpoint_url
    SSM_ACTIVATION_ID            = aws_ssm_activation.hybrid.id
    SSM_ACTIVATION_CODE          = aws_ssm_activation.hybrid.activation_code
  }
}
