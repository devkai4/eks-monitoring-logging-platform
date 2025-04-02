# EKS Monitoring and Logging Platform Architecture

This document describes the architecture of the EKS Monitoring and Logging Platform, including the components, their interactions, and deployment patterns.

## Overview

The platform provides comprehensive monitoring and logging capabilities for Kubernetes workloads running on Amazon EKS. It consists of two main stacks:

1. **Monitoring Stack**: Prometheus, Grafana, and AlertManager for metrics collection, visualization, and alerting
2. **Logging Stack**: Elasticsearch, Fluent Bit, and Kibana (EFK) for log collection, storage, and analysis

## Infrastructure Architecture

The platform is deployed on AWS using the following components:

- **Amazon EKS**: Managed Kubernetes service to run containerized applications
- **VPC**: Custom VPC with public and private subnets across multiple availability zones
- **Node Groups**: Managed EC2 instances for running Kubernetes workloads
- **IAM Roles**: Service accounts with specific permissions
- **KMS**: Encryption for Kubernetes secrets

## Component Architecture

### Monitoring Stack

![Monitoring Architecture](images/monitoring-architecture.png)

- **Prometheus**: Collects and stores metrics from Kubernetes clusters and applications
  - Uses ServiceMonitors to discover and scrape targets
  - Persistent storage for metric retention
  - Rules for alerting and recording

- **Grafana**: Visualizes metrics with pre-configured dashboards
  - Dashboard for cluster monitoring
  - Dashboard for node monitoring
  - Dashboard for pod monitoring
  - Connects to Prometheus and Elasticsearch data sources

- **AlertManager**: Manages alerts from Prometheus
  - Routes alerts to receivers
  - Grouping and silencing of alerts
  - Integration with Slack or other notification channels

### Logging Stack

![Logging Architecture](images/logging-architecture.png)

- **Fluent Bit**: Collects logs from containers and nodes
  - Deployed as DaemonSet to run on every node
  - Parses and filters logs
  - Forwards logs to Elasticsearch

- **Elasticsearch**: Stores and indexes logs
  - Distributed search and analytics engine
  - Persistent storage for logs
  - Indices managed by ILM (Index Lifecycle Management)

- **Kibana**: Visualizes and analyzes logs
  - Search interface for logs
  - Dashboards for log visualization
  - Saved searches and visualizations

## Deployment Architecture

The platform uses:

- **Helm Charts**: Package, configure, and deploy applications to Kubernetes
- **Terraform**: Provision and manage AWS infrastructure
- **CI/CD Pipeline**: Automate testing, building, and deployment of the platform
  - GitHub Actions workflow
  - Environment-specific deployments (dev, staging, prod)
  - Infrastructure validation
  - Monitoring stack deployment
  - Logging stack deployment

## Security Architecture

- **Network Security**:
  - Private subnets for EKS nodes
  - Security groups restricting access
  - No direct public exposure of monitoring/logging components

- **Authentication & Authorization**:
  - IAM roles for service accounts
  - RBAC for Kubernetes resources
  - Grafana and Kibana authentication

- **Data Security**:
  - Encryption at rest for persistent volumes
  - TLS for component communication
  - KMS for Kubernetes secrets

## Scalability

- **Prometheus**:
  - Horizontal scalability through sharding
  - Configurable retention and storage

- **Elasticsearch**:
  - Distributed cluster with multiple nodes
  - Shard allocation for performance
  - Index lifecycle management

## High Availability

- Components deployed across multiple availability zones
- Stateful components have appropriate replicas
- Persistent storage for critical data