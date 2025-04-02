# Troubleshooting Guide

This guide provides solutions for common issues you may encounter with the EKS Monitoring and Logging Platform.

## Monitoring Stack Issues

### Prometheus

#### Prometheus Pod is not starting

**Symptoms:**
- Prometheus pod is in `Pending` or `CrashLoopBackOff` state

**Possible Causes and Solutions:**

1. **Insufficient Resources**
   ```bash
   kubectl describe pod -n monitoring <prometheus-pod-name>
   ```
   Look for resource-related errors in events. If the issue is resources, either update the resource requests in the Prometheus values file or add more capacity to the cluster.

2. **PersistentVolumeClaim Issues**
   ```bash
   kubectl get pvc -n monitoring
   kubectl describe pvc -n monitoring <prometheus-pvc-name>
   ```
   Ensure that the storage class exists and is working properly. You may need to create the PVC manually or use a different storage class.

3. **Configuration Issues**
   Check the Prometheus configuration:
   ```bash
   kubectl get secret -n monitoring prometheus-prometheus-kube-prometheus-prometheus -o jsonpath='{.data.prometheus\.yaml\.gz}' | base64 -d | gunzip
   ```

#### No metrics in Prometheus

**Symptoms:**
- Prometheus UI shows no metrics
- Query returns no results

**Possible Causes and Solutions:**

1. **ServiceMonitor issues**
   ```bash
   kubectl get servicemonitors -n monitoring
   kubectl describe servicemonitor -n monitoring <servicemonitor-name>
   ```
   Ensure that ServiceMonitor selectors match your service labels.

2. **Target Scraping Issues**
   Check if targets are being scraped:
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
   ```
   Then open http://localhost:9090/targets in your browser to check the status of the targets.

3. **Network Issues**
   Ensure that Prometheus can reach the targets:
   ```bash
   kubectl exec -it -n monitoring <prometheus-pod-name> -- wget -O- <target-service-url>/metrics
   ```

### Grafana

#### Grafana is not showing metrics

**Symptoms:**
- Grafana dashboards are empty
- "No data" message in panels

**Possible Causes and Solutions:**

1. **Data Source Configuration**
   - Verify that the Prometheus data source is configured correctly:
     - Go to Grafana UI > Configuration > Data Sources
     - Check the Prometheus URL (should be `http://prometheus-server` or similar)
     - Test the connection

2. **Dashboard Configuration**
   - Check if the dashboard is using the correct data source:
     - Edit the panel
     - Look at the query and make sure it's pointing to the Prometheus data source

3. **Query Syntax**
   - Verify that the PromQL queries are correct:
     - Try running the same query in Prometheus UI to see if it returns data

#### Cannot access Grafana

**Symptoms:**
- Cannot reach Grafana UI

**Possible Causes and Solutions:**

1. **Service Issues**
   ```bash
   kubectl get svc -n monitoring prometheus-grafana
   kubectl describe svc -n monitoring prometheus-grafana
   ```

2. **Access Method**
   - For local access, use port forwarding:
     ```bash
     kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
     ```
   - For cluster access, create an Ingress or LoadBalancer service

3. **Authentication Issues**
   - Default credentials are usually admin/admin or admin/prom-operator
   - If you've forgotten the password, you can reset it:
     ```bash
     kubectl rollout restart deployment -n monitoring prometheus-grafana
     ```

## Logging Stack Issues

### Elasticsearch

#### Elasticsearch pod is not starting

**Symptoms:**
- Elasticsearch pod is in `Pending` or `CrashLoopBackOff` state

**Possible Causes and Solutions:**

1. **Java Heap Size**
   ```bash
   kubectl logs -n logging <elasticsearch-pod-name>
   ```
   Look for heap size errors. Update the JVM heap settings in the Elasticsearch values file.

2. **Storage Issues**
   ```bash
   kubectl get pvc -n logging
   kubectl describe pvc -n logging <elasticsearch-pvc-name>
   ```
   Ensure storage provisioning is working correctly.

3. **System Configuration**
   Elasticsearch requires specific system settings. Check if the init container has properly set these:
   ```bash
   kubectl logs -n logging <elasticsearch-pod-name> -c init-sysctl
   ```

#### Elasticsearch cluster health is not green

**Symptoms:**
- Cluster health is yellow or red

**Possible Causes and Solutions:**

1. **Unassigned Shards**
   ```bash
   kubectl exec -it -n logging <elasticsearch-pod-name> -- curl -s 'localhost:9200/_cat/shards?v'
   ```
   Look for shards with unassigned status. This could be due to not enough data nodes or disk space.

2. **Cluster Formation Issues**
   ```bash
   kubectl exec -it -n logging <elasticsearch-pod-name> -- curl -s 'localhost:9200/_cluster/state?pretty'
   ```
   Check the cluster state for any configuration issues.

### Fluent Bit

#### Logs not showing up in Elasticsearch

**Symptoms:**
- No logs in Kibana
- Fluent Bit is running but logs aren't appearing

**Possible Causes and Solutions:**

1. **Configuration Issues**
   ```bash
   kubectl describe configmap -n logging fluent-bit-config
   ```
   Ensure the output section is correctly configured to send logs to Elasticsearch.

2. **Connection Issues**
   ```bash
   kubectl logs -n logging <fluent-bit-pod-name>
   ```
   Look for connection errors to Elasticsearch.

3. **Authentication Issues**
   Check if Fluent Bit has the correct credentials for Elasticsearch:
   ```bash
   kubectl get secret -n logging elasticsearch-credentials -o yaml
   ```

### Kibana

#### Kibana not connecting to Elasticsearch

**Symptoms:**
- "Kibana server is not ready yet" message
- Cannot create index patterns

**Possible Causes and Solutions:**

1. **Connection Issues**
   ```bash
   kubectl logs -n logging <kibana-pod-name>
   ```
   Check for connectivity errors to Elasticsearch.

2. **Authentication Issues**
   Ensure Kibana has the correct credentials:
   ```bash
   kubectl describe deployment -n logging kibana
   ```
   Look for the environment variables with Elasticsearch credentials.

3. **Elasticsearch Health**
   Kibana requires Elasticsearch to be in a healthy state:
   ```bash
   kubectl exec -it -n logging <elasticsearch-pod-name> -- curl -s 'localhost:9200/_cluster/health?pretty'
   ```

## CI/CD Pipeline Issues

### Terraform Plan/Apply Failures

**Symptoms:**
- CI/CD pipeline fails during Terraform plan or apply

**Possible Causes and Solutions:**

1. **AWS Credentials**
   - Ensure the AWS role has sufficient permissions
   - Check the role ARN in GitHub secrets

2. **Terraform State Issues**
   - Verify S3 bucket for Terraform state exists
   - Check DynamoDB table for state locking

3. **Resource Limitations**
   - AWS service quotas may be reached
   - Check the error message for specific quota issues

### Kubernetes Deployment Failures

**Symptoms:**
- Pipeline succeeds for infrastructure deployment but fails for Kubernetes resources

**Possible Causes and Solutions:**

1. **RBAC Issues**
   - Ensure the Kubernetes service account has sufficient permissions
   - Check for RBAC errors in the pipeline logs

2. **Manifest Validation**
   - Run `kubectl validate` locally to check manifests
   - Fix any validation errors in the Kubernetes manifests

3. **Helm Chart Issues**
   - Try installing the Helm chart locally with debug flags:
     ```bash
     helm install --debug --dry-run <release-name> <chart> -f values.yaml
     ```

## General Troubleshooting Commands

### Checking Pod Status

```bash
kubectl get pods -A
kubectl describe pod -n <namespace> <pod-name>
kubectl logs -n <namespace> <pod-name>
```

### Checking Service Status

```bash
kubectl get svc -A
kubectl describe svc -n <namespace> <service-name>
```

### Testing Network Connectivity

```bash
kubectl exec -it -n <namespace> <pod-name> -- curl -v <service-name>.<namespace>:<port>
```

### Restarting Components

```bash
kubectl rollout restart deployment -n <namespace> <deployment-name>
```

### Checking Resource Usage

```bash
kubectl top pods -n <namespace>
kubectl top nodes
```