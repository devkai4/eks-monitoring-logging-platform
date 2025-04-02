#!/bin/bash
set -e

echo "Installing kube-prometheus-stack to EKS cluster..."

# Create monitoring namespace
kubectl apply -f namespace.yaml
echo "Created monitoring namespace"

# Add Prometheus community Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
echo "Added Prometheus community Helm repository"

# Install kube-prometheus-stack using custom values
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values values.yaml \
  --timeout 10m

echo "Prometheus stack installation complete!"
echo "Waiting for pods to be ready..."
kubectl -n monitoring wait --for=condition=Ready pods --all --timeout=300s

# Display access information
echo ""
echo "=== Access Information ==="
echo "Prometheus:"
echo "  kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090"
echo "  Then access http://localhost:9090 in your browser"
echo ""
echo "Grafana:"
echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  Then access http://localhost:3000 in your browser"
echo "  Default credentials: admin / admin"
echo ""
echo "AlertManager:"
echo "  kubectl port-forward -n monitoring svc/prometheus-alertmanager 9093:9093"
echo "  Then access http://localhost:9093 in your browser"