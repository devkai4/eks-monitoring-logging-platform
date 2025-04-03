#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
S3_BUCKET=""
ACTION=""
COMPONENTS=""
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
TEMP_DIR="/tmp/eks-monitoring-backup-${TIMESTAMP}"
RESTORE_TIMESTAMP=""

# Show help
function show_help {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -a, --action      Action to perform (backup or restore)"
    echo "  -b, --bucket      S3 bucket name for storing backups"
    echo "  -c, --components  Components to backup/restore (comma-separated, options: elasticsearch,prometheus,grafana,all)"
    echo "  -t, --timestamp   Timestamp of backup to restore (required for restore action)"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --action backup --bucket my-monitoring-backups --components all"
    echo "  $0 --action restore --bucket my-monitoring-backups --components elasticsearch,grafana --timestamp 20230415120000"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -a|--action)
        ACTION="$2"
        shift
        shift
        ;;
        -b|--bucket)
        S3_BUCKET="$2"
        shift
        shift
        ;;
        -c|--components)
        COMPONENTS="$2"
        shift
        shift
        ;;
        -t|--timestamp)
        RESTORE_TIMESTAMP="$2"
        shift
        shift
        ;;
        -h|--help)
        show_help
        ;;
        *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        ;;
    esac
done

# Validate arguments
if [[ -z "$ACTION" ]]; then
    echo -e "${RED}Error: Action is required (backup or restore)${NC}"
    show_help
fi

if [[ "$ACTION" != "backup" && "$ACTION" != "restore" ]]; then
    echo -e "${RED}Error: Invalid action. Must be 'backup' or 'restore'${NC}"
    show_help
fi

if [[ -z "$S3_BUCKET" ]]; then
    echo -e "${RED}Error: S3 bucket is required${NC}"
    show_help
fi

if [[ -z "$COMPONENTS" ]]; then
    echo -e "${RED}Error: Components are required${NC}"
    show_help
fi

if [[ "$ACTION" == "restore" && -z "$RESTORE_TIMESTAMP" ]]; then
    echo -e "${RED}Error: Timestamp is required for restore action${NC}"
    show_help
fi

# Set components
if [[ "$COMPONENTS" == "all" ]]; then
    COMPONENTS="elasticsearch,prometheus,grafana"
fi

# Check for required tools
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl not found. Please install kubectl.${NC}" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}aws not found. Please install AWS CLI.${NC}" >&2; exit 1; }

# Create temp directory
mkdir -p "${TEMP_DIR}"

# Function to backup Elasticsearch
function backup_elasticsearch {
    echo -e "${YELLOW}Backing up Elasticsearch...${NC}"
    
    # Create snapshot repository if it doesn't exist
    kubectl exec -it elasticsearch-master-0 -n logging -- curl -XPUT "localhost:9200/_snapshot/s3_repository" -H "Content-Type: application/json" -d '{
        "type": "s3",
        "settings": {
            "bucket": "'"${S3_BUCKET}"'",
            "base_path": "elasticsearch/snapshots"
        }
    }'
    
    # Create a snapshot
    kubectl exec -it elasticsearch-master-0 -n logging -- curl -XPUT "localhost:9200/_snapshot/s3_repository/snapshot_${TIMESTAMP}" -H "Content-Type: application/json" -d '{
        "indices": "*",
        "ignore_unavailable": true,
        "include_global_state": true
    }'
    
    # Wait for snapshot to complete
    echo -e "${YELLOW}Waiting for Elasticsearch snapshot to complete...${NC}"
    sleep 10
    
    # Check snapshot status
    kubectl exec -it elasticsearch-master-0 -n logging -- curl -XGET "localhost:9200/_snapshot/s3_repository/snapshot_${TIMESTAMP}"
    
    echo -e "${GREEN}Elasticsearch backup completed${NC}"
}

# Function to backup Prometheus
function backup_prometheus {
    echo -e "${YELLOW}Backing up Prometheus...${NC}"
    
    # Create directory for Prometheus backup
    mkdir -p "${TEMP_DIR}/prometheus"
    
    # Export Prometheus rules
    kubectl get prometheusrules -n monitoring -o yaml > "${TEMP_DIR}/prometheus/prometheusrules.yaml"
    
    # Export service monitors
    kubectl get servicemonitors -n monitoring -o yaml > "${TEMP_DIR}/prometheus/servicemonitors.yaml"
    
    # Export pod monitors
    kubectl get podmonitors -n monitoring -o yaml > "${TEMP_DIR}/prometheus/podmonitors.yaml"
    
    # Export alert manager config
    kubectl get secret alertmanager-prometheus-kube-prometheus-alertmanager -n monitoring -o yaml > "${TEMP_DIR}/prometheus/alertmanager-secret.yaml"
    
    # Upload to S3
    aws s3 cp "${TEMP_DIR}/prometheus" "s3://${S3_BUCKET}/prometheus/${TIMESTAMP}/" --recursive
    
    echo -e "${GREEN}Prometheus backup completed${NC}"
}

# Function to backup Grafana
function backup_grafana {
    echo -e "${YELLOW}Backing up Grafana...${NC}"
    
    # Create directory for Grafana backup
    mkdir -p "${TEMP_DIR}/grafana"
    
    # Export Grafana dashboards
    kubectl get configmaps -n monitoring -l grafana_dashboard=1 -o yaml > "${TEMP_DIR}/grafana/dashboards.yaml"
    
    # Export Grafana datasources
    kubectl get secrets -n monitoring -l grafana_datasource=1 -o yaml > "${TEMP_DIR}/grafana/datasources.yaml"
    
    # Upload to S3
    aws s3 cp "${TEMP_DIR}/grafana" "s3://${S3_BUCKET}/grafana/${TIMESTAMP}/" --recursive
    
    echo -e "${GREEN}Grafana backup completed${NC}"
}

# Function to restore Elasticsearch
function restore_elasticsearch {
    echo -e "${YELLOW}Restoring Elasticsearch from backup ${RESTORE_TIMESTAMP}...${NC}"
    
    # Create snapshot repository if it doesn't exist
    kubectl exec -it elasticsearch-master-0 -n logging -- curl -XPUT "localhost:9200/_snapshot/s3_repository" -H "Content-Type: application/json" -d '{
        "type": "s3",
        "settings": {
            "bucket": "'"${S3_BUCKET}"'",
            "base_path": "elasticsearch/snapshots"
        }
    }'
    
    # Close all indices
    kubectl exec -it elasticsearch-master-0 -n logging -- curl -XPOST "localhost:9200/_all/_close"
    
    # Restore from snapshot
    kubectl exec -it elasticsearch-master-0 -n logging -- curl -XPOST "localhost:9200/_snapshot/s3_repository/snapshot_${RESTORE_TIMESTAMP}/_restore" -H "Content-Type: application/json" -d '{
        "indices": "*",
        "ignore_unavailable": true,
        "include_global_state": true
    }'
    
    # Wait for restore to complete
    echo -e "${YELLOW}Waiting for Elasticsearch restore to complete...${NC}"
    sleep 30
    
    # Check restore status
    kubectl exec -it elasticsearch-master-0 -n logging -- curl -XGET "localhost:9200/_recovery?pretty"
    
    echo -e "${GREEN}Elasticsearch restore completed${NC}"
}

# Function to restore Prometheus
function restore_prometheus {
    echo -e "${YELLOW}Restoring Prometheus from backup ${RESTORE_TIMESTAMP}...${NC}"
    
    # Create directory for Prometheus restore
    mkdir -p "${TEMP_DIR}/prometheus-restore"
    
    # Download from S3
    aws s3 cp "s3://${S3_BUCKET}/prometheus/${RESTORE_TIMESTAMP}/" "${TEMP_DIR}/prometheus-restore" --recursive
    
    # Apply configurations
    echo -e "${YELLOW}Restoring Prometheus rules...${NC}"
    kubectl apply -f "${TEMP_DIR}/prometheus-restore/prometheusrules.yaml"
    
    echo -e "${YELLOW}Restoring service monitors...${NC}"
    kubectl apply -f "${TEMP_DIR}/prometheus-restore/servicemonitors.yaml"
    
    echo -e "${YELLOW}Restoring pod monitors...${NC}"
    kubectl apply -f "${TEMP_DIR}/prometheus-restore/podmonitors.yaml"
    
    echo -e "${YELLOW}Restoring alert manager config...${NC}"
    kubectl apply -f "${TEMP_DIR}/prometheus-restore/alertmanager-secret.yaml"
    
    # Restart Prometheus
    kubectl rollout restart statefulset/prometheus-prometheus-kube-prometheus-prometheus -n monitoring
    
    echo -e "${GREEN}Prometheus restore completed${NC}"
}

# Function to restore Grafana
function restore_grafana {
    echo -e "${YELLOW}Restoring Grafana from backup ${RESTORE_TIMESTAMP}...${NC}"
    
    # Create directory for Grafana restore
    mkdir -p "${TEMP_DIR}/grafana-restore"
    
    # Download from S3
    aws s3 cp "s3://${S3_BUCKET}/grafana/${RESTORE_TIMESTAMP}/" "${TEMP_DIR}/grafana-restore" --recursive
    
    # Apply configurations
    echo -e "${YELLOW}Restoring Grafana dashboards...${NC}"
    kubectl apply -f "${TEMP_DIR}/grafana-restore/dashboards.yaml"
    
    echo -e "${YELLOW}Restoring Grafana datasources...${NC}"
    kubectl apply -f "${TEMP_DIR}/grafana-restore/datasources.yaml"
    
    # Restart Grafana
    kubectl rollout restart deployment/prometheus-grafana -n monitoring
    
    echo -e "${GREEN}Grafana restore completed${NC}"
}

# Main execution
if [[ "$ACTION" == "backup" ]]; then
    echo -e "${GREEN}Starting backup process to S3 bucket ${S3_BUCKET} with timestamp ${TIMESTAMP}...${NC}"
    
    # Run backups based on selected components
    if [[ "$COMPONENTS" == *"elasticsearch"* ]]; then
        backup_elasticsearch
    fi
    
    if [[ "$COMPONENTS" == *"prometheus"* ]]; then
        backup_prometheus
    fi
    
    if [[ "$COMPONENTS" == *"grafana"* ]]; then
        backup_grafana
    fi
    
    echo -e "${GREEN}Backup completed successfully!${NC}"
    echo -e "${YELLOW}Use the following timestamp for restore: ${TIMESTAMP}${NC}"
    
elif [[ "$ACTION" == "restore" ]]; then
    echo -e "${GREEN}Starting restore process from S3 bucket ${S3_BUCKET} with timestamp ${RESTORE_TIMESTAMP}...${NC}"
    
    # Run restores based on selected components
    if [[ "$COMPONENTS" == *"elasticsearch"* ]]; then
        restore_elasticsearch
    fi
    
    if [[ "$COMPONENTS" == *"prometheus"* ]]; then
        restore_prometheus
    fi
    
    if [[ "$COMPONENTS" == *"grafana"* ]]; then
        restore_grafana
    fi
    
    echo -e "${GREEN}Restore completed successfully!${NC}"
fi

# Clean up
rm -rf "${TEMP_DIR}"