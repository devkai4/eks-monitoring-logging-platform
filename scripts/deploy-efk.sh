#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying EFK Stack to EKS Cluster${NC}"

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

# Create the logging namespace
echo -e "${YELLOW}Creating logging namespace...${NC}"
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

# Deploy Elastic Operator
echo -e "${YELLOW}Deploying Elastic Operator...${NC}"
kubectl apply -f kubernetes/elasticsearch/elastic-operator.yaml
echo -e "${GREEN}Waiting for Elastic Operator to be ready...${NC}"
kubectl -n elastic-system wait --for=condition=ready pod -l control-plane=elastic-operator --timeout=120s

# Deploy Elasticsearch
echo -e "${YELLOW}Deploying Elasticsearch...${NC}"
kubectl apply -f kubernetes/elasticsearch/elasticsearch.yaml
echo -e "${GREEN}Elasticsearch deployment initiated. This may take a few minutes...${NC}"

# Deploy Kibana
echo -e "${YELLOW}Deploying Kibana...${NC}"
kubectl apply -f kubernetes/kibana/kibana.yaml
echo -e "${GREEN}Kibana deployment initiated...${NC}"

# Deploy Fluent Bit
echo -e "${YELLOW}Deploying Fluent Bit...${NC}"
kubectl apply -f kubernetes/fluentbit/fluent-bit-configmap.yaml
kubectl apply -f kubernetes/fluentbit/fluent-bit.yaml
echo -e "${GREEN}Fluent Bit deployment initiated...${NC}"

# Wait for Elasticsearch to be ready
echo -e "${YELLOW}Waiting for Elasticsearch to be ready (this may take a few minutes)...${NC}"
echo -e "${YELLOW}You can check the status with: kubectl get pods -n logging${NC}"
kubectl -n logging wait --for=condition=ready pod -l elasticsearch.k8s.elastic.co/cluster-name=elasticsearch --timeout=600s || {
    echo -e "${RED}Elasticsearch pods did not become ready in time. Please check the status manually with: kubectl get pods -n logging${NC}"
    echo -e "${YELLOW}Continuing with deployment...${NC}"
}

# Wait for Kibana to be ready
echo -e "${YELLOW}Waiting for Kibana to be ready...${NC}"
kubectl -n logging wait --for=condition=ready pod -l kibana.k8s.elastic.co/name=kibana --timeout=300s || {
    echo -e "${RED}Kibana pods did not become ready in time. Please check the status manually with: kubectl get pods -n logging${NC}"
    echo -e "${YELLOW}Continuing with deployment...${NC}"
}

# Wait for Fluent Bit to be ready
echo -e "${YELLOW}Waiting for Fluent Bit to be ready...${NC}"
kubectl -n logging wait --for=condition=ready pod -l app=fluent-bit --timeout=120s || {
    echo -e "${RED}Fluent Bit pods did not become ready in time. Please check the status manually with: kubectl get pods -n logging${NC}"
    echo -e "${YELLOW}Continuing with deployment...${NC}"
}

# Get access information
echo -e "${GREEN}EFK Stack deployment completed!${NC}"
echo -e "${YELLOW}Access Information:${NC}"

# Get Elasticsearch credentials
PASSWORD=$(kubectl get secret -n logging elasticsearch-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode)
echo -e "${GREEN}Elasticsearch:${NC}"
echo "  Username: elastic"
echo "  Password: $PASSWORD"
echo "  Port-forward command: kubectl port-forward service/elasticsearch-es-http 9200:9200 -n logging"
echo "  Access URL: http://localhost:9200"

echo -e "${GREEN}Kibana:${NC}"
echo "  Port-forward command: kubectl port-forward service/kibana-kb-http 5601:5601 -n logging"
echo "  Access URL: http://localhost:5601"
echo "  Username: elastic"
echo "  Password: $PASSWORD"

echo -e "${GREEN}Fluent Bit:${NC}"
echo "  Status: $(kubectl get pods -n logging -l app=fluent-bit --no-headers | wc -l) instances running"
echo "  Metrics URL (via port-forward): http://localhost:2020/api/v1/metrics/prometheus"
echo "  Port-forward command: kubectl port-forward service/fluent-bit 2020:2020 -n logging"

echo -e "${YELLOW}Initial Setup Instructions:${NC}"
echo "1. Access Kibana at http://localhost:5601 (after port-forwarding)"
echo "2. Login with username 'elastic' and the password shown above"
echo "3. Navigate to 'Stack Management' > 'Index Patterns'"
echo "4. Create an index pattern 'logstash-*' with @timestamp as the time field"
echo "5. Go to 'Discover' to start exploring your logs"

echo -e "${GREEN}EFK Stack deployment and setup complete!${NC}"