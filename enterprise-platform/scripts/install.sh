#!/bin/bash

# Enterprise Platform Installation Script
# This script installs the enterprise platform umbrella Helm chart

set -e

# Configuration
CHART_NAME="enterprise-platform"
RELEASE_NAME="enterprise-platform"
NAMESPACE="enterprise-platform"
ENVIRONMENT="dev"
REGISTRY_SECRET="private-registry-secret"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install the Enterprise Platform Helm chart

Options:
    -n, --namespace NAMESPACE     Kubernetes namespace (default: enterprise-platform)
    -e, --environment ENV         Environment: dev, qa, prod (default: dev)
    -r, --release RELEASE         Helm release name (default: enterprise-platform)
    -s, --registry-secret SECRET  Registry secret name (default: private-registry-secret)
    --registry REGISTRY           Container registry URL (default: my-registry.company.com)
    --registry-user USER          Registry username
    --registry-pass PASS          Registry password
    --registry-email EMAIL        Registry email
    --dry-run                     Perform a dry run
    --upgrade                     Upgrade existing installation
    --uninstall                   Uninstall the platform
    -h, --help                    Show this help message

Examples:
    # Install development environment
    $0 -e dev

    # Install production environment with custom namespace
    $0 -e prod -n production

    # Upgrade existing installation
    $0 --upgrade -e prod

    # Dry run installation
    $0 --dry-run -e qa

    # Create registry secret and install
    $0 -e dev --registry-user myuser --registry-pass mypass --registry-email me@company.com
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -s|--registry-secret)
            REGISTRY_SECRET="$2"
            shift 2
            ;;
        --registry)
            REGISTRY_URL="$2"
            shift 2
            ;;
        --registry-user)
            REGISTRY_USER="$2"
            shift 2
            ;;
        --registry-pass)
            REGISTRY_PASS="$2"
            shift 2
            ;;
        --registry-email)
            REGISTRY_EMAIL="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --upgrade)
            UPGRADE=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|qa|prod)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT. Must be dev, qa, or prod."
    exit 1
fi

# Set default registry if not provided
REGISTRY_URL=${REGISTRY_URL:-"my-registry.company.com"}

log_info "Starting Enterprise Platform installation..."
log_info "Environment: $ENVIRONMENT"
log_info "Namespace: $NAMESPACE"
log_info "Release: $RELEASE_NAME"
log_info "Registry: $REGISTRY_URL"

# Check prerequisites
log_info "Checking prerequisites..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    log_error "helm is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to Kubernetes
if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

log_success "Prerequisites check passed"

# Handle uninstall
if [[ "$UNINSTALL" == "true" ]]; then
    log_info "Uninstalling Enterprise Platform..."
    
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"
        log_success "Helm release uninstalled"
    else
        log_warning "Helm release not found"
    fi
    
    # Optionally delete PVCs (uncomment if needed)
    # log_info "Cleaning up PVCs..."
    # kubectl delete pvc -l app.kubernetes.io/instance="$RELEASE_NAME" -n "$NAMESPACE" --ignore-not-found=true
    
    log_success "Enterprise Platform uninstalled"
    exit 0
fi

# Create namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    log_info "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
    log_success "Namespace created"
else
    log_info "Namespace already exists: $NAMESPACE"
fi

# Create registry secret if credentials are provided
if [[ -n "$REGISTRY_USER" && -n "$REGISTRY_PASS" && -n "$REGISTRY_EMAIL" ]]; then
    log_info "Creating registry secret: $REGISTRY_SECRET"
    
    # Delete existing secret if it exists
    kubectl delete secret "$REGISTRY_SECRET" -n "$NAMESPACE" --ignore-not-found=true
    
    # Create new secret
    kubectl create secret docker-registry "$REGISTRY_SECRET" \
        --docker-server="$REGISTRY_URL" \
        --docker-username="$REGISTRY_USER" \
        --docker-password="$REGISTRY_PASS" \
        --docker-email="$REGISTRY_EMAIL" \
        -n "$NAMESPACE"
    
    log_success "Registry secret created"
elif ! kubectl get secret "$REGISTRY_SECRET" -n "$NAMESPACE" &> /dev/null; then
    log_warning "Registry secret '$REGISTRY_SECRET' not found and credentials not provided"
    log_warning "You may need to create the registry secret manually:"
    log_warning "kubectl create secret docker-registry $REGISTRY_SECRET \\"
    log_warning "  --docker-server=$REGISTRY_URL \\"
    log_warning "  --docker-username=<username> \\"
    log_warning "  --docker-password=<password> \\"
    log_warning "  --docker-email=<email> \\"
    log_warning "  -n $NAMESPACE"
fi

# Update Helm dependencies
log_info "Updating Helm dependencies..."
helm dependency update .
log_success "Dependencies updated"

# Prepare Helm command
HELM_CMD="helm"
VALUES_FILE="environments/${ENVIRONMENT}-values.yaml"

if [[ "$UPGRADE" == "true" ]]; then
    HELM_CMD="$HELM_CMD upgrade"
else
    HELM_CMD="$HELM_CMD install"
fi

HELM_CMD="$HELM_CMD $RELEASE_NAME ."
HELM_CMD="$HELM_CMD --namespace $NAMESPACE"
HELM_CMD="$HELM_CMD --create-namespace"
HELM_CMD="$HELM_CMD --values $VALUES_FILE"
HELM_CMD="$HELM_CMD --set global.imageRegistry=$REGISTRY_URL"
HELM_CMD="$HELM_CMD --set global.imagePullSecrets[0].name=$REGISTRY_SECRET"
HELM_CMD="$HELM_CMD --timeout 10m"

if [[ "$DRY_RUN" == "true" ]]; then
    HELM_CMD="$HELM_CMD --dry-run --debug"
fi

# Check if values file exists
if [[ ! -f "$VALUES_FILE" ]]; then
    log_error "Values file not found: $VALUES_FILE"
    exit 1
fi

# Execute Helm command
log_info "Executing Helm command..."
log_info "Command: $HELM_CMD"

if eval "$HELM_CMD"; then
    if [[ "$DRY_RUN" != "true" ]]; then
        log_success "Enterprise Platform installed successfully!"
        
        # Display installation information
        echo ""
        log_info "Installation Summary:"
        log_info "- Release: $RELEASE_NAME"
        log_info "- Namespace: $NAMESPACE"
        log_info "- Environment: $ENVIRONMENT"
        log_info "- Chart: $CHART_NAME"
        
        echo ""
        log_info "To check the status:"
        echo "  helm status $RELEASE_NAME -n $NAMESPACE"
        
        echo ""
        log_info "To view the pods:"
        echo "  kubectl get pods -n $NAMESPACE"
        
        echo ""
        log_info "To view the services:"
        echo "  kubectl get svc -n $NAMESPACE"
        
        if [[ "$ENVIRONMENT" != "prod" ]]; then
            echo ""
            log_info "To run tests:"
            echo "  helm test $RELEASE_NAME -n $NAMESPACE"
        fi
        
        echo ""
        log_info "To view logs:"
        echo "  kubectl logs -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE"
        
        echo ""
        log_success "Installation completed successfully!"
    else
        log_success "Dry run completed successfully!"
    fi
else
    log_error "Installation failed!"
    exit 1
fi