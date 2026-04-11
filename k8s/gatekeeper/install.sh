#!/bin/bash
set -euo pipefail

echo "Adding Gatekeeper Helm repo..."
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update

echo "Installing Gatekeeper..."
helm install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace

echo "Waiting for Gatekeeper pods..."
kubectl wait --for=condition=ready pod -l control-plane=controller-manager \
  -n gatekeeper-system --timeout=120s

echo "Gatekeeper installation complete."
kubectl get pods -n gatekeeper-system