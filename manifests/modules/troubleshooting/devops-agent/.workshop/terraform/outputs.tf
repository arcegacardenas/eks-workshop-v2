output "environment_variables" {
  description = "Environment variables to be added to the IDE shell"
  value = {
    DEVOPS_AGENT_SPACE_NAME = local.agent_space_name
    DEVOPS_AGENT_REGION     = "us-east-1"
  }
}
