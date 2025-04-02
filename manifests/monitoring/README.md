# Prometheus and Grafana Deployment Guide

This directory contains the manifests and Helm chart configurations needed to deploy Prometheus and Grafana to an EKS cluster.

## Overview

This setup deploys the following components:

- **Prometheus**: Metrics collection and storage
- **Grafana**: Metrics visualization and dashboarding
- **AlertManager**: Alert management
- **Node Exporter**: Node-level metrics collection
- **kube-state-metrics**: Kubernetes resource state metrics

## Prerequisites

- Kubernetes 1.19+
- Helm 3.x
- `kubectl` command-line tool
- Access to an EKS cluster

## Installation Instructions

1. Navigate to this directory:
   ```
   cd manifests/monitoring
   ```

2. Run the installation script:
   ```
   ./install.sh
   ```

3. Wait for all pods to start (may take a few minutes)

## Access Information

After installation, you can access the services using the following commands:

**Prometheus**:
```
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
```
Access in browser: http://localhost:9090

**Grafana**:
```
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```
Access in browser: http://localhost:3000
Default credentials: admin / admin

**AlertManager**:
```
kubectl port-forward -n monitoring svc/prometheus-alertmanager 9093:9093
```
Access in browser: http://localhost:9093

## Configurable Parameters

The following key settings can be modified in the `values.yaml` file:

### Prometheus Configuration
- `prometheus.prometheusSpec.retention`: Data retention period (default: 15 days)
- `prometheus.prometheusSpec.storageSpec`: Storage configuration
  - Storage class
  - Storage size
- `prometheus.prometheusSpec.resources`: Resource limits

### Grafana Configuration
- `grafana.persistence`: Persistent storage configuration
- `grafana.adminPassword`: Admin password
- `grafana.dashboards`: Dashboards to import
- `grafana.resources`: Resource limits

### Node Exporter Configuration
- `nodeExporter.resources`: Resource limits

### AlertManager Configuration
- `alertmanager.alertmanagerSpec.storage`: Storage configuration
- `alertmanager.alertmanagerSpec.resources`: Resource limits

## Included Dashboards

This setup includes the following Grafana dashboards:

1. **Kubernetes Cluster Monitoring** (ID: 7249)
   - Overall cluster state monitoring

2. **Node Exporter Full** (ID: 1860)
   - Detailed node resource usage monitoring

3. **Kubernetes Capacity Planning** (ID: 5228)
   - Cluster capacity planning and forecasting

4. **Kubernetes Pod Monitoring** (ID: 6417)
   - Pod resource usage monitoring

## Customization

To customize the setup for specific requirements:

1. Edit `values.yaml` with your desired changes
2. Update using the following command:
   ```
   helm upgrade prometheus prometheus-community/kube-prometheus-stack \
     --namespace monitoring \
     --values values.yaml
   ```

## Troubleshooting

1. **If pods don't start**:
   ```
   kubectl get pods -n monitoring
   kubectl describe pod <pod-name> -n monitoring
   ```

2. **If PersistentVolumeClaims aren't created**:
   ```
   kubectl get pvc -n monitoring
   kubectl describe pvc <pvc-name> -n monitoring
   ```

3. **Check available StorageClasses**:
   ```
   kubectl get storageclass
   ```