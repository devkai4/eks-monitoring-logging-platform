#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying alert configuration to EKS Cluster${NC}"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install it and try again.${NC}"
    exit 1
fi

# Check kubectl access
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}Cannot connect to Kubernetes cluster. Please check your kubeconfig.${NC}"
    exit 1
fi

# Create the monitoring namespace if it doesn't exist
echo -e "${YELLOW}Ensuring monitoring namespace exists...${NC}"
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Deploy alert rules
echo -e "${YELLOW}Deploying Prometheus alert rules...${NC}"
kubectl apply -f kubernetes/prometheus/rules/critical-alerts.yaml
kubectl apply -f kubernetes/prometheus/rules/warning-alerts.yaml
kubectl apply -f kubernetes/prometheus/rules/info-alerts.yaml
kubectl apply -f kubernetes/prometheus/rules/alerts.yaml

# Deploy AlertManager configuration
echo -e "${YELLOW}Deploying AlertManager configuration...${NC}"
kubectl apply -f kubernetes/alertmanager/alertmanager-config.yaml

echo -e "${GREEN}Alert configuration has been deployed successfully${NC}"
echo -e "${YELLOW}Please update the following values in the AlertManager configuration:${NC}"
echo "1. Slack webhook URL: kubernetes/alertmanager/alertmanager-config.yaml - global.slack_api_url"
echo "2. Email SMTP settings: kubernetes/alertmanager/alertmanager-config.yaml - global.smtp_* fields"
echo "3. PagerDuty service key: kubernetes/alertmanager/alertmanager-config.yaml - receivers[name=pagerduty].pagerduty_configs.service_key"

echo -e "${YELLOW}To check that alerts are configured correctly:${NC}"
echo "1. Check Prometheus alerts: kubectl port-forward svc/prometheus-operated 9090:9090 -n monitoring"
echo "   Open http://localhost:9090/alerts in your browser"
echo "2. Check AlertManager configuration: kubectl port-forward svc/alertmanager-operated 9093:9093 -n monitoring"
echo "   Open http://localhost:9093/#/status in your browser"

echo -e "${GREEN}Alert configuration deployment complete!${NC}"