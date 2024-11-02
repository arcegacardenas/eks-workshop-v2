set -Eeuo pipefail

before() {
  echo "noop"
}

after() {
  sleep 5

  aws_node_pod=$(kubectl get pods --namespace=kube-system --selector=k8s-app=aws-node -o wide | grep $NEW_NODEGROUP_3_NODE_NAME)

  if [[ $aws_node_pod == *"PodInitializing"* ]]; then
    echo "Success: Found aws-node pod in PodInitializing state"
    # Found "PodInitializing" - this is what we want, so exit successfully
    exit 0
  fi  
  # If we get here, it means we found is a different state
  >&2 echo "Found pod in other state than 'PodInitializing'"
  exit 1

}

"$@"
