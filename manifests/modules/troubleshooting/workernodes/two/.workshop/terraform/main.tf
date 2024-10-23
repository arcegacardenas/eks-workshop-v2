##To do - added nodegroup name as variable and change change to use the variable instead.



#Bootstrap failure due to vpc endpoint issue
#could create issue due to subnet issue possiblly or ACL/network issue
# - either do this and have nodes not show up instead of transitioning to not-ready OR try to create stress on node resources. For this one, there needs to be a follow up on what could cause it or how to troubleshoot further and prevent such things. 
# The only potential problem with network issue and node not showing up is that troubleshooting may be similar to first one... I don't think it's too similar though except for initial diagnosis. 
#enable cloudwatch logs?? for troubleshooting labs?

#Simulate a kernel panic: You can run the following command on the node to simulate a kernel panic:
# sudo bash -c "echo 1 > /proc/sys/kernel/sysrq && echo c > /proc/sysrq-trigger"


#
#Does SSM work on original worker nodeS?


#create a new managed nodegroup. first set it to desired 0 and use script to increase. (try to find a way node name. May be better to create launch template to make is easier to identity ec2 instance)
# create a new subnet 10.42.192.0/19  (may need to update cluster config with new subnet?)

### create a route table and associate with above subnet. The subnet's route table will only have local route and not route to the internet. 




#Custom LT issue

terraform {
  required_providers {
    #    kubectl = {
    #      source  = "gavinbunney/kubectl"
    #      version = ">= 1.14"
    #    }
  }
}



provider "aws" {
  region = "us-west-2"
  alias  = "Oregon"

  default_tags {
    tags = {
      Workshop = "EKS Workshop"
      Module   = "Troubleshooting"
      Issue    = "Two"
    }
  }
}

locals {
  tags = {
    module = "troubleshooting"
  }
}


# data "aws_vpc" "selected" {
#   tags = {
#     created-by = "eks-workshop-v2"
#     env        = var.addon_context.eks_cluster_id
#   }
# }

# data "aws_subnets" "public" {
#   tags = {
#     created-by = "eks-workshop-v2"
#     env        = var.addon_context.eks_cluster_id
#   }
# }
#   filter {
#     name   = "tag:Name"
#     values = ["*Public*"]
#   }

data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_id
}

data "aws_eks_node_group" "default" {
  cluster_name    = data.aws_eks_cluster.cluster.id
  node_group_name = "default"
}

# data "aws_subnet" "default_nodegroup_subnet" {
#   id = tolist(data.aws_eks_node_group.default.subnet_ids)[0]
# }

# data "aws_nat_gateway" "default_nodegroup_nat" {
#   subnet_id = data.aws_subnet.default_nodegroup_subnet.id
# }

data "aws_vpc" "selected" {
  tags = {
    created-by = "eks-workshop-v2"
    env        = var.addon_context.eks_cluster_id
  }
}

data "aws_nat_gateways" "cluster_nat_gateways" {
  #  vpc_id = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
  vpc_id = data.aws_vpc.selected.id

  tags = {
    created-by = "eks-workshop-v2"
    env        = var.addon_context.eks_cluster_id
  }
  filter {
    name   = "state"
    values = ["available"]
  }

  # filter {
  #   name   = "tag:created-by"
  #   values = ["eks-workshop-v2"]
  # }
}

# Create a new subnet
resource "aws_subnet" "new_subnet" {
  vpc_id            = data.aws_vpc.selected.id
  cidr_block        = "10.42.192.0/19"
  availability_zone = "us-west-2a"

  tags = {
    Name = "eksctl-${data.aws_eks_cluster.cluster.id}/NewPrivateSubnetUSWEST2A"
  }

  lifecycle {
    create_before_destroy = true
  }
}
# Create a new route table
resource "aws_route_table" "new_route_table" {
  vpc_id = data.aws_vpc.selected.id

  lifecycle {
    create_before_destroy = true
  }
}
# Associate the new subnet with the new route table
resource "aws_route_table_association" "new_subnet_association" {
  subnet_id      = aws_subnet.new_subnet.id
  route_table_id = aws_route_table.new_route_table.id
}

# Create a new launch template to add ec2 names
resource "aws_launch_template" "new_launch_template" {
  name = "new_nodegroup_2"

  instance_type = "t3.medium"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "troubleshooting-two-${var.eks_cluster_id}"
    }
  }
  lifecycle {
    create_before_destroy = true
  }

}
# Create a new managed node group
resource "aws_eks_node_group" "new_nodegroup_2" {
  cluster_name    = data.aws_eks_cluster.cluster.name
  node_group_name = "new_nodegroup_2"
  node_role_arn   = data.aws_eks_node_group.default.node_role_arn
  subnet_ids      = [aws_subnet.new_subnet.id]
  launch_template {
    id      = aws_launch_template.new_launch_template.id
    version = aws_launch_template.new_launch_template.latest_version
  }

  scaling_config {
    desired_size = 0
    max_size     = 2
    min_size     = 0
  }

  depends_on = [
    aws_launch_template.new_launch_template,
    aws_subnet.new_subnet,
    aws_route_table_association.new_subnet_association,
  ]
  # # Allow Terraform to delete the node group
  # force_delete = true

  # combine local tags with resource-specific tags
  tags = merge(local.tags, {
    Name = "troubleshooting-new-node-group"
  })
  # helps manage updates more smoothly
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_autoscaling_group" "new_nodegroup_2" {
  name       = aws_eks_node_group.new_nodegroup_2.resources[0].autoscaling_groups[0].name
  depends_on = [aws_eks_node_group.new_nodegroup_2]
}



resource "null_resource" "increase_desired_count" {
  #trigger to properly capture the cluster and node group names for both create and destroy operations
  triggers = {
    cluster_name    = data.aws_eks_cluster.cluster.id
    node_group_name = aws_eks_node_group.new_nodegroup_2.node_group_name
  }
  provisioner "local-exec" {
    command = "aws eks update-nodegroup-config --cluster-name ${data.aws_eks_cluster.cluster.id} --nodegroup-name new_nodegroup_2 --scaling-config minSize=0,maxSize=2,desiredSize=1"

    when = create
    # environment = {
    #   AWS_DEFAULT_REGION = "us-west-2" # Replace with any region
    # }
  }
  # provisioner "local-exec" {
  #   when    = destroy
  #   command = "aws eks update-nodegroup-config --cluster-name ${self.triggers.cluster_name} --nodegroup-name ${self.triggers.node_group_name} --scaling-config minSize=0,maxSize=2,desiredSize=0"
  # }
  depends_on = [aws_eks_node_group.new_nodegroup_2]
}

resource "null_resource" "wait_for_instance" {
  depends_on = [null_resource.increase_desired_count]

  provisioner "local-exec" {
    command = <<EOT
      while [ "$(aws ec2 describe-instances --filters "Name=tag:aws:autoscaling:groupName,Values=${data.aws_autoscaling_group.new_nodegroup_2.name}" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].InstanceId' --output text)" == "" ]; do
        echo "Waiting for instance to be in running state..."
        sleep 10
      done
    EOT
  }
}

data "aws_instances" "new_nodegroup_2_instances" {
  instance_tags = {
    "aws:autoscaling:groupName" = data.aws_autoscaling_group.new_nodegroup_2.name
  }
  instance_state_names = ["running", "pending"]
  depends_on           = [null_resource.wait_for_instance]
}


# data "aws_instances" "new_nodegroup_2_instances" {
#   instance_tags = {
#     "aws:autoscaling:groupName" = data.aws_autoscaling_group.new_nodegroup_2.name
#   }
#   instance_state_names = ["running"]
#   depends_on           = [null_resource.increase_desired_count]
# }
