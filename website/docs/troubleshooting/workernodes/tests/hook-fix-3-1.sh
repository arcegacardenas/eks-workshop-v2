set -Eeuo pipefail

before() {
  echo "noop"
}

after() {
  sleep 10

# Function to check node status
check_node_status() {
    local timeout=600  # 10 minutes
    local interval=15  # Check every 15 seconds
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        # Capture the output and redirect stderr to stdout
        node_status=$(kubectl get nodes --selector=eks.amazonaws.com/nodegroup=new_nodegroup_3 -o wide 2>&1)
        
        # Check if any nodes exist
        if [[ -z "$node_status" ]] || echo "$node_status" | grep -q "No resources found"; then
            echo "No nodes found yet in nodegroup new_nodegroup_3. Waiting... (${elapsed}s/${timeout}s)"
            sleep $interval
            elapsed=$((elapsed + interval))
            continue
        fi

        # Get the node name if it exists
        NODE_NAME=$(echo "$node_status" | awk 'NR>1 {print $1}' | head -n1)
        
        if [ -z "$NODE_NAME" ]; then
            echo "Could not get node name. Waiting... (${elapsed}s/${timeout}s)"
            sleep $interval
            elapsed=$((elapsed + interval))
            continue
        fi

        echo "Found node: $NODE_NAME"

        # Check if there are any nodes in NotReady state
        if echo "$node_status" | grep -q "NotReady"; then
            echo "Success: Node in NotReady state found as expected"
            return 0
        fi

        echo "Node found but not in NotReady state. Waiting... (${elapsed}s/${timeout}s)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    echo "Timeout reached. Node did not appear or transition to NotReady state within ${timeout} seconds"
    echo "Current node status:"
    echo "$node_status"
    return 1
}

# Call the function
check_node_status
status=$?

if [ $status -ne 0 ]; then
    echo "Node status check failed"
    exit 1
fi

}

"$@"
