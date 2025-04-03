#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Display help message
function show_help {
    echo "EKS Monitoring Platform Integration Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --integrate-logging-metrics  Integrate metrics and logging systems"
    echo "  --backup                     Backup monitoring and logging data to S3"
    echo "  --restore TIMESTAMP          Restore monitoring and logging data from S3"
    echo "  --check                      Run operational health check"
    echo "  --help                       Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --integrate-logging-metrics"
    echo "  $0 --backup --bucket my-monitoring-backups"
    echo "  $0 --restore 20230415120000 --bucket my-monitoring-backups"
    echo "  $0 --check"
    echo ""
}

# Check if no arguments provided
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# Check if integration scripts exist
if [ ! -d "$(dirname "$0")/integration" ]; then
    echo -e "${RED}Error: Integration scripts directory not found${NC}"
    exit 1
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --integrate-logging-metrics)
        INTEGRATE_LOGGING_METRICS=true
        shift
        ;;
        --backup)
        BACKUP=true
        shift
        ;;
        --restore)
        RESTORE=true
        TIMESTAMP="$2"
        shift
        shift
        ;;
        --bucket)
        S3_BUCKET="$2"
        shift
        shift
        ;;
        --check)
        OPERATIONAL_CHECK=true
        shift
        ;;
        --help)
        show_help
        exit 0
        ;;
        *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
    esac
done

# Integrate metrics and logging
if [ "$INTEGRATE_LOGGING_METRICS" = true ]; then
    echo -e "${GREEN}Running metrics and logging integration...${NC}"
    $(dirname "$0")/integration/metrics-logging-integration.sh
fi

# Backup to S3
if [ "$BACKUP" = true ]; then
    if [ -z "$S3_BUCKET" ]; then
        echo -e "${RED}Error: S3 bucket is required for backup${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Running backup to S3 bucket ${S3_BUCKET}...${NC}"
    $(dirname "$0")/integration/backup-restore.sh --action backup --bucket $S3_BUCKET --components all
fi

# Restore from S3
if [ "$RESTORE" = true ]; then
    if [ -z "$S3_BUCKET" ]; then
        echo -e "${RED}Error: S3 bucket is required for restore${NC}"
        exit 1
    fi
    
    if [ -z "$TIMESTAMP" ]; then
        echo -e "${RED}Error: Timestamp is required for restore${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Running restore from S3 bucket ${S3_BUCKET} with timestamp ${TIMESTAMP}...${NC}"
    $(dirname "$0")/integration/backup-restore.sh --action restore --bucket $S3_BUCKET --components all --timestamp $TIMESTAMP
fi

# Run operational check
if [ "$OPERATIONAL_CHECK" = true ]; then
    echo -e "${GREEN}Running operational health check...${NC}"
    $(dirname "$0")/integration/operational-checklist.sh
fi

echo -e "${GREEN}All requested operations completed!${NC}"