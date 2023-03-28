#!/usr/bin/env bash
set -eux -o pipefail -o errexit

if [ '!' -d etc/helm/pachyderm ]; then
    echo "Run from a pachyderm repo"
    exit 1
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Compile Go binaries for deploying Pachyderm to K8s, that's why we need GOOS=linux
CGO_ENABLED=0 GOOS=linux go build ./src/server/cmd/pachctl
CGO_ENABLED=0 GOOS=linux go build ./src/server/cmd/pachd
CGO_ENABLED=0 GOOS=linux go build ./src/server/cmd/worker
CGO_ENABLED=0 GOOS=linux go build ./src/server/cmd/pachtf
CGO_ENABLED=0 GOOS=linux go build -o worker_init ./etc/worker

# Build local docker images
docker build . -f ./Dockerfile.pachd -t pachyderm/pachd:local
docker build . -f ./Dockerfile.worker -t pachyderm/worker:local
# load these docker images into kind
kind load docker-image pachyderm/pachd:local pachyderm/worker:local --name local-pach || true
# don't want to commit these to git
rm pachctl pachd worker pachtf worker_init

# Re-deploy Pachyderm via helm
helm upgrade --install pachyderm etc/helm/pachyderm -f $SCRIPT_DIR/values.yaml
kubectl rollout status deployment pachd

# This pachctl is the version we actually use to run commands interactively
CGO_ENABLED=0 go install ./src/server/cmd/pachctl
pachctl config set context kind-local-pach --overwrite <<EOF
{"pachd_address": "grpc://localhost:80", "session_token": "fa03ee2e5be041aba4a7b5e4ed3db814"}
EOF
pachctl config set active-context kind-local-pach

until pachctl version &> /dev/null
do
  echo "retry pachctl version until success"
  sleep 1
done
echo "Pachyderm is ready!"
