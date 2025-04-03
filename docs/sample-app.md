# Sample Microservices Application

This document describes the sample microservices application included in the EKS Monitoring Platform. The application is designed to demonstrate metrics collection, alerting, and logging capabilities.

## Architecture

The sample application consists of three interconnected microservices:

1. **Frontend** - NGINX web server with a Prometheus NGINX exporter
   - Serves static content and proxies API requests
   - Exposes NGINX metrics (connections, requests, errors)
   - Acts as the entry point for user traffic

2. **API** - Python Flask application with custom Prometheus metrics
   - Provides RESTful endpoints for data retrieval
   - Tracks request counts, latencies, and error rates
   - Communicates with the database service
   - Includes load generation capabilities for demos

3. **Database** - Simulated database service with custom Prometheus metrics
   - Provides data storage and retrieval functionality
   - Tracks query performance, connection counts, and errors
   - Includes simulated database events for monitoring demonstrations

## Custom Metrics

Each microservice exposes custom Prometheus metrics relevant to its functionality:

### Frontend Metrics
- `nginx_http_connections`
- `nginx_http_requests_total`
- `nginx_http_request_duration_seconds`
- `nginx_http_response_size_bytes`

### API Metrics
- `api_request_count` - Request counts by method, endpoint, and status
- `api_request_latency_seconds` - Request latency histograms
- `api_db_query_count` - Database query counts by type
- `api_active_requests` - Number of active requests
- `api_error_count` - Error counts by type

### Database Metrics
- `db_query_count` - Query counts by type and status
- `db_query_latency_seconds` - Query latency histograms
- `db_connection_count` - Active database connections
- `db_size_bytes` - Simulated database size
- `db_record_count` - Record counts by table
- `db_error_count` - Error counts by type
- `db_connection_pool` - Connection pool statistics
- `db_query_size_bytes` - Query size summaries

## Load Generation

For demonstration purposes, both the API and database services include load generation endpoints:

- `http://[api-service]/load/[intensity]` - Generates API request load
- `http://[database-service]/load/[intensity]` - Generates database query load

The intensity parameter (1-10) controls the volume and duration of the simulated load.

## Deployment

The sample application can be deployed using the provided script:

```bash
./scripts/deploy-sample-app.sh
```

This script:
1. Creates a dedicated namespace (`sample-app`)
2. Deploys all three microservices
3. Sets up ServiceMonitor resources for Prometheus integration
4. Configures proper service discovery

## Accessing the Application

After deployment, you can access the application using port forwarding:

```bash
kubectl -n sample-app port-forward svc/frontend 8080:80
```

Then visit `http://localhost:8080` in your browser.

## Monitoring Integration

The application is fully integrated with the platform's monitoring stack:

1. **Prometheus** collects all custom metrics via ServiceMonitors
2. **Grafana** dashboards visualize application performance
3. **AlertManager** triggers alerts based on application metrics
4. **Fluent Bit** collects application logs
5. **Elasticsearch/Kibana** indexes and visualizes the logs

## Testing Alerts

You can trigger alerts by generating high load:

```bash
# Generate high API load
curl http://localhost:8080/api/load/10

# Generate high database load
curl http://localhost:8080/database/load/10
```

This will create spikes in latency and error rates that should trigger relevant alerts.