#!/bin/bash

set -e

logmessage "Restoring public subnet tags..."

# Function to create ftags for subnets ids
remove_tags_from_subnets() {
    subnets_vpc=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=*Public*" "Name=tag:created-by,Values=eks-workshop-v2" --query 'Subnets[*].SubnetId' --output text)
    #logmessage "subnets_vpc: $subnets_vpc"
    
        
#remove tag from subnets with AWS cli
    for subnet_id in $subnets_vpc; do
        #logmessage "public subnets: $subnet_id"
        aws ec2 create-tags --resources "$subnet_id" --tags Key=kubernetes.io/role/elb,Value='1' || logmessage "Failed to create tag from subnet $subnet_id"
    done
    return 0
}

remove_tags_from_subnets

kubectl delete ingress -n ui ui --ignore-not-found --wait=false

logmessage "Uninstalling helm chart aws-load-balancer-controller..."
helm uninstall aws-load-balancer-controller -n kube-system --ignore-not-found 2>/dev/null || true