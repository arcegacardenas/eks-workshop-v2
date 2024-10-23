set -Eeuo pipefail

before() {
  echo "noop"
}

after() {
  sleep 20

  output_message=$(kubectl get nodes --selector=eks.amazonaws.com/nodegroup=new_nodegroup_1)

  if [[ $output_message == *"No resources found"* ]]; then
    >&2 echo "text Not found: Failed deploy module due to unexpected output. Expecting 'No resources found'"
    exit 1
  fi  

  EXIT_CODE=0
}

"$@"
