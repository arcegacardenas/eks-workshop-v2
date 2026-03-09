set -Eeuo pipefail

before() {
  echo "noop"
}

after() {
  sleep 20

  number_of_subnets=$(aws ec2 describe-subnets --filters 'Name=tag:kubernetes.io/role/elb,Values=1' --query 'Subnets[].SubnetId' --output json | jq 'length')
  
  echo "# of subnets tagged: ${number_of_subnets}"
  
  if [[ "$number_of_subnets" -eq 0 ]]; then
    >&2 echo "Error: No subnets tagged with kubernetes.io/role/elb=1"
    exit 1
  fi

  output_message=$(kubectl describe ingress/ui -n ui)

  if [[ $output_message == *"Failed build model due to couldn't auto-discover subnets"* ]]; then
    >&2 echo "Error: Ingress still shows subnet discovery failure"
    exit 1
  fi
}

"$@"
