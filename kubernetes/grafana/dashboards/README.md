# Grafana Dashboards

This directory contains a set of pre-built Grafana dashboards for the EKS Monitoring Platform.

## Dashboard Overview

1. **Cluster Overview Dashboard**
   - Provides a high-level view of the entire Kubernetes cluster
   - Shows node count, namespace count, running pods, and problem pods
   - Displays resource utilization (CPU, memory, disk, network) across the cluster
   - Lists namespaces with their resource usage and status

2. **Node Details Dashboard**
   - Detailed view of individual nodes in the cluster
   - Shows node status, resource usage, and capacity
   - Includes CPU, memory, disk, and network metrics for each node
   - Features a node selector to quickly switch between nodes

3. **Application Performance Dashboard**
   - Focuses on application-level metrics for the sample microservices
   - Displays API request rates, latency, and error rates
   - Shows database query performance and connection statistics
   - Helps identify bottlenecks and performance issues in the application

4. **Service SLA Dashboard**
   - Tracks service level agreement (SLA) metrics
   - Displays service availability, uptime, and reliability stats
   - Shows success rates for API and database operations
   - Helps ensure services are meeting defined SLA targets

5. **Resource Planning Dashboard**
   - Assists with capacity planning and resource optimization
   - Shows resource allocation vs. actual usage
   - Provides estimates for when additional capacity will be needed
   - Helps identify over/under-provisioned resources

## Deployment

To deploy these dashboards:

```bash
# From the project root
./scripts/deploy-dashboards.sh
```

This script will:
1. Convert the dashboard JSON files into Kubernetes ConfigMaps
2. Apply the ConfigMaps to the cluster
3. Configure Grafana to load these dashboards automatically

## Accessing the Dashboards

Once deployed, you can access the dashboards through Grafana:

```bash
# Port-forward Grafana to local machine
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring

# Open in browser
# http://localhost:3000
# Default login: admin/admin
```

## Customization

These dashboards can be customized either:

1. By editing the JSON files in this directory and re-deploying
2. By editing directly in the Grafana UI and saving the changes
3. By exporting from Grafana and replacing the files in this directory