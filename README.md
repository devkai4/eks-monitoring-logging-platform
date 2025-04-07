# EKS Monitoring and Logging Platform

![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=Prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/grafana-%23F46800.svg?style=for-the-badge&logo=grafana&logoColor=white)
![Elasticsearch](https://img.shields.io/badge/Elasticsearch-005571?style=for-the-badge&logo=elasticsearch&logoColor=white)

## Overview

This project implements a comprehensive monitoring and logging platform built on AWS EKS (Elastic Kubernetes Service). It leverages industry-standard tools like Prometheus, Grafana, and the Elasticsearch stack to provide visibility into cluster and application health, performance metrics, and centralized logging capabilities.

## Architecture

![Architecture Diagram](./docs/architecture/architecture-overview.png)

The platform consists of the following components:

- **AWS EKS**: Managed Kubernetes service
- **Prometheus**: Metrics collection and storage
- **Grafana**: Metrics visualization and dashboards
- **Elasticsearch**: Log data storage and search
- **Fluent Bit**: Log collection and forwarding
- **Kibana**: Log data visualization and analysis
- **Alertmanager**: Alert management and notification

## Prerequisites

- AWS CLI installed and configured with appropriate permissions
- Terraform v1.6.0+
- kubectl v1.27.0+
- Helm v3.12.0+

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/devkai4/eks-monitoring-logging-platform.git
cd eks-monitoring-logging-platform
```

### 2. Infrastructure Provisioning

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 3. Configure kubeconfig

```bash
aws eks update-kubeconfig --name eks-monitoring-cluster --region <your-region>
```

### 4. Deploy Monitoring Components

```bash
cd ../../../kubernetes
kubectl apply -f monitoring/namespace.yaml
kubectl apply -f monitoring/prometheus/
kubectl apply -f monitoring/grafana/
```

### 5. Deploy Logging Components

```bash
kubectl apply -f logging/namespace.yaml
kubectl apply -f logging/elasticsearch/
kubectl apply -f logging/fluent-bit/
kubectl apply -f logging/kibana/
```

### 6. Deploy Alerting System

```bash
kubectl apply -f alerting/alertmanager/
```

### 7. Deploy Sample Application

```bash
kubectl apply -f sample-app/
```

## Accessing Components

After setup is complete, you can access the components at the following URLs:

- **Grafana**: http://grafana.your-domain.com (default login: admin/admin)
- **Prometheus**: http://prometheus.your-domain.com
- **Alertmanager**: http://alertmanager.your-domain.com
- **Kibana**: http://kibana.your-domain.com

Note: Update URLs based on your actual domain configuration.

## Key Features

- Resource utilization monitoring for cluster nodes and pods
- Application performance metrics collection and visualization
- Centralized management of system and application logs
- Anomaly detection and alert notification
- Operational visibility through custom dashboards
- Robust infrastructure managed as code with Terraform
- Kubernetes-native deployment of all components

## Project Structure

```
eks-monitoring-platform/
├── terraform/          # Infrastructure as Code
│   ├── modules/        # Reusable Terraform modules
│   └── environments/   # Environment-specific configurations
├── kubernetes/         # Kubernetes manifests
│   ├── monitoring/     # Prometheus and Grafana configurations
│   ├── logging/        # EFK stack configurations
│   └── alerting/       # Alertmanager configurations
├── docs/               # Documentation
└── scripts/            # Utility scripts
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[MIT](LICENSE)

## References

- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Elasticsearch Documentation](https://www.elastic.co/guide/index.html)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Roadmap

- [x] Initial repository structure
- [ ] EKS cluster setup with Terraform
- [ ] Prometheus and Grafana deployment
- [ ] EFK stack deployment
- [ ] Sample application with custom metrics
- [ ] Alert configuration
- [ ] Documentation and architecture diagrams
- [ ] CI/CD pipeline with GitHub Actions
