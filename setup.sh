#!/usr/bin/env bash
set -eux -o pipefail -o errexit

if [ '!' -d etc/helm/pachyderm ]; then
    echo "Run from a pachyderm repo"
    exit 1
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
echo $SCRIPT_DIR

# start fresh by deleting existing cluster and clearing docker volumes
kind delete cluster --name=local-pach
docker system prune --volumes -f

# create kind cluster with custom port mappings
cat <<EOF | kind create cluster --name=local-pach --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
            kubeletExtraArgs:
                node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 30080
        hostPort: 80
        protocol: TCP
      - containerPort: 30660 # test-cluster-1 pachd
        hostPort: 30660
        protocol: TCP
      - containerPort: 30669 # test-cluster-1 loki
        hostPort: 30669
        protocol: TCP
      - containerPort: 30670 # test-cluster-2 pachd
        hostPort: 30670
        protocol: TCP
      - containerPort: 30679 # test-cluster-2 loki
        hostPort: 30679
        protocol: TCP
      - containerPort: 30680 # test-cluster-3 pachd
        hostPort: 30680
        protocol: TCP
      - containerPort: 30689 # test-cluster-3 loki
        hostPort: 30689
        protocol: TCP
      - containerPort: 30690 # test-cluster-4 pachd
        hostPort: 30690
        protocol: TCP
      - containerPort: 30699 # test-cluster-4 loki
        hostPort: 30699
        protocol: TCP
      - containerPort: 31650 # enterprise cluster
        hostPort: 31650
        protocol: TCP
      - containerPort: 31659 # enterprise loki
        hostPort: 31659
        protocol: TCP
EOF

# Apply minio
kubectl apply -f etc/testing/minio.yaml --namespace=default

# coredns ConfigMap
# cat <<EOF | kubectl apply -f -
# apiVersion: v1
# kind: ConfigMap
# metadata:
#     name: coredns
#     namespace: kube-system
# data:
#     Corefile: |
#         .:53 {
#             errors
#             health {
#                lameduck 5s
#             }
#             ready
#             kubernetes cluster.local in-addr.arpa ip6.arpa {
#                pods insecure
#                fallthrough in-addr.arpa ip6.arpa
#                ttl 0
#             }
#             prometheus :9153
#             forward . /etc/resolv.conf {
#                max_concurrent 1000
#             }
#             cache 30
#             loop
#             reload
#             loadbalance
#         }
# EOF

# Assume these keys already exist
# TODO generate new keys each time?
# kubectl create secret tls envoy-tls --cert=$SCRIPT_DIR/tls/tls.crt --key=$SCRIPT_DIR/tls/tls.key

# metrics api
# kubectl apply -f $SCRIPT_DIR/metrics-server.yaml
# helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install --set args={--kubelet-insecure-tls} metrics-server metrics-server/metrics-server --namespace kube-system

# build pachyderm docker images, load into kind, and deploy pachyderm
$SCRIPT_DIR/rebuild.sh
