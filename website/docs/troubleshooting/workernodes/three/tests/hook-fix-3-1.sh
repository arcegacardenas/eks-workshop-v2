set -Eeuo pipefail

before() {
  echo "noop"
}

after() {
  sleep 10

  not_ready_node=$(kubectl get nodes --selector=eks.amazonaws.com/nodegroup=new_nodegroup_3)

  if [[ $not_ready_node == *"NotReady"* ]]; then
    # Found "No resources found" - this is what we want, so exit successfully
    echo "Success: Node in NotReady state found as expected"    
    exit 0
  fi  
  # If we get here, it means we found resources when we shouldn't have
  >&2 echo "expecting node in 'NotReady'. Found node in Ready or did not find any nodes in new_nodegroup_3"
  exit 1

}

"$@"
