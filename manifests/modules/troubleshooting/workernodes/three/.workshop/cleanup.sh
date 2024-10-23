#!/bin/bash

# Clean up any resources created by the user OUTSIDE of Terraform here

# All stdout output will be hidden from the user
# To display a message to the user:
# logmessage "Deleting some resource...."


#!/bin/bash

#MAY need to adde a script that deletes nodegroup.. for some reason, destroy environment didn't delete it.


INSTANCE_ID=$(kubectl get nodes --selector=eks.amazonaws.com/nodegroup=new_nodegroup_3 -o jsonpath='{.items[*].spec.providerID}' 2>/dev/null | cut -d '/' -f5 | cut -d ' ' -f1 | head -n1)

if [ -z "$INSTANCE_ID" ]; then
    logmessage "Ignore this message if this is your first time preparing the environment for this section. No instances found in nodegroup new_nodegroup_3. Please be sure to update aws-auth configmap and remove role for new_nodegroup_3 if you have not already."
else
    logmessage "Found instance ID: $INSTANCE_ID"

    INSTANCE_PROFILE_NAME=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text 2>/dev/null | awk -F'/' '{print $NF}')

    if [ -z "$INSTANCE_PROFILE_NAME" ]; then
        logmessage "Error: Could not find IAM instance profile name for instance $INSTANCE_ID"
    else
        logmessage "Found instance profile name: $INSTANCE_PROFILE_NAME"

        ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --query 'InstanceProfile.Roles[0].RoleName' --output text 2>/dev/null)

        if [ -z "$ROLE_NAME" ]; then
            logmessage "Error: Could not find role name for instance profile $INSTANCE_PROFILE_NAME"
        else
            logmessage "Found role name: $ROLE_NAME"

            logmessage "Modifying aws-auth ConfigMap..."
            if kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth-temp.yaml; then
                # Remove 'x' from role name and remove the sample user
                yq eval '
                    .data.mapRoles |= sub("rolearn: arn:aws:iam::[0-9]+:role/x" + strenv(ROLE_NAME), "rolearn: arn:aws:iam::[0-9]+:role/" + strenv(ROLE_NAME)) |
                    .data.mapUsers |= select(. != null) |
                    (.data.mapUsers | select(. != null)) -= "- groups:\n  - system:masters\n  userarn: arn:aws:iam::111122223333:user/new-admin-user\n  username: admin-user\n"
                ' -i aws-auth-temp.yaml

                logmessage "Debugging: Showing contents of modified aws-auth ConfigMap"
                cat aws-auth-temp.yaml

                logmessage "Applying modified ConfigMap..."
                if kubectl apply -f aws-auth-temp.yaml; then
                    logmessage "aws-auth ConfigMap updated successfully."
                else
                    logmessage "Error: Failed to apply modified aws-auth ConfigMap."
                fi

                rm aws-auth-temp.yaml
            else
                logmessage "Error: Failed to retrieve aws-auth ConfigMap."
            fi
        fi
    fi
fi

logmessage "Script execution completed."


###THIS IS A WORKING CLEANUP
# # Attempt to get the instance ID, but don't fail if no nodes are found
# INSTANCE_ID=$(kubectl get nodes --selector=eks.amazonaws.com/nodegroup=new_nodegroup_3 -o jsonpath='{.items[*].spec.providerID}' 2>/dev/null | cut -d '/' -f5 | cut -d ' ' -f1 | head -n1)

# if [ -z "$INSTANCE_ID" ]; then
#     logmessage "No instances found in nodegroup new_nodegroup_3. Please be sure to update aws-auth configmap and remove role for new_nodegroup_3 if you have not already."
# else
#     logmessage "Found instance ID: $INSTANCE_ID"

#     INSTANCE_PROFILE_NAME=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text 2>/dev/null | awk -F'/' '{print $NF}')

#     if [ -z "$INSTANCE_PROFILE_NAME" ]; then
#         logmessage "Error: Could not find IAM instance profile name for instance $INSTANCE_ID"
#     else
#         logmessage "Found instance profile name: $INSTANCE_PROFILE_NAME"

#         ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --query 'InstanceProfile.Roles[0].RoleName' --output text 2>/dev/null)

#         if [ -z "$ROLE_NAME" ]; then
#             logmessage "Error: Could not find role name for instance profile $INSTANCE_PROFILE_NAME"
#         else
#             logmessage "Found role name: $ROLE_NAME"

#             logmessage "Modifying aws-auth ConfigMap..."
#             if kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth-temp.yaml; then
#                 awk -v role="$ROLE_NAME" '
#                 {
#                     if ($1 == "rolearn:") {
#                         split($2, arr, "/")
#                         if (arr[2] == "x" role) {
#                             sub("/x" role, "/" role, $2)
#                             print "      rolearn: "$2" # Modified"
#                         } else {
#                             print $0
#                         }
#                     } else {
#                         print $0
#                     }
#                 }
#                 ' aws-auth-temp.yaml > aws-auth-modified.yaml

#                 logmessage "Debugging: Showing contents of aws-auth-modified.yaml"
#                 cat aws-auth-modified.yaml

#                 logmessage "Applying modified ConfigMap..."
#                 if kubectl apply -f aws-auth-modified.yaml; then
#                     logmessage "aws-auth ConfigMap updated successfully."
#                 else
#                     logmessage "Error: Failed to apply modified aws-auth ConfigMap."
#                 fi

#                 #rm aws-auth-temp.yaml aws-auth-modified.yaml
#             else
#                 logmessage "Error: Failed to retrieve aws-auth ConfigMap."
#             fi
#         fi
#     fi
# fi

# logmessage "Script execution completed."





# logmessage "Identifying the specific node ARN..."

# # Get the instance ID of the node in the specified nodegroup
# INSTANCE_ID=$(kubectl get nodes --selector=eks.amazonaws.com/nodegroup=new_nodegroup_3 -o jsonpath='{.items[0].spec.providerID}' | cut -d '/' -f5)

# if [ -z "$INSTANCE_ID" ]; then
#     logmessage "Error: No instance found in nodegroup new_nodegroup_3"
#     exit 1
# fi

# logmessage "Found instance ID: $INSTANCE_ID"

# # Get the IAM role ARN for this instance
# ROLE_ARN=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text | sed 's/instance-profile/role/')

# if [ -z "$ROLE_ARN" ]; then
#     logmessage "Error: Could not find IAM role ARN for instance $INSTANCE_ID"
#     exit 1
# fi

# logmessage "Found role ARN: $ROLE_ARN"

# # Extract the role name from the role ARN
# ROLE_NAME=$(echo $ROLE_ARN | awk -F'/' '{print $NF}')

# logmessage "Extracted role name: $ROLE_NAME"

# logmessage "Modifying aws-auth ConfigMap..."
# # Get the current aws-auth ConfigMap
# kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth-temp.yaml

# # Use awk to find and modify the specific role ARN with 'x' in front of it, preserving the account ID
# awk -v role="$ROLE_NAME" '
# {
#     if ($1 == "rolearn:" && $2 ~ role) {
#         split($2, arr, "/")
#         if (arr[2] ~ /^x/) {
#             sub(/\/x/, "/", $2)
#             print "    "$0" # Modified"
#         } else {
#             print $0
#         }
#     } else {
#         print $0
#     }
# }
# ' aws-auth-temp.yaml > aws-auth-modified.yaml

# # Apply the modified ConfigMap
# kubectl apply -f aws-auth-modified.yaml

# # Clean up the temporary files
# #rm aws-auth-temp.yaml aws-auth-modified.yaml

# logmessage "aws-auth ConfigMap updated successfully."




# logmessage "Deleting some resources. Reverting configmap...."

# logmessage "Modifying aws-auth ConfigMap..."
# # Get the current aws-auth ConfigMap
# kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth-temp.yaml

# # Use awk to find and modify the role ARN with 'x' in front of it, preserving the account ID
# awk '
# {
#     if ($1 == "rolearn:") {
#         split($2, arr, "/")
#         if (arr[2] ~ /^x/) {
#             sub(/\/x/, "/", $2)
#         }
#     }
#     print $0
# }
# ' aws-auth-temp.yaml > aws-auth-modified.yaml

# # Apply the modified ConfigMap
# kubectl apply -f aws-auth-modified.yaml

# # Clean up the temporary files
# rm aws-auth-temp.yaml aws-auth-modified.yaml

# logmessage "aws-auth ConfigMap updated successfully."



# logmessage "Modifying aws-auth ConfigMap..."
# # Get the current aws-auth ConfigMap
# kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth-temp.yaml

# # Use sed to modify the specific role mapping
# # The role ARN is escaped to handle special characters
# sed -i 's|rolearn: ${replace(replace(aws_iam_role.eks_node_group_role.arn, "role/x", "role/"), "/", "\\/")}|rolearn: ${replace(aws_iam_role.eks_node_group_role.arn, "/", "\\/")}|' aws-auth-temp.yaml

# # Apply the modified ConfigMap
# kubectl apply -f aws-auth-temp.yaml

# # Clean up the temporary file
# #rm aws-auth-temp.yaml

# logmessage "aws-auth ConfigMap updated successfully."






