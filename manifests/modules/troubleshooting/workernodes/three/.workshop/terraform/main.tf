##To do - added nodegroup name as variable and change change to use the variable instead.


#Custom LT issue
#can create user-data that generates kernel panic or stop kubelet
#Simulate a kernel panic: You can run the following command on the node to simulate a kernel panic:
# sudo bash -c "echo 1 > /proc/sys/kernel/sysrq && echo c > /proc/sysrq-trigger"


#-config=/etc/kubernetes/kubelet/config.json --config-dir=/etc/kubernetes/kubelet/config
#misconfiguring /etc/resolv.conf and then restarting kubelet if needed will cause 'unknown status. 
# or iptables
# or stopping kubelet

# in order to supply kubelet extra args, I need to add an AMI ID for custome AMI. If I do this, eventhough i set managed nodegroup desired count
# to 0, with custom AMI, ASG will have desired count set to 1 automatically causing the nodegroup creation to fail. 
# I can try to use userdata instead to break kubelet config. But this won't work b/c user data runs before bootstrap and will bring
# all values back to normal. 


##update: after 15 minutes, asg desired count is set to 0: 
#At 2024-09-26T22:58:50Z a user request update of AutoScalingGroup constraints to min: 0, max: 3, desired: 0 changing 
#the desired capacity from 1 to 0. At 2024-09-26T22:58:58Z an instance was taken out of service in response to a difference 
#between desired and actual capacity, shrinking the capacity from 1 to 0. At 2024-09-26T22:58:58Z instance i-0d6ffcbe624dd63d6
# was selected for termination.

#2024 September 26, 06:58:58 PM -04:00
#

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
}

/* locals {
  tags = {
    module = "troubleshooting"
  }
}
 */
data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_id
}

# data "aws_region" "current" {}

/* data "aws_eks_node_group" "default" {
  cluster_name    = data.aws_eks_cluster.cluster.id
  node_group_name = "default"
} */

/* data "aws_vpc" "selected" {
  tags = {
    created-by = "eks-workshop-v2"
    env        = var.addon_context.eks_cluster_id
  }
} */

/* locals {
  cluster_name    = data.aws_eks_cluster.cluster.name
  node_group_name = "default"
}
 */
# data "aws_eks_node_group" "default" {
#   cluster_name    = local.cluster_name
#   node_group_name = local.node_group_name
# }

/* output "debug_locals" {
  value = {
    cluster_name    = local.cluster_name
    node_group_name = local.node_group_name
  }
} */

/* data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${data.aws_eks_cluster.cluster.version}/amazon-linux-2/recommended/image_id"
} */




# resource "null_resource" "get_instance_id" {
#   provisioner "local-exec" {
#     command = "aws eks describe-nodegroup --cluster-name ${data.aws_eks_node_group.default.cluster_name} --nodegroup-name ${data.aws_eks_node_group.default.node_group_name} --query 'nodegroup.instances[0].instanceId' --output text > instance_id.txt || echo 'Error fetching instance ID' >&2"
#   }
# }

# data "local_file" "instance_id" {
#   filename   = "instance_id.txt"
#   depends_on = [null_resource.get_instance_id]
# }

# resource "null_resource" "get_ami_id" {
#   provisioner "local-exec" {
#     command = "aws ec2 describe-instances --instance-ids ${trimspace(data.local_file.instance_id.content)} --query 'Reservations[0].Instances[0].ImageId' --output text > ami_id.txt"
#   }
#   depends_on = [data.local_file.instance_id]
# }

# data "local_file" "ami_id" {
#   filename   = "ami_id.txt"
#   depends_on = [null_resource.get_ami_id]
# }

# output "node_group_ami_id" {
#   value = trimspace(data.local_file.ami_id.content)
# }


# output "debug_instance_id" {
#   value = data.local_file.instance_id.content
# }
# output "debug_ami_id" {
#   value = data.local_file.ami_id.content
# }

# output "debug_cluster_name" {
#   value = data.aws_eks_node_group.default.cluster_name
# }

# output "debug_node_group_name" {
#   value = data.aws_eks_node_group.default.node_group_name
# }



# data "aws_ssm_parameter" "eks_ami_release_version" {
#   name = "/aws/service/eks/optimized-ami/${data.aws_eks_cluster.cluster.version}/amazon-linux-2/recommended/release_version"
# }


data "aws_subnets" "private" {
  tags = {
    created-by = "eks-workshop-v2"
    env        = var.addon_context.eks_cluster_id
  }
  filter {
    name   = "tag:Name"
    values = ["*Private*"]
  }
}


#creating IAM role for SSM access
resource "aws_iam_role" "new_nodegroup_3" {
  name = "new_nodegroup_3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

#attaching all needed policies including ssm

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.new_nodegroup_3.name
}

# resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   role       = aws_iam_role.new_nodegroup_3.name
# }

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.new_nodegroup_3.name
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.new_nodegroup_3.name
}


###for ec2 vpc endpoint issue
# # Create a new security group for the VPC endpoint
# resource "aws_security_group" "endpoint_sg" {
#   name        = "eks-endpoint-sg"
#   description = "Security group for EC2 VPC endpoint"
#   vpc_id      = data.aws_vpc.selected.id

#   # No ingress rules - all ingress is blocked

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "eks-endpoint-sg"
#   }
# }

# # Create the EC2 VPC endpoint
# resource "aws_vpc_endpoint" "ec2" {
#   vpc_id            = data.aws_vpc.selected.id
#   service_name      = "com.amazonaws.${data.aws_region.current.name}.ec2"
#   vpc_endpoint_type = "Interface"

#   security_group_ids = [
#     aws_security_group.endpoint_sg.id,
#   ]

#   subnet_ids = data.aws_subnets.private.ids

#   private_dns_enabled = true

#   tags = {
#     Name = "ec2-vpc-endpoint"
#   }
# }

# # VPC Endpoint policy
# resource "aws_vpc_endpoint_policy" "ec2_endpoint_policy" {
#   vpc_endpoint_id = aws_vpc_endpoint.ec2.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AllowAll"
#         Effect = "Allow"
#         Principal = {
#           AWS = "*"
#         }
#         Action   = "*"
#         Resource = "*"
#       }
#     ]
#   })

#   depends_on = [aws_vpc_endpoint.ec2]
# }

# Create a new launch template to add ec2 names
resource "aws_launch_template" "new_launch_template" {
  name = "new_nodegroup_3"

  instance_type = "m5.large"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "troubleshooting-three-${var.eks_cluster_id}"
    }
  }
  lifecycle {
    create_before_destroy = true
  }

}

#create launch template with misconfigured kubelet extra args config
#
# resource "aws_launch_template" "eks_with_ssm" {
#   name = "eksctl-eks-workshop-new_nodegroup_3"
#   #  image_id = data.aws_ssm_parameter.eks_ami.value
#   user_data = base64encode(<<-EOF
# MIME-Version: 1.0
# Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

# --==MYBOUNDARY==
# Content-Type: text/x-shellscript; charset="us-ascii"

# #!/bin/bash
# # set -ex
# # /etc/eks/bootstrap.sh ${data.aws_eks_cluster.cluster.id} \
# #   --dns-cluster-ip 172.20.0.11 \
# #   --kubelet-extra-args '--max-pods=1' \
# #   --use-max-pods false

# #   #--dns-cluster-ip ["169.254.20.11" ,"172.20.0.11"]
# #   #--max-pods false
# #   #--kubelet-extra-args \
# #   # "--max-pods=1"
# #   # "--cluster-dns=169.254.20.11,172.20.0.11"

# # yes > /dev/null &


# #  iptables -A INPUT -s 127.0.0.0/8 -j DROP
# #  iptables -A OUTPUT -s 127.0.0.0/8 -j DROP
# #  iptables -A FORWARD -s 127.0.0.0/8 -j DROP

# # Install cronie (which provides cron)
# #yum install -y cronie

# # Start and enable the crond service
# #systemctl start crond
# #systemctl enable crond

# # Add the cron job to stop kubelet every 3 minutes
# #echo "*/3 * * * * systemctl stop kubelet" > /var/spool/cron/root

# # Restart crond to ensure the new job is picked up
# #systemctl restart crond



# # Install the 'at' utility if it's not already installed
# yum install -y at

# # Start the atd service
# #systemctl start atd
# #systemctl enable atd

# # Schedule the iptables command to run after 3 minutes
# #echo "iptables -A INPUT -s 127.0.0.0/8 -j DROP" | at now + 3 minutes

# # You can add more commands here if needed


# --==MYBOUNDARY==--  
#   EOF
#   )

#   instance_type = "t3.medium"
#   tag_specifications {
#     resource_type = "instance"
#     tags = {
#       Name = "troubleshooting-three-${data.aws_eks_cluster.cluster.id}"
#     }
#   }
# }


#Create New nodegroup with launch template
resource "aws_eks_node_group" "new_nodegroup_3" {
  cluster_name    = data.aws_eks_cluster.cluster.id
  node_group_name = "new_nodegroup_3"
  node_role_arn   = aws_iam_role.new_nodegroup_3.arn
  subnet_ids      = data.aws_subnets.private.ids

  scaling_config {
    desired_size = 0
    max_size     = 2
    min_size     = 0
  }

  launch_template {
    id      = aws_launch_template.new_launch_template.id
    version = aws_launch_template.new_launch_template.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    #aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read_only,
    aws_iam_role_policy_attachment.ssm_managed_instance_core,
  ]
}

# ###modify aws-auth and reboot instance (have to create a script to make sure aws-auth node arn is 
# # fixed before evicting or else pod termination will get stuck)
# resource "null_resource" "modify_aws_auth_and_reboot" {
#   provisioner "local-exec" {
#     interpreter = ["/bin/bash", "-c"]
#     command     = <<-EOT
#       echo "Waiting for 75 seconds before modifying aws-auth..."
#       sleep 90

#       # Get the current aws-auth ConfigMap
#       kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth-temp.yaml

#       # Use sed to modify the specific role mapping
#       # The role ARN is escaped to handle special characters
#       sed -i 's|rolearn: ${replace(aws_iam_role.new_nodegroup_3.arn, "/", "\\/")}|rolearn: ${replace(replace(aws_iam_role.new_nodegroup_3.arn, "role/", "role/x"), "/", "\\/")}|' aws-auth-temp.yaml

#       # Apply the modified ConfigMap
#       kubectl apply -f aws-auth-temp.yaml

#       # Clean up the temporary file
#       rm aws-auth-temp.yaml

#       echo "Waiting for another 10 seconds before rebooting the instance..."
#       sleep 5

#       # Find the instance ID of the running node in the new node group
#       INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:eks:nodegroup-name,Values=new_nodegroup_3" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId" --output text)

#       if [ -n "$INSTANCE_ID" ]; then
#         echo "Found instance ID: $INSTANCE_ID. Rebooting..."
#         aws ec2 reboot-instances --instance-ids $INSTANCE_ID
#         echo "Reboot command sent for instance $INSTANCE_ID"
#       else
#         echo "No running instances found in the new_nodegroup_3 node group"
#       fi
#     EOT

#     environment = {
#       KUBECONFIG         = "/home/ec2-user/.kube/config"
#       AWS_DEFAULT_REGION = "us-west-2" # Replace with your AWS region
#     }
#   }

#   depends_on = [null_resource.increase_desired_count, aws_eks_node_group.new_nodegroup_3]
# }





resource "null_resource" "increase_desired_count" {
  #trigger to properly capture the cluster and node group names for both create and destroy operations
  triggers = {
    cluster_name    = data.aws_eks_cluster.cluster.id
    node_group_name = aws_eks_node_group.new_nodegroup_3.node_group_name
  }
  provisioner "local-exec" {
    command = "aws eks update-nodegroup-config --cluster-name ${data.aws_eks_cluster.cluster.id} --nodegroup-name new_nodegroup_3 --scaling-config minSize=0,maxSize=2,desiredSize=1"
    when    = create
    environment = {
      AWS_DEFAULT_REGION = "us-west-2" # Replace with any region
    }
    #This will eventually transition newnodegroup into Degraded state. Need to find out how to bring it back to healthy state.
  }
  provisioner "local-exec" {
    when    = destroy
    command = "aws eks update-nodegroup-config --cluster-name ${self.triggers.cluster_name} --nodegroup-name ${self.triggers.node_group_name} --scaling-config minSize=0,maxSize=2,desiredSize=0"
  }
  depends_on = [aws_eks_node_group.new_nodegroup_3]
}


# resource "null_resource" "modify_aws_auth_and_reboot" {
#   provisioner "local-exec" {
#     interpreter = ["/bin/bash", "-c"]
#     command     = <<-EOT
#       echo "Waiting for a new node to appear..."
#       while true; do
#         NODE_INFO=$(kubectl get nodes --selector=eks.amazonaws.com/nodegroup=new_nodegroup_3 -o jsonpath='{range .items[*]}{.metadata.name} {.spec.providerID}{"\n"}{end}' | head -n 1)
#         if [ -n "$NODE_INFO" ]; then
#           NODE_NAME=$(echo $NODE_INFO | cut -d' ' -f1)
#           INSTANCE_ID=$(echo $NODE_INFO | cut -d' ' -f2 | cut -d'/' -f5)
#           echo "Found a new node: $NODE_NAME with Instance ID: $INSTANCE_ID"
#           break
#         fi
#         echo "No new nodes found yet. Waiting 5 seconds..."
#         sleep 5
#       done

#       echo "Adding taint to prevent non-DaemonSet pods from being scheduled..."
#       ##this is to ensure pods do not cause deployment/cleanup issues
#       kubectl taint nodes $NODE_NAME dedicated=experimental:NoSchedule

#       echo "Waiting for the node to be in Ready state..."
#       while true; do
#         if kubectl get nodes $NODE_NAME -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
#           echo "Node $NODE_NAME is now Ready"
#           break
#         fi
#         echo "Node not Ready yet. Waiting 5 seconds..."
#         sleep 5
#       done

#       echo "Modifying aws-auth ConfigMap..."
#       # Get the current aws-auth ConfigMap
#       kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth-temp.yaml

#       # Use sed to modify the specific role mapping
#       # The role ARN is escaped to handle special characters
#       sed -i 's|rolearn: ${replace(aws_iam_role.new_nodegroup_3.arn, "/", "\\/")}|rolearn: ${replace(replace(aws_iam_role.new_nodegroup_3.arn, "role/", "role/x"), "/", "\\/")}|' aws-auth-temp.yaml

#       # adding random users
#       sed -i '
#   /mapRoles/a \
#     mapUsers: |
#     - groups:
#       - system:masters
#       userarn: arn:aws:iam::111122223333:user/admin
#       username: admin
#     - groups:
#       - eks-console-dashboard-restricted-access-group
#       userarn: arn:aws:iam::444455556666:user/my-user
#       username: my-user
# ' aws-auth-temp.yaml

#       # Apply the modified ConfigMap
#       kubectl apply -f aws-auth-temp.yaml

#       # Clean up the temporary file
#       rm aws-auth-temp.yaml

#       echo "aws-auth ConfigMap updated successfully."

#       if [ -n "$INSTANCE_ID" ]; then
#         echo "Rebooting instance $INSTANCE_ID..."
#         sleep 10
#         aws ec2 reboot-instances --instance-ids $INSTANCE_ID
#         echo "Reboot command sent for instance $INSTANCE_ID"
#       else
#         echo "No instance ID found for the node $NODE_NAME"
#       fi
#     EOT

#     environment = {
#       KUBECONFIG         = "/home/ec2-user/.kube/config"
#       AWS_DEFAULT_REGION = "us-west-2" # Replace with your AWS region
#     }
#   }

#   depends_on = [null_resource.increase_desired_count, aws_eks_node_group.new_nodegroup_3]
# }

resource "null_resource" "modify_aws_auth_and_reboot" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "Waiting for a new node to appear..."
      while true; do
        NODE_INFO=$(kubectl get nodes --selector=eks.amazonaws.com/nodegroup=new_nodegroup_3 -o jsonpath='{range .items[*]}{.metadata.name} {.spec.providerID}{"\n"}{end}' | head -n 1)
        if [ -n "$NODE_INFO" ]; then
          NODE_NAME=$(echo $NODE_INFO | cut -d' ' -f1)
          INSTANCE_ID=$(echo $NODE_INFO | cut -d' ' -f2 | cut -d'/' -f5)
          echo "Found a new node: $NODE_NAME with Instance ID: $INSTANCE_ID"
          break
        fi
        echo "No new nodes found yet. Waiting 5 seconds..."
        sleep 5
      done

      echo "Adding taint to prevent non-DaemonSet pods from being scheduled..."
      kubectl taint nodes $NODE_NAME dedicated=experimental:NoSchedule

      echo "Waiting for the node to be in Ready state..."
      while true; do
        if kubectl get nodes $NODE_NAME -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
          echo "Node $NODE_NAME is now Ready"
          break
        fi
        echo "Node not Ready yet. Waiting 5 seconds..."
        sleep 5
      done

      echo "Modifying aws-auth ConfigMap..."
      kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth-temp.yaml

      # Modify the role ARN and add the new user
      yq eval '.data.mapRoles |= sub("rolearn: ${replace(aws_iam_role.new_nodegroup_3.arn, "/", "\\/")}", "rolearn: ${replace(replace(aws_iam_role.new_nodegroup_3.arn, "role/", "role/x"), "/", "/")}")' -i aws-auth-temp.yaml
      yq eval '.data.mapUsers += "- groups:\n  - system:masters\n  userarn: arn:aws:iam::111122223333:user/new-admin-user\n  username: admin-user\n"' -i aws-auth-temp.yaml

      kubectl apply -f aws-auth-temp.yaml
      rm aws-auth-temp.yaml

      echo "aws-auth ConfigMap updated successfully."

      if [ -n "$INSTANCE_ID" ]; then
        echo "Rebooting instance $INSTANCE_ID..."
        sleep 20
        aws ec2 reboot-instances --instance-ids $INSTANCE_ID
        echo "Reboot command sent for instance $INSTANCE_ID"
        sleep 10
      else
        echo "No instance ID found for the node $NODE_NAME"
      fi
    EOT

    environment = {
      KUBECONFIG         = "/home/ec2-user/.kube/config"
      AWS_DEFAULT_REGION = "us-west-2"
    }
  }

  depends_on = [null_resource.increase_desired_count, aws_eks_node_group.new_nodegroup_3]
}



# ###THIS IS A WORKING ONE - JUST W/OUT SAMPLE USER ADDED TO CONFIGMAP

# resource "null_resource" "modify_aws_auth_and_reboot" {
#   provisioner "local-exec" {
#     interpreter = ["/bin/bash", "-c"]
#     command     = <<-EOT
#       echo "Waiting for a new node to appear..."
#       while true; do
#         NODE_INFO=$(kubectl get nodes --selector=eks.amazonaws.com/nodegroup=new_nodegroup_3 -o jsonpath='{range .items[*]}{.metadata.name} {.spec.providerID}{"\n"}{end}' | head -n 1)
#         if [ -n "$NODE_INFO" ]; then
#           NODE_NAME=$(echo $NODE_INFO | cut -d' ' -f1)
#           INSTANCE_ID=$(echo $NODE_INFO | cut -d' ' -f2 | cut -d'/' -f5)
#           echo "Found a new node: $NODE_NAME with Instance ID: $INSTANCE_ID"
#           break
#         fi
#         echo "No new nodes found yet. Waiting 5 seconds..."
#         sleep 5
#       done

#       echo "Adding taint to prevent non-DaemonSet pods from being scheduled..."
#       ##this is to ensure pods do not cause deployment/cleanup issues
#       kubectl taint nodes $NODE_NAME dedicated=experimental:NoSchedule

#       echo "Waiting for the node to be in Ready state..."
#       while true; do
#         if kubectl get nodes $NODE_NAME -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
#           echo "Node $NODE_NAME is now Ready"
#           break
#         fi
#         echo "Node not Ready yet. Waiting 5 seconds..."
#         sleep 5
#       done

#       echo "Modifying aws-auth ConfigMap..."
#       # Get the current aws-auth ConfigMap
#       kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth-temp.yaml

#       # Use sed to modify the specific role mapping
#       # The role ARN is escaped to handle special characters
#       sed -i 's|rolearn: ${replace(aws_iam_role.new_nodegroup_3.arn, "/", "\\/")}|rolearn: ${replace(replace(aws_iam_role.new_nodegroup_3.arn, "role/", "role/x"), "/", "\\/")}|' aws-auth-temp.yaml

#       # adding random users
#   #     sed -i '/mapRoles/a\
#   # mapUsers: |\
#   #   - groups:\
#   #     - system:masters\
#   #     userarn: arn:aws:iam::111122223333:user/admin\
#   #     username: admin\
#   #   - groups:\
#   #     - eks-console-dashboard-restricted-access-group\
#   #     userarn: arn:aws:iam::444455556666:user/my-user\
#   #     username: my-user' aws-auth-temp.yaml

#       # Apply the modified ConfigMap
#       kubectl apply -f aws-auth-temp.yaml

#       # Clean up the temporary file
#       rm aws-auth-temp.yaml

#       echo "aws-auth ConfigMap updated successfully."

#       if [ -n "$INSTANCE_ID" ]; then
#         echo "Rebooting instance $INSTANCE_ID..."
#         sleep 10
#         aws ec2 reboot-instances --instance-ids $INSTANCE_ID
#         echo "Reboot command sent for instance $INSTANCE_ID"
#       else
#         echo "No instance ID found for the node $NODE_NAME"
#       fi
#     EOT

#     environment = {
#       KUBECONFIG         = "/home/ec2-user/.kube/config"
#       AWS_DEFAULT_REGION = "us-west-2" # Replace with your AWS region
#     }
#   }

#   depends_on = [null_resource.increase_desired_count, aws_eks_node_group.new_nodegroup_3]
# }



###modifying default nodegroup size to 0 during creation and nodegroup size back to default during destory. 


# resource "null_resource" "ensure_node_group_size" {
#   triggers = {
#     cluster_name    = data.aws_eks_cluster.cluster.id
#     node_group_name = "default"
#     current_min     = data.aws_eks_node_group.default.scaling_config[0].min_size
#     current_max     = data.aws_eks_node_group.default.scaling_config[0].max_size
#     current_desired = data.aws_eks_node_group.default.scaling_config[0].desired_size
#   }

# # This provisioner runs during create and update
# provisioner "local-exec" {
#   command = <<-EOT
#   if [ "${self.triggers.current_min}" -ne 0 ] || [ "${self.triggers.current_desired}" -ne 0 ]; then
#     aws eks update-nodegroup-config \
#       --cluster-name ${self.triggers.cluster_name} \
#       --nodegroup-name ${self.triggers.node_group_name} \
#       --scaling-config minSize=0,maxSize=${self.triggers.current_max},desiredSize=0
#   fi
# EOT
# }

# This provisioner runs during destroy
#   provisioner "local-exec" {
#     when    = destroy
#     command = <<-EOT
#       CURRENT_CONFIG=$(aws eks describe-nodegroup \
#         --cluster-name ${self.triggers.cluster_name} \
#         --nodegroup-name ${self.triggers.node_group_name} \
#         --query 'nodegroup.scalingConfig.[minSize,maxSize,desiredSize]' \
#         --output text)

#       MIN_SIZE=$(echo $CURRENT_CONFIG | awk '{print $1}')
#       MAX_SIZE=$(echo $CURRENT_CONFIG | awk '{print $2}')
#       DESIRED_SIZE=$(echo $CURRENT_CONFIG | awk '{print $3}')

#       if [ "$MIN_SIZE" -ne 3 ] || [ "$MAX_SIZE" -ne 6 ] || [ "$DESIRED_SIZE" -ne 3 ]; then
#         aws eks update-nodegroup-config \
#           --cluster-name ${self.triggers.cluster_name} \
#           --nodegroup-name ${self.triggers.node_group_name} \
#           --scaling-config minSize=3,maxSize=6,desiredSize=3
#       fi
#     EOT
#   }
# }
