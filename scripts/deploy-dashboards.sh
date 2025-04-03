#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying Grafana Dashboards...${NC}"

# Check for kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

# Project directory
PROJECT_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
DASHBOARDS_DIR="${PROJECT_DIR}/kubernetes/grafana/dashboards"
TEMP_FILE="/tmp/dashboards.yaml"

# Check if monitoring namespace exists
if ! kubectl get namespace monitoring &> /dev/null; then
    echo -e "${YELLOW}Creating monitoring namespace...${NC}"
    kubectl create namespace monitoring
fi

# Copy dashboards.yaml to temp file
cp ${DASHBOARDS_DIR}/dashboards.yaml ${TEMP_FILE}

# Replace placeholders with actual dashboard content
echo -e "${YELLOW}Processing dashboard files...${NC}"

# Cluster Overview
CLUSTER_OVERVIEW=$(cat ${DASHBOARDS_DIR}/cluster-overview.json)
sed -i "s|{{DASHBOARD_CLUSTER_OVERVIEW}}|${CLUSTER_OVERVIEW}|g" ${TEMP_FILE}

# Node Details
NODE_DETAILS=$(cat ${DASHBOARDS_DIR}/node-details.json)
sed -i "s|{{DASHBOARD_NODE_DETAILS}}|${NODE_DETAILS}|g" ${TEMP_FILE}

# Application Performance
APP_PERFORMANCE=$(cat ${DASHBOARDS_DIR}/application-performance.json)
sed -i "s|{{DASHBOARD_APPLICATION_PERFORMANCE}}|${APP_PERFORMANCE}|g" ${TEMP_FILE}

# Service SLA
SERVICE_SLA=$(cat ${DASHBOARDS_DIR}/service-sla.json)
sed -i "s|{{DASHBOARD_SERVICE_SLA}}|${SERVICE_SLA}|g" ${TEMP_FILE}

# Resource Planning
RESOURCE_PLANNING=$(cat ${DASHBOARDS_DIR}/resource-planning.json)
sed -i "s|{{DASHBOARD_RESOURCE_PLANNING}}|${RESOURCE_PLANNING}|g" ${TEMP_FILE}

# Apply the ConfigMaps
echo -e "${YELLOW}Applying dashboard ConfigMaps...${NC}"
kubectl apply -f ${TEMP_FILE}

# Clean up
rm ${TEMP_FILE}

echo -e "${GREEN}Grafana dashboards deployed successfully!${NC}"
echo -e "${YELLOW}To access Grafana and view the dashboards:${NC}"
echo -e "  kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
echo -e "  Then open http://localhost:3000 (default login: admin/admin)"