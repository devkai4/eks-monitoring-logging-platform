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

![EKS Monitoring and Logging Platform Architecture](./docs/images/architecture-overview.png)

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
- Terraform (v1.4.6+)
- kubectl (v1.26.0+)
- Helm (v3.0.0+)
- Git

## Setup and Deployment

The platform can be deployed through either the automatic CI/CD pipeline or manually through these steps:

### Automated Deployment (Recommended)

1. Fork this repository
2. Set up the required GitHub Actions secrets:
   - `AWS_ROLE_TO_ASSUME`: ARN of the IAM role with necessary permissions
3. Trigger the workflow manually through GitHub Actions for your desired environment (dev/staging/prod)

### Manual Deployment

#### 1. Infrastructure Deployment

```bash
cd terraform
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

This will provision:
- Custom VPC with public and private subnets
- EKS cluster with managed node groups
- Required IAM roles and security groups
- KMS encryption for secrets

#### 2. Monitoring & Logging Stack Deployment

Use the provided installation script:
```bash
# Makes the script executable
chmod +x scripts/install.sh
# Installs the complete monitoring and logging stack
./scripts/install.sh dev
```

Or deploy individual components:

```bash
# Update your kubeconfig
aws eks update-kubeconfig --name eks-monitoring-dev --region ap-northeast-1

# Deploy Prometheus Stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -f kubernetes/prometheus/values.yaml \
  --namespace monitoring --create-namespace

# Deploy Elasticsearch & Kibana
helm repo add elastic https://helm.elastic.co
helm upgrade --install elasticsearch elastic/elasticsearch \
  -f kubernetes/elasticsearch/values.yaml \
  --namespace logging --create-namespace
helm upgrade --install kibana elastic/kibana \
  -f kubernetes/kibana/values.yaml \
  --namespace logging

# Deploy Fluent Bit
helm repo add fluent https://fluent.github.io/helm-charts
helm upgrade --install fluent-bit fluent/fluent-bit \
  -f kubernetes/fluentbit/values.yaml \
  --namespace logging

# Deploy Sample Microservices Application
./scripts/deploy-sample-app.sh
```

## Customization

The platform is designed to be customizable:

- **Terraform Variables**: Edit variables in the Terraform configuration to change infrastructure parameters
- **Helm Values**: Modify the various `values.yaml` files to adjust component settings
  - `kubernetes/prometheus/values.yaml`: Prometheus and Grafana settings
  - `kubernetes/elasticsearch/values.yaml`: Elasticsearch configuration
  - `kubernetes/kibana/values.yaml`: Kibana settings
  - `kubernetes/fluentbit/values.yaml`: Log collection configuration
  - `kubernetes/alertmanager/values.yaml`: Alert routing configuration
- **CI/CD Pipeline**: Adjust workflow in `.github/workflows/main.yml`

## Features

### Monitoring

- **Real-time metrics collection** from Kubernetes nodes, pods, and applications
- **Pre-configured dashboards** for cluster, node, and pod monitoring including:
  - Cluster Overview Dashboard
  - Node Details Dashboard
  - Application Performance Dashboard
  - Service SLA Dashboard
  - Resource Planning Dashboard
- **Alerting system** for critical issues and performance anomalies
- **ServiceMonitor** support for automatic discovery of custom metrics endpoints
- **Persistent storage** for long-term metric retention
- **Sample microservices** with custom metrics exporters for demonstrations

### Logging

- **Centralized logging** from all containers and system components
- **Structured log parsing** with Fluent Bit
- **Full-text search** capabilities through Elasticsearch
- **Log visualization** with Kibana dashboards
- **Log retention policies** for compliance and space management

### CI/CD Pipeline

- **Multi-environment support** (dev, staging, prod)
- **Infrastructure validation** with Terraform lint and validate
- **Kubernetes manifest validation** with kubeval
- **Automatic deployment** of Terraform and Kubernetes resources
- **Deployment verification** with health checks
- **Deployment reports** for visibility and troubleshooting

## Accessing the Platform

After deployment, access the components with the following commands:

```bash
# Grafana (monitoring dashboard)
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# Open http://localhost:3000 (user: admin, password: admin)

# Prometheus (metrics)
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
# Open http://localhost:9090

# Kibana (logs)
kubectl port-forward svc/kibana-kibana 5601:5601 -n logging
# Open http://localhost:5601 (user: elastic, password: displayed after install)

# Elasticsearch (log storage)
kubectl port-forward svc/elasticsearch-master 9200:9200 -n logging
# Access via http://localhost:9200
```

## Troubleshooting

A comprehensive troubleshooting guide is available at [docs/troubleshooting.md](docs/troubleshooting.md). Common issues include:

- **EKS Cluster Provisioning Failures**
  - Check IAM permissions and VPC configurations
  - Verify AWS CLI configuration and access

- **Monitoring Stack Issues**
  - Prometheus pods not starting or scraping issues
  - Grafana data source configuration problems

- **Logging Stack Issues**
  - Elasticsearch cluster health problems
  - Fluent Bit to Elasticsearch connectivity issues

## Documentation

- [Architecture Documentation](docs/architecture.md): Detailed system design
- [Troubleshooting Guide](docs/troubleshooting.md): Solutions for common issues

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
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

Created as a portfolio project to demonstrate cloud engineering and Kubernetes monitoring skills.
