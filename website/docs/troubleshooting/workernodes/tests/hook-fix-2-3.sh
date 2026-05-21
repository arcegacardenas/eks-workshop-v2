set -Eeuo pipefail

before() {
  echo "noop"
}

after() {
  local timeout=900
  local interval=10
  local elapsed=0

  while [ $elapsed -lt $timeout ]; do
    export node_output=$(kubectl get nodes --selector=eks.amazonaws.com/nodegroup=new_nodegroup_2 2>&1)

    if [[ $node_output == *".internal"* ]]; then
      echo "Success: Node found in nodegroup new_nodegroup_2"
      exit 0
    fi

    echo "Waiting for node to join... (${elapsed}s/${timeout}s)"
    sleep $interval
    elapsed=$((elapsed + interval))
  done

  >&2 echo "Did not find any nodes when expecting a node"
  exit 1
}

"$@"
