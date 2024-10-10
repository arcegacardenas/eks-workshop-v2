variable "ami_release_version" {
  description = "Default EKS AMI release version for node groups"
  type        = string
  default     = "1.30.0-20240625"
}
#^^ adding for testing

module "lab" {
  source = "./lab"

  eks_cluster_id            = local.eks_cluster_id
  eks_cluster_version       = local.eks_cluster_version
  cluster_security_group_id = local.cluster_security_group_id
  addon_context             = local.addon_context
  tags                      = local.tags
  resources_precreated      = var.resources_precreated
  #adding ami_release_version for test
  ami_release_version       = var.ami_release_version
}

locals {
  environment_variables = try(module.lab.environment_variables, [])
}