#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if required tools are installed
echo -e "${YELLOW}Checking required tools...${NC}"
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl not found. Please install kubectl first.${NC}" >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}helm not found. Please install helm first.${NC}" >&2; exit 1; }

# Get environment from command line
ENV=${1:-dev}
echo -e "${GREEN}Installing monitoring stack in environment: ${ENV}${NC}"

# Check if kubeconfig is configured
echo -e "${YELLOW}Checking Kubernetes connection...${NC}"
kubectl get nodes > /dev/null || { echo -e "${RED}Cannot connect to Kubernetes cluster. Please check your kubeconfig.${NC}" >&2; exit 1; }

# Create namespaces
echo -e "${YELLOW}Creating namespaces...${NC}"
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repositories
echo -e "${YELLOW}Adding Helm repositories...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add elastic https://helm.elastic.co
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

# Create Elasticsearch credentials secret
echo -e "${YELLOW}Creating Elasticsearch credentials...${NC}"
ELASTIC_PASSWORD=$(openssl rand -base64 12)
kubectl create secret generic elasticsearch-credentials \
  --from-literal=username=elastic \
  --from-literal=password=$ELASTIC_PASSWORD \
  --namespace logging \
  --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}Elasticsearch user: elastic, password: $ELASTIC_PASSWORD${NC}"

# Install Prometheus and Grafana
echo -e "${YELLOW}Installing Prometheus & Grafana...${NC}"
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -f kubernetes/prometheus/values.yaml \
  --namespace monitoring --create-namespace

# Install Elasticsearch
echo -e "${YELLOW}Installing Elasticsearch...${NC}"
helm upgrade --install elasticsearch elastic/elasticsearch \
  -f kubernetes/elasticsearch/values.yaml \
  --namespace logging

# Wait for Elasticsearch to be ready
echo -e "${YELLOW}Waiting for Elasticsearch to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=elasticsearch-master --timeout=300s --namespace logging

# Install Kibana
echo -e "${YELLOW}Installing Kibana...${NC}"
helm upgrade --install kibana elastic/kibana \
  -f kubernetes/kibana/values.yaml \
  --namespace logging

# Install Fluent Bit
echo -e "${YELLOW}Installing Fluent Bit...${NC}"
helm upgrade --install fluent-bit fluent/fluent-bit \
  -f kubernetes/fluentbit/values.yaml \
  --namespace logging

# Deploy dashboards
echo -e "${YELLOW}Deploying Grafana dashboards...${NC}"
./scripts/deploy-dashboards.sh

# Deploy sample application
echo -e "${YELLOW}Deploying sample application...${NC}"
./scripts/deploy-sample-app.sh

# Wait for deployments to be ready
echo -e "${YELLOW}Waiting for deployments to be ready...${NC}"
kubectl rollout status deployment/prometheus-grafana -n monitoring --timeout=300s
kubectl rollout status deployment/sample-app --timeout=300s

# Get access information
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${YELLOW}Access Information:${NC}"
echo -e "${GREEN}Grafana:${NC}"
echo "  Username: admin"
echo "  Password: admin"
echo "  Port-forward command: kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
echo ""
echo -e "${GREEN}Prometheus:${NC}"
echo "  Port-forward command: kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring"
echo ""
echo -e "${GREEN}Kibana:${NC}"
echo "  Port-forward command: kubectl port-forward svc/kibana-kibana 5601:5601 -n logging"
echo ""
echo -e "${GREEN}Elasticsearch:${NC}"
echo "  Username: elastic"
echo "  Password: $ELASTIC_PASSWORD"
echo "  Port-forward command: kubectl port-forward svc/elasticsearch-master 9200:9200 -n logging"