set -Eeuo pipefail

before() {
  echo "noop"
}

after() {
  sleep 180

  if kubectl get pods --selector="app=app-private" 2>&1 | grep -q "Running"; then
    echo "Success: The pod is now in running state"
    exit 0
  fi  

  >&2 echo "pod is not in running state, when expected to be running"
  exit 1
}



"$@"