# Nothing consumes these. Labs discover Identity Center through data sources and the
# naming convention below, so that a lab's Terraform is identical whether this module
# ran or an administrator set Identity Center up by hand.
#
# They exist to make a pre-provisioning run legible in the build log, which is the
# only place anyone looks when an event comes up without a working sign-in.
output "idc_instance_arn" {
  description = "ARN of the Identity Center instance that was created or adopted"
  value       = tolist(data.aws_ssoadmin_instances.main.arns)[0]
}

# Which of the two provisioning paths ran. Worth a line in the build log on its own:
# the symptoms of "CloudFormation was supposed to create the instance but the ARN
# never reached Terraform" and "Terraform created one it should not have" are
# otherwise indistinguishable from the resources that come out the far end.
output "idc_instance_source" {
  description = "Whether the Identity Center instance came from outside Terraform (Workshop Studio team stack) or was created by this module"
  value       = local.idc_externally_provisioned ? "external (${var.idc_instance_arn})" : "created by this module"
}

output "idc_identity_store_id" {
  description = "Identity store holding the workshop user and group"
  value       = local.identity_store_id
}

output "idc_user_name" {
  description = "Sign-in name of the Argo CD administrator"
  value       = aws_identitystore_user.argocd_admin.user_name
}

output "idc_group_name" {
  description = "Group that capabilities map to the Argo CD ADMIN role"
  value       = aws_identitystore_group.argocd_admins.display_name
}

output "idc_secret_name" {
  description = "Secrets Manager secret holding the activated {username,password}"
  value       = aws_secretsmanager_secret.argocd_admin.name
}
