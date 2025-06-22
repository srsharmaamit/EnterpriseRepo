# Enterprise Platform Helm Chart

A production-ready umbrella Helm chart for deploying an enterprise data platform consisting of Apache Airflow, PostgreSQL, and Apache Spark on Kubernetes/OpenShift.

## Overview

This chart deploys:
- **Apache Airflow** with KubernetesExecutor for workflow orchestration
- **PostgreSQL** as the metadata database for Airflow
- **Apache Spark** in Kubernetes-native mode for data processing

## Prerequisites

- Kubernetes 1.19+ or OpenShift 4.8+
- Helm 3.8+
- PV provisioner support in the underlying infrastructure
- Private registry access for custom Docker images

## Installation

### Quick Start

```bash
# Add your private registry secret
kubectl create secret docker-registry private-registry-secret \
  --docker-server=my-registry.company.com \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email>

# Install the chart
helm install enterprise-platform ./enterprise-platform
```

### Environment-Specific Installation

```bash
# Development environment
helm install enterprise-platform ./enterprise-platform \
  --set global.environment=dev \
  --set airflow.resources.scheduler.requests.cpu=100m \
  --set postgresql.storage.data.size=1Gi

# Production environment
helm install enterprise-platform ./enterprise-platform \
  --set global.environment=prod \
  --set airflow.resources.scheduler.requests.cpu=1000m \
  --set postgresql.storage.data.size=50Gi
```

## Configuration

### Global Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageRegistry` | Private registry URL | `my-registry.company.com` |
| `global.imagePullSecrets` | Image pull secrets | `[private-registry-secret]` |
| `global.environment` | Environment (dev/qa/prod) | `dev` |
| `global.storageClass` | Storage class for PVCs | `""` (default) |
| `global.useBYOS` | Use bring-your-own-storage | `false` |
| `global.openshift.enabled` | Enable OpenShift compatibility | `true` |
| `global.openshift.scc` | Security Context Constraint | `restricted-v2` |

### Apache Airflow Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `airflow.enabled` | Enable Airflow deployment | `true` |
| `airflow.image.repository` | Airflow image repository | `my-registry/airflow` |
| `airflow.image.tag` | Airflow image tag | `custom` |
| `airflow.executor` | Airflow executor type | `KubernetesExecutor` |
| `airflow.storage.logs.size` | Logs PVC size | `5Gi` |
| `airflow.storage.dags.size` | DAGs PVC size | `1Gi` |
| `airflow.ingress.enabled` | Enable ingress/route | `true` |
| `airflow.ingress.host` | Ingress hostname | `airflow.company.com` |

### PostgreSQL Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Enable PostgreSQL deployment | `true` |
| `postgresql.image.repository` | PostgreSQL image repository | `my-registry/postgres` |
| `postgresql.image.tag` | PostgreSQL image tag | `custom` |
| `postgresql.database.name` | Database name | `airflow` |
| `postgresql.database.username` | Database username | `airflow` |
| `postgresql.storage.data.size` | Data PVC size | `10Gi` |

### Apache Spark Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `spark.enabled` | Enable Spark deployment | `true` |
| `spark.image.repository` | Spark image repository | `my-registry/spark` |
| `spark.image.tag` | Spark image tag | `custom` |
| `spark.mode` | Spark execution mode | `k8s-native` |
| `spark.storage.checkpoint.size` | Checkpoint PVC size | `2Gi` |
| `spark.storage.scratch.size` | Scratch PVC size | `2Gi` |
| `spark.rbac.create` | Create RBAC resources | `true` |

## Custom Images

This chart expects custom Docker images for all components:

### Required Images
- `my-registry/airflow:custom` - Custom Airflow image
- `my-registry/postgres:custom` - Custom PostgreSQL image  
- `my-registry/spark:custom` - Custom Spark image

### Image Requirements

#### Airflow Image
- Based on Apache Airflow 2.5+
- Include required providers (kubernetes, postgres)
- KubernetesExecutor support
- Custom DAGs included in image or mounted

#### PostgreSQL Image
- PostgreSQL 13+ compatible
- Optimized configuration for Airflow metadata

#### Spark Image
- Apache Spark 3.3+ with Kubernetes support
- Hadoop libraries for cloud storage access
- Custom JARs and dependencies included

## Environment Overlays

The chart supports environment-specific configurations:

### Development (dev)
- Reduced resource requests
- Single replica deployments
- Smaller storage allocations

### Quality Assurance (qa)
- Moderate resource allocation
- Multiple replicas for testing
- Medium storage allocation

### Production (prod)
- Full resource allocation
- High availability setup
- Large storage allocation

## Security

### OpenShift Compatibility
- Security Context Constraints (SCC) support
- Non-root container execution
- Proper fsGroup and runAsUser settings

### RBAC
- Service accounts for each component
- Minimal required permissions
- Spark-specific Kubernetes API access

### Secrets Management
- Database credentials stored in Kubernetes secrets
- Image pull secrets for private registry
- Configuration separation by environment

## Networking

### Services
- **Airflow WebServer**: ClusterIP service on port 8080
- **PostgreSQL**: ClusterIP service on port 5432
- **Spark**: Dynamic service creation for jobs

### Ingress/Routes
- OpenShift Route support with TLS termination
- Standard Kubernetes Ingress compatibility
- Configurable hostname and TLS settings

## Storage

### Persistent Volumes
- **Airflow Logs**: Persistent storage for workflow execution logs
- **Airflow DAGs**: Storage for DAG definitions (if not embedded in image)
- **PostgreSQL Data**: Database storage with configurable size
- **Spark Checkpoints**: RDD checkpoint storage
- **Spark Scratch**: Temporary storage for Spark jobs

### Storage Classes
- Default storage class usage
- BYOS (Bring Your Own Storage) support
- Environment-specific storage sizing

## Monitoring and Observability

### Metrics Endpoints
- Airflow: StatsD metrics on port 8125
- PostgreSQL: postgres_exporter metrics on port 9187  
- Spark: Spark UI metrics on port 4040

### Prometheus Integration
- Automatic service discovery annotations
- `/metrics` endpoint exposure
- Grafana dashboard compatibility

## Troubleshooting

### Common Issues

#### Image Pull Errors
```bash
# Verify image pull secret
kubectl get secret private-registry-secret -o yaml

# Test image access
kubectl run test --image=my-registry/airflow:custom --restart=Never
```

#### Storage Issues
```bash
# Check PVC status
kubectl get pvc -l app.kubernetes.io/instance=enterprise-platform

# Verify storage class
kubectl get storageclass
```

#### OpenShift Security Context
```bash
# Check SCC assignment
kubectl get pods -o yaml | grep scc

# Verify security context
kubectl describe pod <pod-name>
```

### Logs
```bash
# Airflow scheduler logs
kubectl logs -l component=scheduler -c scheduler

# Airflow webserver logs  
kubectl logs -l component=webserver -c webserver

# PostgreSQL logs
kubectl logs -l component=postgresql

# Spark driver logs (for running jobs)
kubectl logs <spark-driver-pod>
```

## GitOps Integration

### GitLab CI/CD Pipeline Example

```yaml
deploy-dev:
  stage: deploy
  script:
    - helm upgrade --install enterprise-platform ./enterprise-platform 
        --set global.environment=dev
        --set global.imageRegistry=$CI_REGISTRY
        --set airflow.image.tag=$CI_COMMIT_SHA
        --values environments/dev-values.yaml
  environment:
    name: development
    
deploy-prod:
  stage: deploy
  script:
    - helm upgrade --install enterprise-platform ./enterprise-platform
        --set global.environment=prod
        --set global.imageRegistry=$CI_REGISTRY  
        --set airflow.image.tag=$CI_COMMIT_TAG
        --values environments/prod-values.yaml
  environment:
    name: production
  only:
    - tags
```

### Environment Values Files

Create environment-specific values files:

**environments/dev-values.yaml**
```yaml
global:
  environment: dev
airflow:
  resources:
    scheduler:
      requests:
        cpu: 100m
        memory: 512Mi
postgresql:
  storage:
    data:
      size: 1Gi
```

**environments/prod-values.yaml**
```yaml
global:
  environment: prod
airflow:
  resources:
    scheduler:
      requests:
        cpu: 1000m
        memory: 2Gi
postgresql:
  storage:
    data:
      size: 50Gi
```

## Upgrading

```bash
# Update dependencies
helm dependency update ./enterprise-platform

# Upgrade release
helm upgrade enterprise-platform ./enterprise-platform

# Rollback if needed
helm rollback enterprise-platform 1
```

## Uninstalling

```bash
# Uninstall the release
helm uninstall enterprise-platform

# Clean up PVCs (if needed)
kubectl delete pvc -l app.kubernetes.io/instance=enterprise-platform
```

## Contributing

1. Follow Helm best practices
2. Update documentation for configuration changes
3. Test on both Kubernetes and OpenShift
4. Ensure backward compatibility

## License

Apache License 2.0