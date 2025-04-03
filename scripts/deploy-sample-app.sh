#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying Sample Microservices Application...${NC}"

# Check for kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

# Check if namespace exists, create if it doesn't
if ! kubectl get namespace sample-app &> /dev/null; then
    echo -e "${YELLOW}Creating sample-app namespace...${NC}"
    kubectl apply -f ../kubernetes/sample-app/namespace.yaml
fi

echo -e "${YELLOW}Deploying application config...${NC}"
kubectl apply -f ../kubernetes/sample-app/deploy-all.yaml

echo -e "${YELLOW}Deploying frontend microservice...${NC}"
kubectl apply -f ../kubernetes/sample-app/frontend/configmap.yaml
kubectl apply -f ../kubernetes/sample-app/frontend/deployment.yaml
kubectl apply -f ../kubernetes/sample-app/frontend/service.yaml
kubectl apply -f ../kubernetes/sample-app/frontend/servicemonitor.yaml

echo -e "${YELLOW}Deploying API microservice...${NC}"
kubectl apply -f ../kubernetes/sample-app/api/deployment.yaml
kubectl apply -f ../kubernetes/sample-app/api/service.yaml
kubectl apply -f ../kubernetes/sample-app/api/servicemonitor.yaml

echo -e "${YELLOW}Deploying database microservice...${NC}"
kubectl apply -f ../kubernetes/sample-app/database/deployment.yaml
kubectl apply -f ../kubernetes/sample-app/database/service.yaml
kubectl apply -f ../kubernetes/sample-app/database/servicemonitor.yaml

echo -e "${GREEN}Waiting for deployments to be ready...${NC}"
kubectl -n sample-app rollout status deployment/frontend
kubectl -n sample-app rollout status deployment/api
kubectl -n sample-app rollout status deployment/database

echo -e "${GREEN}Sample application deployed successfully!${NC}"
echo -e "${YELLOW}To access the application, run:${NC}"
echo -e "  kubectl -n sample-app port-forward svc/frontend 8080:80"
echo -e "${YELLOW}Then open:${NC} http://localhost:8080"
echo -e ""
echo -e "${YELLOW}To generate load, visit:${NC}"
echo -e "  http://localhost:8080/api/load/5  (intensity 1-10)"
echo -e "  http://localhost:8080/api/items   (API endpoint)"
echo -e ""
echo -e "${YELLOW}For metrics, port-forward and visit:${NC}"
echo -e "  kubectl -n sample-app port-forward svc/frontend 8080:8080"
echo -e "  http://localhost:8080/metrics"