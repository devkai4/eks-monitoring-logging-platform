# EKS Monitoring and Logging Platform

A comprehensive monitoring and logging platform for AWS Elastic Kubernetes Service (EKS) clusters, built with industry-standard tools including Prometheus, Grafana, Elasticsearch, Fluent Bit, and Kibana.

## Project Overview

This project implements a complete monitoring and observability solution for Kubernetes workloads running on AWS EKS. It provides:

- Real-time metrics collection and visualization
- Comprehensive logging infrastructure
- Alerting and notification system
- Sample application with custom metrics
- Infrastructure as Code (IaC) through Terraform
- CI/CD pipeline with GitHub Actions

The platform is designed as a portfolio project to demonstrate cloud engineering skills, particularly around AWS, Kubernetes, monitoring, and DevOps practices.

## Architecture

![EKS Monitoring and Logging Platform Architecture](./docs/architecture-diagram.png)

The architecture consists of the following components:

- **AWS EKS Cluster**: Managed Kubernetes service running in a properly configured VPC
- **Monitoring Stack**: Prometheus for metrics collection and Grafana for visualization
- **Logging Stack**: Elasticsearch, Fluent Bit, and Kibana (EFK stack) for log collection and analysis
- **Alerting**: Alertmanager for notification routing to Slack and Email
- **Sample Application**: Microservices demonstrating custom metrics and logging
- **CI/CD**: GitHub Actions for automated deployment and updates

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured with access credentials
- Terraform (v1.0.0+)
- kubectl
- Helm (v3.0.0+)
- Git

## Setup and Deployment

The platform can be deployed in phases following these steps:

### 1. EKS Cluster Setup

```bash
cd terraform
terraform init
terraform apply
```

This will provision:
- Custom VPC with public and private subnets
- EKS cluster with managed node group (t3.medium instances)
- Required IAM roles and security groups

### 2. Monitoring Stack Deployment

```bash
cd kubernetes/prometheus-grafana
kubectl create namespace monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -f values.yaml -n monitoring
```

This installs:
- Prometheus server with persistent storage
- Grafana with preconfigured dashboards
- Alertmanager
- Node Exporter and kube-state-metrics

### 3. Logging Stack Deployment

```bash
cd kubernetes/efk-stack
kubectl apply -f elastic-operator.yaml
kubectl apply -f elasticsearch.yaml
kubectl apply -f kibana.yaml
kubectl apply -f fluent-bit.yaml
```

This sets up:
- Elasticsearch cluster with 3 nodes
- Kibana instance for log visualization
- Fluent Bit DaemonSet for log collection

### 4. Alert Configuration

```bash
cd kubernetes/alerting
kubectl apply -f alertmanager-config.yaml
kubectl apply -f prometheus-rules.yaml
```

This establishes:
- Alert rules for critical system metrics
- Notification channels (Slack and Email)
- Alert grouping and routing policies

### 5. Sample Application Deployment

```bash
cd kubernetes/sample-app
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f service-monitor.yaml
```

This deploys:
- Sample microservices with Prometheus instrumentation
- Service monitors for custom metrics collection
- Structured logging setup

## Customization

The platform is designed to be customizable:

- **Terraform Variables**: Edit `terraform.tfvars` to change infrastructure parameters
- **Helm Values**: Modify `values.yaml` to adjust Prometheus/Grafana settings
- **Elasticsearch Config**: Tune `elasticsearch.yaml` for different storage or performance requirements
- **Alert Rules**: Edit `prometheus-rules.yaml` to customize alerting thresholds

## Dashboards

The platform comes with several pre-configured Grafana dashboards:

1. **Cluster Overview**: High-level view of Kubernetes cluster health
2. **Node Resources**: Detailed node-level metrics (CPU, memory, disk, network)
3. **Pod Resources**: Container-level resource utilization
4. **Capacity Planning**: Trend analysis and resource forecasting
5. **Sample Application**: Custom business and technical metrics

## Troubleshooting

### Common Issues

**EKS Cluster Provisioning Failures**
- Check IAM permissions
- Verify VPC and subnet configurations
- Ensure proper CIDR block assignments

**Prometheus Connection Issues**
- Verify service and pod are running: `kubectl get pods -n monitoring`
- Check service monitor configuration
- Examine Prometheus logs: `kubectl logs -f prometheus-prometheus-kube-prometheus-prometheus-0 -n monitoring`

**Elasticsearch Data Persistence**
- Verify storage class and PVC status: `kubectl get pvc -n logging`
- Check Elasticsearch pods status: `kubectl get pods -n logging`
- Inspect Elasticsearch logs: `kubectl logs -f elasticsearch-master-0 -n logging`

## Future Enhancements

- Integration with AWS CloudWatch for additional metrics
- Enhanced security with AWS Secrets Manager integration
- Multi-cluster federation for centralized monitoring
- Machine learning for anomaly detection
- Cost optimization dashboards

## References

- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Elastic Cloud on Kubernetes](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

Created as a portfolio project to demonstrate cloud engineering and Kubernetes monitoring skills.
