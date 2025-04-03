#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Output format
OK="${GREEN}[✓]${NC}"
WARNING="${YELLOW}[!]${NC}"
ERROR="${RED}[✗]${NC}"
INFO="${BLUE}[i]${NC}"

# Get current date
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Create a report file
REPORT_FILE="/tmp/monitoring-platform-report-$(date +%Y%m%d%H%M%S).txt"
LOG_FILE="/tmp/monitoring-platform-log-$(date +%Y%m%d%H%M%S).txt"

echo "EKS Monitoring Platform Operational Checklist" > $REPORT_FILE
echo "Date: $DATE" >> $REPORT_FILE
echo "==============================================" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Check for required tools
command -v kubectl >/dev/null 2>&1 || { echo -e "${ERROR} kubectl not found. Please install kubectl." | tee -a $REPORT_FILE; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${ERROR} aws not found. Please install AWS CLI." | tee -a $REPORT_FILE; exit 1; }
command -v jq >/dev/null 2>&1 || { echo -e "${WARNING} jq not found. Some checks may not work correctly." | tee -a $REPORT_FILE; }

echo -e "${BLUE}=== EKS Monitoring Platform Operational Checklist ===${NC}"
echo -e "${BLUE}Date: $DATE${NC}"
echo -e "${BLUE}=============================================${NC}"

# Function to check if a pod is running
function check_pod_status {
    local namespace=$1
    local app_selector=$2
    local app_name=$3
    
    echo -e "${INFO} Checking $app_name pods..."
    echo "Checking $app_name pods..." >> $REPORT_FILE
    
    pod_status=$(kubectl get pods -n $namespace -l $app_selector -o jsonpath='{.items[*].status.phase}' 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${ERROR} Failed to get $app_name pod status" | tee -a $REPORT_FILE
        return 1
    fi
    
    if [[ "$pod_status" == *"Running"* && "$pod_status" != *"Failed"* && "$pod_status" != *"Pending"* ]]; then
        echo -e "${OK} $app_name pods are running" | tee -a $REPORT_FILE
        return 0
    else
        echo -e "${ERROR} $app_name pods are not all running: $pod_status" | tee -a $REPORT_FILE
        kubectl get pods -n $namespace -l $app_selector >> $LOG_FILE 2>&1
        return 1
    fi
}

# Function to check prometheus targets
function check_prometheus_targets {
    echo -e "${INFO} Checking Prometheus targets..."
    echo "Checking Prometheus targets..." >> $REPORT_FILE
    
    # Port-forward to Prometheus (background)
    kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090 &> /dev/null &
    PF_PID=$!
    
    # Give it time to establish
    sleep 3
    
    # Check if port-forward succeeded
    if ! curl -s http://localhost:9090 &> /dev/null; then
        echo -e "${ERROR} Failed to connect to Prometheus" | tee -a $REPORT_FILE
        kill $PF_PID &> /dev/null
        return 1
    fi
    
    # Get targets
    if command -v jq &> /dev/null; then
        # Using jq for better parsing if available
        targets_json=$(curl -s http://localhost:9090/api/v1/targets)
        active_targets=$(echo $targets_json | jq -r '.data.activeTargets | length')
        unhealthy_targets=$(echo $targets_json | jq -r '.data.activeTargets[] | select(.health != "up") | .labels.job' 2>/dev/null | wc -l)
        
        if [ "$unhealthy_targets" -gt 0 ]; then
            echo -e "${WARNING} $unhealthy_targets out of $active_targets Prometheus targets are unhealthy" | tee -a $REPORT_FILE
            echo "Unhealthy targets:" >> $REPORT_FILE
            echo $targets_json | jq -r '.data.activeTargets[] | select(.health != "up") | .labels.job' >> $REPORT_FILE
            echo $targets_json | jq -r '.data.activeTargets[] | select(.health != "up") | .labels.job' >> $LOG_FILE
        else
            echo -e "${OK} All $active_targets Prometheus targets are healthy" | tee -a $REPORT_FILE
        fi
    else
        # Fallback without jq
        targets_status=$(curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"up"' | wc -l)
        echo -e "${OK} Found $targets_status healthy Prometheus targets" | tee -a $REPORT_FILE
    fi
    
    # Kill port-forward
    kill $PF_PID &> /dev/null
    return 0
}

# Function to check alert rules
function check_alert_rules {
    echo -e "${INFO} Checking AlertManager rules..."
    echo "Checking AlertManager rules..." >> $REPORT_FILE
    
    # Get alerting rules
    alerting_rules=$(kubectl get prometheusrules -n monitoring -o json 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${ERROR} Failed to get AlertManager rules" | tee -a $REPORT_FILE
        return 1
    fi
    
    # Count rules
    if command -v jq &> /dev/null; then
        rules_count=$(echo $alerting_rules | jq -r '.items | length')
        echo -e "${OK} Found $rules_count AlertManager rule groups" | tee -a $REPORT_FILE
        
        # Port-forward to Prometheus (background)
        kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090 &> /dev/null &
        PF_PID=$!
        
        # Give it time to establish
        sleep 3
        
        # Check if port-forward succeeded
        if curl -s http://localhost:9090 &> /dev/null; then
            # Get firing alerts
            alerts_json=$(curl -s http://localhost:9090/api/v1/alerts)
            firing_alerts=$(echo $alerts_json | jq -r '.data.alerts[] | select(.state == "firing") | .labels.alertname' 2>/dev/null | wc -l)
            
            if [ "$firing_alerts" -gt 0 ]; then
                echo -e "${WARNING} $firing_alerts alerts are currently firing" | tee -a $REPORT_FILE
                echo "Firing alerts:" >> $REPORT_FILE
                echo $alerts_json | jq -r '.data.alerts[] | select(.state == "firing") | .labels.alertname' >> $REPORT_FILE
                echo $alerts_json | jq -r '.data.alerts[] | select(.state == "firing") | .labels.alertname' >> $LOG_FILE
            else
                echo -e "${OK} No alerts are currently firing" | tee -a $REPORT_FILE
            fi
            
            # Kill port-forward
            kill $PF_PID &> /dev/null
        else
            echo -e "${WARNING} Couldn't check firing alerts" | tee -a $REPORT_FILE
            kill $PF_PID &> /dev/null
        fi
    else
        # Fallback without jq
        rules_count=$(kubectl get prometheusrules -n monitoring | wc -l)
        echo -e "${OK} Found $rules_count AlertManager rule objects" | tee -a $REPORT_FILE
    fi
    
    return 0
}

# Function to check Elasticsearch cluster health
function check_elasticsearch_health {
    echo -e "${INFO} Checking Elasticsearch cluster health..."
    echo "Checking Elasticsearch cluster health..." >> $REPORT_FILE
    
    # Port-forward to Elasticsearch (background)
    kubectl port-forward svc/elasticsearch-master -n logging 9200:9200 &> /dev/null &
    PF_PID=$!
    
    # Give it time to establish
    sleep 3
    
    # Check if port-forward succeeded
    if ! curl -s http://localhost:9200 &> /dev/null; then
        echo -e "${ERROR} Failed to connect to Elasticsearch" | tee -a $REPORT_FILE
        kill $PF_PID &> /dev/null
        return 1
    fi
    
    # Get cluster health
    cluster_health=$(curl -s http://localhost:9200/_cluster/health)
    
    if command -v jq &> /dev/null; then
        status=$(echo $cluster_health | jq -r '.status')
        
        case $status in
            "green")
                echo -e "${OK} Elasticsearch cluster health is green" | tee -a $REPORT_FILE
                ;;
            "yellow")
                echo -e "${WARNING} Elasticsearch cluster health is yellow" | tee -a $REPORT_FILE
                echo "Details:" >> $REPORT_FILE
                echo $cluster_health | jq >> $REPORT_FILE
                echo $cluster_health >> $LOG_FILE
                ;;
            "red")
                echo -e "${ERROR} Elasticsearch cluster health is red" | tee -a $REPORT_FILE
                echo "Details:" >> $REPORT_FILE
                echo $cluster_health | jq >> $REPORT_FILE
                echo $cluster_health >> $LOG_FILE
                ;;
            *)
                echo -e "${ERROR} Unknown Elasticsearch cluster health status: $status" | tee -a $REPORT_FILE
                ;;
        esac
    else
        # Fallback without jq
        if [[ "$cluster_health" == *"green"* ]]; then
            echo -e "${OK} Elasticsearch cluster health is green" | tee -a $REPORT_FILE
        elif [[ "$cluster_health" == *"yellow"* ]]; then
            echo -e "${WARNING} Elasticsearch cluster health is yellow" | tee -a $REPORT_FILE
        elif [[ "$cluster_health" == *"red"* ]]; then
            echo -e "${ERROR} Elasticsearch cluster health is red" | tee -a $REPORT_FILE
        else
            echo -e "${ERROR} Unknown Elasticsearch cluster health status" | tee -a $REPORT_FILE
        fi
    fi
    
    # Kill port-forward
    kill $PF_PID &> /dev/null
    return 0
}

# Function to check disk usage
function check_disk_usage {
    echo -e "${INFO} Checking disk usage on nodes..."
    echo "Checking disk usage on nodes..." >> $REPORT_FILE
    
    # Port-forward to Prometheus (background)
    kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090 &> /dev/null &
    PF_PID=$!
    
    # Give it time to establish
    sleep 3
    
    # Check if port-forward succeeded
    if ! curl -s http://localhost:9090 &> /dev/null; then
        echo -e "${ERROR} Failed to connect to Prometheus" | tee -a $REPORT_FILE
        kill $PF_PID &> /dev/null
        return 1
    fi
    
    # Query disk usage
    disk_query='100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"})'
    disk_usage=$(curl -s -G --data-urlencode "query=$disk_query" http://localhost:9090/api/v1/query)
    
    if command -v jq &> /dev/null; then
        results=$(echo $disk_usage | jq -r '.data.result[] | .metric.instance + ": " + .value[1] + "%"' 2>/dev/null)
        
        if [ -z "$results" ]; then
            echo -e "${WARNING} No disk usage data available" | tee -a $REPORT_FILE
        else
            echo -e "${OK} Current disk usage:" | tee -a $REPORT_FILE
            echo "$results" | while read line; do
                usage=$(echo $line | awk -F': ' '{print $2}' | sed 's/%//')
                node=$(echo $line | awk -F': ' '{print $1}')
                
                if (( $(echo "$usage > 85" | bc -l) )); then
                    echo -e "${ERROR} $node: $usage%" | tee -a $REPORT_FILE
                elif (( $(echo "$usage > 70" | bc -l) )); then
                    echo -e "${WARNING} $node: $usage%" | tee -a $REPORT_FILE
                else
                    echo -e "${OK} $node: $usage%" | tee -a $REPORT_FILE
                fi
            done
        fi
    else
        # Fallback without jq
        echo -e "${WARNING} jq not available, can't parse disk usage results properly" | tee -a $REPORT_FILE
    fi
    
    # Kill port-forward
    kill $PF_PID &> /dev/null
    return 0
}

# Function to check Grafana dashboards
function check_grafana_dashboards {
    echo -e "${INFO} Checking Grafana dashboards..."
    echo "Checking Grafana dashboards..." >> $REPORT_FILE
    
    dashboard_count=$(kubectl get configmaps -n monitoring -l grafana_dashboard=1 2>/dev/null | wc -l)
    if [ "$dashboard_count" -gt 0 ]; then
        echo -e "${OK} Found $dashboard_count Grafana dashboards" | tee -a $REPORT_FILE
    else
        echo -e "${WARNING} No Grafana dashboards found" | tee -a $REPORT_FILE
    fi
    
    return 0
}

# Function to check Kubernetes component status
function check_k8s_components {
    echo -e "${INFO} Checking Kubernetes components status..."
    echo "Checking Kubernetes components status..." >> $REPORT_FILE
    
    # Get nodes
    nodes=$(kubectl get nodes 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${ERROR} Failed to get Kubernetes nodes" | tee -a $REPORT_FILE
        return 1
    fi
    
    node_count=$(echo "$nodes" | grep -v "NAME" | wc -l)
    not_ready=$(echo "$nodes" | grep -v "Ready" | grep -v "NAME" | wc -l)
    
    if [ "$not_ready" -gt 0 ]; then
        echo -e "${ERROR} $not_ready out of $node_count nodes are not ready" | tee -a $REPORT_FILE
        echo "$nodes" | grep -v "Ready" | grep -v "NAME" >> $REPORT_FILE
    else
        echo -e "${OK} All $node_count nodes are ready" | tee -a $REPORT_FILE
    fi
    
    # Check control plane components
    echo -e "${INFO} Checking control plane components..."
    echo "Checking control plane components..." >> $REPORT_FILE
    
    for component in apiserver controller-manager scheduler; do
        pod_status=$(kubectl get pods -n kube-system -l component=$component -o jsonpath='{.items[*].status.phase}' 2>&1)
        if [ $? -ne 0 ]; then
            echo -e "${WARNING} Failed to get status for $component" | tee -a $REPORT_FILE
        elif [[ "$pod_status" == *"Running"* ]]; then
            echo -e "${OK} $component is running" | tee -a $REPORT_FILE
        else
            echo -e "${ERROR} $component is not running: $pod_status" | tee -a $REPORT_FILE
        fi
    done
    
    return 0
}

# Run checks
echo -e "${BLUE}Running operational checks...${NC}"

echo -e "${BLUE}1. Cluster Status${NC}"
check_k8s_components

echo -e "\n${BLUE}2. Monitoring Stack${NC}"
check_pod_status "monitoring" "app=prometheus" "Prometheus"
check_pod_status "monitoring" "app=grafana" "Grafana"
check_prometheus_targets
check_alert_rules
check_grafana_dashboards

echo -e "\n${BLUE}3. Logging Stack${NC}"
check_pod_status "logging" "app=elasticsearch-master" "Elasticsearch"
check_pod_status "logging" "app=fluent-bit" "Fluent Bit"
check_pod_status "logging" "app=kibana" "Kibana"
check_elasticsearch_health

echo -e "\n${BLUE}4. Resource Usage${NC}"
check_disk_usage

# Final report
echo -e "\n${BLUE}===================${NC}"
echo -e "${BLUE}Operational check completed${NC}"
echo -e "${BLUE}Full report saved to: ${REPORT_FILE}${NC}"
echo -e "${BLUE}Detailed logs saved to: ${LOG_FILE}${NC}"

# Add summary to report
echo "" >> $REPORT_FILE
echo "===================" >> $REPORT_FILE
echo "Operational check completed at $(date +"%Y-%m-%d %H:%M:%S")" >> $REPORT_FILE