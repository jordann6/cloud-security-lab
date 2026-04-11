#!/bin/bash
set -euo pipefail

echo "Adding Falco Helm repo..."
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

echo "Installing Falco with Sidekick..."
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  -f values.yaml \
  --set driver.kind=ebpf

echo "Waiting for Falco pods..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=falco \
  -n falco --timeout=120s

echo "Falco installation complete."
kubectl get pods -n falco