# VPC_CNI_IAM_ROLE_NAME="eksctl-eks-workshop-addon-vpc-cni-Role1-n85u3l0IhDSv"

kubectl delete namespace cni-tshoot
attached_policies=$(aws iam list-attached-role-policies --role-name $VPC_CNI_IAM_ROLE_NAME --query 'AttachedPolicies[*].PolicyArn' --output text)

is_policy_exist=0

for policy in ${attached_policies[@]}; do
    if [ "$policy" == "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" ]; then
        is_policy_exist=1
    else
        aws iam detach-role-policy --role-name $VPC_CNI_IAM_ROLE_NAME --policy-arn $policy
    fi
done

if [ $is_policy_exist -eq 0 ]; then
    logmessage "Attaching back AmazonEKS_CNI_Policy policy into VPC CNI addon role"

    aws iam attach-role-policy --role-name $VPC_CNI_IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
fi

nodes=$(aws eks list-nodegroups --cluster-name $EKS_CLUSTER_NAME --query 'nodegroups' --output text)
deleted_nodes=()

logmessage "Reverting EKS managed nodegroup configuration"
for node in ${nodes[@]}; do
    if [[ "$node" != "default" && "$node" != "cni_troubleshooting_nodes" ]]; then
        logmessage "Deleting nodegroup $node"
        aws eks delete-nodegroup --cluster-name $EKS_CLUSTER_NAME --nodegroup-name $node
        deleted_nodes+=$node
    fi
done

logmessage "Waiting for EKS managed nodegroup to be deleted"
for deleted_node in ${deleted_nodes[@]}; do
    logmessage "waiting for deletion of $deleted_node"
    aws eks wait nodegroup-deleted --cluster-name $EKS_CLUSTER_NAME --nodegroup-name $deleted_node
done

DEFAULT_CONFIG='{"enableNetworkPolicy":"true","env":{"ENABLE_POD_ENI":"true","ENABLE_PREFIX_DELEGATION":"true","POD_SECURITY_GROUP_ENFORCING_MODE":"standard"},"nodeAgent":{"enablePolicyEventLogs":"true"}}'
CURRENT_CONFIG=$(aws eks describe-addon --addon-name vpc-cni --cluster-name $EKS_CLUSTER_NAME --query addon.configurationValues --output text | jq --sort-keys -c .)

if [ $DEFAULT_CONFIG != $CURRENT_CONFIG ]; then
    logmessage "Reverting VPC CNI config to default"
    addons_status=$(aws eks describe-addon --addon-name vpc-cni --cluster-name $EKS_CLUSTER_NAME --query addon.status --output text)
    while [ $addons_status == "UPDATING" ]; do
        logmessage "Waiting for VPC CNI addons status to not be in UPDATING"
        sleep 60
        addons_status=$(aws eks describe-addon --addon-name vpc-cni --cluster-name $EKS_CLUSTER_NAME --query addon.status --output text)
    done

    aws eks update-addon --addon-name vpc-cni --cluster-name $EKS_CLUSTER_NAME --service-account-role-arn $VPC_CNI_IAM_ROLE_ARN --configuration-values $DEFAULT_CONFIG
fi


