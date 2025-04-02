# Alert Troubleshooting Guide

This guide provides step-by-step instructions for troubleshooting common alerts in the EKS Monitoring Platform.

## Node Alerts

### NodeCPUUsageCritical / NodeCPUUsageWarning

**Alert Description**: Node CPU usage exceeds 90% (critical) or 80% (warning).

**Troubleshooting Steps**:

1. Identify the affected node:
   ```bash
   kubectl describe node <node_name>
   ```

2. Check which pods are consuming CPU on this node:
   ```bash
   kubectl top pods --all-namespaces --sort-by=cpu | grep <node_name>
   ```

3. Look for potential causes:
   - CPU-intensive workloads or unexpected spikes
   - Too many pods scheduled on the node
   - System processes consuming excessive resources

4. Potential resolutions:
   - Scale out the deployment to distribute load
   - Add more nodes to the cluster
   - Apply resource limits to runaway pods
   - Increase the node size (vertical scaling)
   - Use Pod Disruption Budgets to ensure availability during eviction

### NodeMemoryUsageCritical / NodeMemoryUsageWarning

**Alert Description**: Node memory usage exceeds 90% (critical) or 80% (warning).

**Troubleshooting Steps**:

1. Identify the affected node:
   ```bash
   kubectl describe node <node_name>
   ```

2. Check which pods are consuming memory on this node:
   ```bash
   kubectl top pods --all-namespaces --sort-by=memory | grep <node_name>
   ```

3. Check for memory leaks or excessive usage:
   ```bash
   kubectl exec -it <pod_name> -n <namespace> -- cat /proc/meminfo
   ```

4. Potential resolutions:
   - Apply or adjust memory limits in pod specifications
   - Check for memory leaks in applications
   - Add more nodes to the cluster
   - Increase node memory (vertical scaling)
   - Tune the application to use less memory

### NodeDiskUsageCritical / NodeDiskUsageWarning

**Alert Description**: Node disk usage exceeds 95% (critical) or 85% (warning).

**Troubleshooting Steps**:

1. Identify the affected node and mountpoint:
   ```bash
   kubectl describe node <node_name>
   ```

2. Check what's consuming disk space:
   ```bash
   # Using debug pod to access node filesystem
   kubectl debug node/<node_name> -it --image=busybox
   ```

3. Common causes:
   - Container logs accumulation
   - Persistent volume usage
   - Temporary files buildup
   - Docker images and layers

4. Potential resolutions:
   - Clean up unused Docker images
   - Rotate or compress logs
   - Increase disk size for the node
   - Move data to a dedicated storage solution
   - Configure log rotation more aggressively

## Kubernetes Pod Alerts

### KubernetesPodCrashLoopBackOff

**Alert Description**: Pod has restarted more than 5 times in the last 15 minutes.

**Troubleshooting Steps**:

1. Identify the affected pod:
   ```bash
   kubectl get pod <pod_name> -n <namespace>
   ```

2. Check pod events:
   ```bash
   kubectl describe pod <pod_name> -n <namespace>
   ```

3. Review pod logs:
   ```bash
   kubectl logs <pod_name> -n <namespace>
   kubectl logs <pod_name> -n <namespace> --previous  # Logs from the previous instance
   ```

4. Common causes:
   - Application errors or exceptions
   - Missing dependencies or configuration
   - Resource constraints (OOMKilled)
   - Liveness probe failures

5. Potential resolutions:
   - Fix application bugs or errors
   - Adjust resource limits and requests
   - Fix liveness probe configuration
   - Ensure all dependencies are available

### KubernetesPodNotReady

**Alert Description**: Pod has been in a non-ready state for more than 10 minutes.

**Troubleshooting Steps**:

1. Check pod status:
   ```bash
   kubectl describe pod <pod_name> -n <namespace>
   ```

2. Review pod events for errors:
   ```bash
   kubectl get events -n <namespace> --field-selector involvedObject.name=<pod_name>
   ```

3. Check readiness probe configuration:
   ```bash
   kubectl get pod <pod_name> -n <namespace> -o yaml | grep readiness -A 10
   ```

4. Common causes:
   - Readiness probe failures
   - Application not fully initialized
   - Dependency services unavailable
   - Resource constraints

5. Potential resolutions:
   - Adjust readiness probe parameters
   - Fix application initialization issues
   - Ensure dependencies are available
   - Check for network policies blocking connectivity

## Storage Alerts

### KubernetesPersistentVolumeUtilizationCritical / KubernetesPersistentVolumeUtilizationWarning

**Alert Description**: PersistentVolume is running low on space (< 5% critical, < 15% warning).

**Troubleshooting Steps**:

1. Identify the affected PVC:
   ```bash
   kubectl get pvc <pvc_name> -n <namespace>
   ```

2. Find the pod using this PVC:
   ```bash
   kubectl get pods -n <namespace> -o json | jq '.items[] | select(.spec.volumes[].persistentVolumeClaim.claimName == "<pvc_name>") | .metadata.name'
   ```

3. Check what's consuming space:
   ```bash
   kubectl exec -it <pod_name> -n <namespace> -- df -h
   kubectl exec -it <pod_name> -n <namespace> -- du -h --max-depth=1 /path/to/mount
   ```

4. Potential resolutions:
   - Clean up unnecessary files
   - Resize the PVC (if supported)
   - Archive older data
   - Implement proper data retention policies
   - Migrate to a larger volume

## API Server Alerts

### KubernetesAPIServerLatency

**Alert Description**: API server latency is higher than 2 seconds for some requests.

**Troubleshooting Steps**:

1. Check API server metrics:
   ```bash
   kubectl get --raw /metrics | grep apiserver_request_duration_seconds
   ```

2. Check API server logs:
   ```bash
   kubectl logs -n kube-system -l component=kube-apiserver
   ```

3. Common causes:
   - High API server load
   - Etcd performance issues
   - Resource constraints on API server pods
   - Network issues

4. Potential resolutions:
   - Scale API server (in self-managed Kubernetes)
   - Check for clients making excessive API calls
   - Implement rate limiting
   - Tune etcd performance
   - Use pagination for list operations

### KubernetesAPIServerErrors

**Alert Description**: API server error rate is higher than 5%.

**Troubleshooting Steps**:

1. Check API server status:
   ```bash
   kubectl get componentstatuses
   ```

2. Check API server logs for error patterns:
   ```bash
   kubectl logs -n kube-system -l component=kube-apiserver | grep -i error
   ```

3. Check recent events:
   ```bash
   kubectl get events -n kube-system
   ```

4. Common causes:
   - Authentication or authorization issues
   - Resource constraints
   - API server overload
   - Networking problems

5. Potential resolutions:
   - Fix authentication issues
   - Check RBAC configuration
   - Address resource constraints
   - Implement rate limiting for API calls
   - Review network policies

## AlertManager Issues

### AlertManager Not Receiving Alerts

**Troubleshooting Steps**:

1. Check if AlertManager is running:
   ```bash
   kubectl get pods -n monitoring | grep alertmanager
   ```

2. Verify the AlertManager configuration:
   ```bash
   kubectl get secret -n monitoring alertmanager-main -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d
   ```

3. Check Prometheus configuration for AlertManager settings:
   ```bash
   kubectl get secret -n monitoring prometheus-server -o jsonpath='{.data.prometheus\.yml}' | base64 -d | grep alertmanager
   ```

4. Check connectivity between Prometheus and AlertManager:
   ```bash
   kubectl exec -it <prometheus-pod> -n monitoring -- wget -O- http://alertmanager-service:9093/api/v2/status
   ```

### Alerts Not Being Routed Correctly

**Troubleshooting Steps**:

1. Check AlertManager configuration:
   ```bash
   kubectl get secret -n monitoring alertmanager-main -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d
   ```

2. Verify route definitions and matchers match your alerts:
   - Check for typos in label names or values
   - Verify routing tree structure

3. Check if notification integrations are working:
   - For Slack, verify webhook URL is correct
   - For email, check SMTP settings
   - For PagerDuty, verify service key

4. Confirm alerts have the expected labels:
   ```bash
   kubectl port-forward svc/prometheus-operated 9090:9090 -n monitoring
   # Access http://localhost:9090/alerts and check labels on each alert
   ```

## General Debugging Tips

1. **Check AlertManager UI**:
   ```bash
   kubectl port-forward svc/alertmanager-operated 9093:9093 -n monitoring
   # Access http://localhost:9093
   ```

2. **Check Prometheus UI**:
   ```bash
   kubectl port-forward svc/prometheus-operated 9090:9090 -n monitoring
   # Access http://localhost:9090
   ```

3. **Temporarily silence alerts** during maintenance:
   ```bash
   kubectl port-forward svc/alertmanager-operated 9093:9093 -n monitoring
   # Access http://localhost:9093/#/silences and create a silence
   ```

4. **Test alert delivery** with a simple alert rule:
   ```yaml
   - alert: TestAlert
     expr: vector(1)
     labels:
       severity: info
     annotations:
       summary: "Test alert"
       description: "This is a test alert to verify notification delivery"
   ```

5. **Restart components** if needed:
   ```bash
   kubectl rollout restart statefulset/prometheus-prometheus -n monitoring
   kubectl rollout restart statefulset/alertmanager-alertmanager -n monitoring
   ```