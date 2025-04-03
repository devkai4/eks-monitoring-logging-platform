#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Integrating Metrics and Logging Systems...${NC}"

# Check for kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

# Check if namespaces exist
echo -e "${YELLOW}Verifying namespaces...${NC}"
kubectl get namespace monitoring &> /dev/null || { echo -e "${RED}Monitoring namespace not found. Please install the monitoring stack first.${NC}" >&2; exit 1; }
kubectl get namespace logging &> /dev/null || { echo -e "${RED}Logging namespace not found. Please install the logging stack first.${NC}" >&2; exit 1; }

echo -e "${YELLOW}Setting up service discovery between Prometheus and Elasticsearch...${NC}"

# Create Service Monitor for Elasticsearch
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: elasticsearch
  namespace: monitoring
  labels:
    release: prometheus
spec:
  endpoints:
  - port: http
    interval: 30s
    path: /_prometheus/metrics
  namespaceSelector:
    matchNames:
    - logging
  selector:
    matchLabels:
      app: elasticsearch-master
EOF

# Create Service Monitor for Kibana
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kibana
  namespace: monitoring
  labels:
    release: prometheus
spec:
  endpoints:
  - port: http
    interval: 30s
    path: /api/reporting/stats
  namespaceSelector:
    matchNames:
    - logging
  selector:
    matchLabels:
      app: kibana
EOF

# Create Service Monitor for FluentBit
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: fluent-bit
  namespace: monitoring
  labels:
    release: prometheus
spec:
  endpoints:
  - port: http
    interval: 30s
    path: /api/v1/metrics/prometheus
  namespaceSelector:
    matchNames:
    - logging
  selector:
    matchLabels:
      app.kubernetes.io/name: fluent-bit
EOF

echo -e "${YELLOW}Creating Grafana data sources for Elasticsearch...${NC}"

# Get Elasticsearch credentials
ES_PASSWORD=$(kubectl get secret elasticsearch-credentials -n logging -o jsonpath="{.data.password}" | base64 --decode)

# Create Elasticsearch data source in Grafana
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: elasticsearch-datasource
  namespace: monitoring
type: Opaque
stringData:
  elasticsearch-datasource.yaml: |-
    apiVersion: 1
    datasources:
    - name: Elasticsearch
      type: elasticsearch
      access: proxy
      url: http://elasticsearch-master.logging:9200
      database: "[logstash-]YYYY.MM.DD"
      jsonData:
        interval: Daily
        timeField: "@timestamp"
        esVersion: 7.0.0
      secureJsonData:
        basicAuth: true
        basicAuthUser: "elastic"
        basicAuthPassword: "${ES_PASSWORD}"
EOF

# Apply label so Grafana picks up the data source
kubectl label secret elasticsearch-datasource -n monitoring grafana_datasource=1

# Create alert rule for log anomalies
echo -e "${YELLOW}Creating alert rules for log anomalies...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: log-anomalies
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
  - name: log-based-alerts
    rules:
    - alert: HighErrorLogsRate
      expr: rate(fluentbit_output_proc_records_total{plugin_id=~".*elasticsearch.*",pod_name=~"fluent-bit.*"}[5m]) > 10
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "High rate of error logs detected"
        description: "There is a high rate of error logs being sent to Elasticsearch (> 10 per second)"
    
    - alert: LoggingSystemErrors
      expr: rate(fluentbit_output_errors_total[5m]) > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Logging system is experiencing errors"
        description: "Fluent Bit is reporting errors in log processing or forwarding"
    
    - alert: LoggingBackpressure
      expr: rate(fluentbit_output_retries_total[5m]) > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Logging system is experiencing backpressure"
        description: "Fluent Bit is having to retry sending logs, indicating possible backpressure"
EOF

echo -e "${YELLOW}Creating integration dashboard...${NC}"

# Create integration dashboard for Grafana
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-integration-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  logging-metrics-integration.json: |-
    {
      "annotations": {
        "list": [
          {
            "builtIn": 1,
            "datasource": {
              "type": "datasource",
              "uid": "grafana"
            },
            "enable": true,
            "hide": true,
            "iconColor": "rgba(0, 211, 255, 1)",
            "name": "Annotations & Alerts",
            "target": {
              "limit": 100,
              "matchAny": false,
              "tags": [],
              "type": "dashboard"
            },
            "type": "dashboard"
          }
        ]
      },
      "editable": true,
      "fiscalYearStartMonth": 0,
      "graphTooltip": 0,
      "id": 6,
      "links": [],
      "liveNow": false,
      "panels": [
        {
          "collapsed": false,
          "gridPos": {
            "h": 1,
            "w": 24,
            "x": 0,
            "y": 0
          },
          "id": 12,
          "panels": [],
          "title": "Logging System Metrics",
          "type": "row"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "short"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 1
          },
          "id": 2,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "mode": "multi",
              "sort": "none"
            }
          },
          "pluginVersion": "9.3.1",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "sum(rate(fluentbit_input_bytes_total[5m])) by (pod)",
              "legendFormat": "{{pod}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Log Collection Rate",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              }
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 1
          },
          "id": 4,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "mode": "multi",
              "sort": "none"
            }
          },
          "pluginVersion": "9.3.1",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "rate(fluentbit_output_errors_total[5m])",
              "legendFormat": "{{pod}} - {{plugin_id}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Log Output Errors",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              }
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 9
          },
          "id": 6,
          "options": {
            "displayMode": "gradient",
            "minVizHeight": 10,
            "minVizWidth": 0,
            "orientation": "horizontal",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showUnfilled": true,
            "text": {}
          },
          "pluginVersion": "9.3.1",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "elasticsearch_cluster_health_active_shards",
              "legendFormat": "Active Shards",
              "range": true,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "elasticsearch_cluster_health_active_primary_shards",
              "hide": false,
              "legendFormat": "Primary Shards",
              "range": true,
              "refId": "B"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "elasticsearch_cluster_health_relocating_shards",
              "hide": false,
              "legendFormat": "Relocating Shards",
              "range": true,
              "refId": "C"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "elasticsearch_cluster_health_initializing_shards",
              "hide": false,
              "legendFormat": "Initializing Shards",
              "range": true,
              "refId": "D"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "elasticsearch_cluster_health_unassigned_shards",
              "hide": false,
              "legendFormat": "Unassigned Shards",
              "range": true,
              "refId": "E"
            }
          ],
          "title": "Elasticsearch Shards Status",
          "type": "bargauge"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "continuous-GrYlRd"
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              }
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 9
          },
          "id": 8,
          "options": {
            "displayMode": "lcd",
            "minVizHeight": 10,
            "minVizWidth": 0,
            "orientation": "horizontal",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showUnfilled": true
          },
          "pluginVersion": "9.3.1",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "100 * (elasticsearch_filesystem_data_available_bytes / elasticsearch_filesystem_data_size_bytes)",
              "legendFormat": "{{node}} - Disk Space Available %",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Elasticsearch Disk Space",
          "type": "bargauge"
        },
        {
          "collapsed": false,
          "gridPos": {
            "h": 1,
            "w": 24,
            "x": 0,
            "y": 17
          },
          "id": 10,
          "panels": [],
          "title": "Log & Metrics Correlation",
          "type": "row"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 0,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "auto",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              }
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 24,
            "x": 0,
            "y": 18
          },
          "id": 14,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "sum(rate(api_error_count[5m]))",
              "legendFormat": "API Errors",
              "range": true,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "sum(rate(db_error_count[5m]))",
              "hide": false,
              "legendFormat": "DB Errors",
              "range": true,
              "refId": "B"
            }
          ],
          "title": "Application Error Metrics",
          "type": "timeseries"
        }
      ],
      "refresh": "10s",
      "schemaVersion": 37,
      "style": "dark",
      "tags": [],
      "templating": {
        "list": []
      },
      "time": {
        "from": "now-6h",
        "to": "now"
      },
      "timepicker": {},
      "timezone": "",
      "title": "Metrics and Logging Integration",
      "uid": "metrics-logging",
      "version": 1,
      "weekStart": ""
    }
EOF

echo -e "${YELLOW}Creating Elasticsearch index patterns in Kibana...${NC}"

# Port-forward Kibana (in background)
kubectl port-forward svc/kibana-kibana 5601:5601 -n logging &
PF_PID=$!

# Wait for port-forward to establish
sleep 5

# Setup index patterns
cat <<EOF > /tmp/kibana-setup.sh
#!/bin/bash
curl -X POST "http://localhost:5601/api/saved_objects/index-pattern/metrics-*" \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/json' \
  -d '{
    "attributes": {
      "title": "metrics-*",
      "timeFieldName": "@timestamp"
    }
  }'

curl -X POST "http://localhost:5601/api/saved_objects/index-pattern/kubernetes-*" \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/json' \
  -d '{
    "attributes": {
      "title": "kubernetes-*",
      "timeFieldName": "@timestamp"
    }
  }'

curl -X POST "http://localhost:5601/api/saved_objects/index-pattern/application-*" \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/json' \
  -d '{
    "attributes": {
      "title": "application-*",
      "timeFieldName": "@timestamp"
    }
  }'
EOF

chmod +x /tmp/kibana-setup.sh

# Run setup script
/tmp/kibana-setup.sh

# Kill the port-forward
kill $PF_PID

echo -e "${GREEN}Integration completed successfully!${NC}"
echo -e "${YELLOW}You can now:${NC}"
echo -e "  - View Elasticsearch metrics in Prometheus (http://localhost:9090)"
echo -e "  - Use the new 'Metrics and Logging Integration' dashboard in Grafana"
echo -e "  - Correlate logs and metrics using the index patterns in Kibana"
echo -e "  - Receive alerts for log-based anomalies"