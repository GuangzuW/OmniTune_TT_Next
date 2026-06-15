#!/bin/bash
# Spin up the whole OmniTune platform on a local kind cluster.
# Prereqs: docker, kind, kubectl, helm.
set -e
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
CLUSTER=omnitune

echo "==> Creating kind cluster (if absent)"
kind get clusters | grep -q "^${CLUSTER}$" || kind create cluster --name "$CLUSTER"

echo "==> Building images"
docker build -t omnitune-aggregator:latest -f "$ROOT/backend/Dockerfile" "$ROOT/backend"
docker build -t omnitune-user-sync:latest -f "$ROOT/backend/Dockerfile.user_sync" "$ROOT/backend"
docker build -t omnitune-web:latest "$ROOT/web"

echo "==> Loading images into kind"
for img in omnitune-aggregator omnitune-user-sync omnitune-web; do
  kind load docker-image "${img}:latest" --name "$CLUSTER"
done

echo "==> Installing ingress-nginx"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=120s || true

echo "==> Installing OmniTune Helm release"
helm upgrade --install omni "$ROOT/deploy/helm/omnitune" \
  --set image.pullPolicy=IfNotPresent \
  --wait --timeout 180s || true

echo ""
echo "Done. Add '127.0.0.1 omnitune.local' to your hosts file, then:"
echo "  kubectl get pods"
echo "  open http://omnitune.local  (web)"
echo "Observability: install kube-prometheus-stack and set serviceMonitor.enabled=true"
