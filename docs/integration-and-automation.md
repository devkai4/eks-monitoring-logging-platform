# Integration and Automation

This document describes the integration and automation features available in the EKS Monitoring Platform.

## Overview

The platform provides several integration and automation features to help manage and maintain the monitoring and logging infrastructure:

1. **Metrics and Logging Integration**: Connect Prometheus metrics with Elasticsearch logs for comprehensive observability
2. **Backup and Restore**: Save and restore your monitoring and logging data to/from S3
3. **Operational Checklist**: Automate health checks for your monitoring platform
4. **Consolidated Management**: Single script interface for all integration and automation tasks

## Metrics and Logging Integration

The metrics-logging integration component provides:

- Cross-stack metrics collection (Prometheus monitors the logging stack)
- Elasticsearch data source in Grafana for combined dashboards
- Log-based alerting through Prometheus
- Integrated dashboard for correlating metrics and logs

### Usage

```bash
# Run the integration
./scripts/integrate.sh --integrate-logging-metrics
```

This will:
- Create ServiceMonitor objects for Elasticsearch, Kibana, and Fluent Bit
- Configure Grafana to use Elasticsearch as a data source
- Add log-based alerting rules to Prometheus
- Create an integration dashboard in Grafana

## Backup and Restore

The backup and restore feature provides:

- Backup of Prometheus configuration (rules, service monitors, alert config)
- Backup of Grafana dashboards and data sources
- Backup of Elasticsearch data through snapshots
- Restore capability from any previous backup point

### Usage

```bash
# Backup to S3
./scripts/integrate.sh --backup --bucket my-monitoring-backups

# Restore from S3
./scripts/integrate.sh --restore 20230415120000 --bucket my-monitoring-backups
```

The backup includes:
- Elasticsearch indices via snapshots
- Prometheus rules and configuration
- Grafana dashboards and data sources

## Operational Checklist

The operational checklist feature provides:

- Automated health checks for all components
- Resource usage verification
- Alert status reporting
- Detailed reports for troubleshooting
- Early warning for potential issues

### Usage

```bash
# Run the operational checklist
./scripts/integrate.sh --check
```

The checklist verifies:
- Kubernetes component status
- Monitoring stack health (Prometheus, Grafana, AlertManager)
- Logging stack health (Elasticsearch, Fluent Bit, Kibana)
- Resource usage (disk space, etc.)
- Alerting configuration
- Integration status

## Implementation Details

### Metrics and Logging Integration

The integration works by:

1. Creating ServiceMonitors for logging components to scrape their metrics
2. Adding Elasticsearch as a Grafana data source
3. Creating AlertManager rules that trigger based on log processing issues
4. Providing an integrated dashboard that shows both metrics and log-derived data

### Backup and Restore

The backup mechanism:

1. For Elasticsearch: Uses the Elasticsearch snapshot API to S3
2. For Prometheus: Exports rules and configuration as YAML 
3. For Grafana: Exports dashboards and data sources as JSON/YAML

The restore process reverses these steps, importing the data from S3 back into the respective systems.

### Operational Checklist

The checklist performs:

1. API queries to all components to verify service availability
2. Configuration validation for all components
3. Resource usage evaluation
4. Component-specific health checks
5. Integration verification between components

## Best Practices

1. **Regular Backups**: Schedule regular backups to S3 using a cron job
   ```
   0 1 * * * /path/to/eks-monitoring-platform/scripts/integrate.sh --backup --bucket my-monitoring-backups
   ```

2. **Health Checks**: Run the operational checklist regularly
   ```
   0 */6 * * * /path/to/eks-monitoring-platform/scripts/integrate.sh --check
   ```

3. **Initial Integration**: Always run the integration step after the initial platform deployment
   ```
   ./scripts/integrate.sh --integrate-logging-metrics
   ```

4. **Before Updates**: Run a backup before any platform updates
   ```
   ./scripts/integrate.sh --backup --bucket my-monitoring-backups
   ```

## Troubleshooting

### Metrics and Logging Integration Issues

- Check ServiceMonitor configurations in the monitoring namespace
- Verify Elasticsearch is accessible from Prometheus
- Check if the Elasticsearch data source is properly configured in Grafana

### Backup and Restore Issues

- Verify S3 bucket permissions
- Check the Elasticsearch snapshot repository configuration
- Ensure the proper timestamp is used for restores

### Operational Checklist Issues

- Look at the detailed report file for specific errors
- Verify connectivity to all components
- Check if the proper permissions are available for the script