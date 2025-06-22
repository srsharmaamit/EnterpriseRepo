#!/bin/bash

# Enterprise Platform Validation Script
# This script validates the Helm chart structure and templates

set -e

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

# Validation functions
validate_chart_structure() {
    log_info "Validating chart structure..."
    
    # Check main chart files
    local required_files=(
        "Chart.yaml"
        "values.yaml"
        "templates/_helpers.tpl"
        "templates/NOTES.txt"
        "README.md"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "✓ $file exists"
        else
            log_error "✗ $file missing"
            return 1
        fi
    done
    
    # Check subcharts
    local subcharts=("airflow" "postgresql" "spark")
    
    for subchart in "${subcharts[@]}"; do
        if [[ -d "charts/$subchart" ]]; then
            log_success "✓ Subchart $subchart exists"
            
            # Check subchart files
            local subchart_files=(
                "charts/$subchart/Chart.yaml"
                "charts/$subchart/values.yaml"
                "charts/$subchart/templates/_helpers.tpl"
            )
            
            for file in "${subchart_files[@]}"; do
                if [[ -f "$file" ]]; then
                    log_success "  ✓ $file exists"
                else
                    log_error "  ✗ $file missing"
                    return 1
                fi
            done
        else
            log_error "✗ Subchart $subchart missing"
            return 1
        fi
    done
    
    log_success "Chart structure validation passed"
}

validate_yaml_syntax() {
    log_info "Validating YAML syntax..."
    
    # Find all YAML files
    local yaml_files
    yaml_files=$(find . -name "*.yaml" -o -name "*.yml" | grep -v ".git")
    
    for file in $yaml_files; do
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            log_success "✓ $file - valid YAML"
        else
            log_error "✗ $file - invalid YAML"
            return 1
        fi
    done
    
    log_success "YAML syntax validation passed"
}

validate_helm_lint() {
    log_info "Running Helm lint..."
    
    # Update dependencies first
    helm dependency update . > /dev/null 2>&1
    
    if helm lint . --strict; then
        log_success "Helm lint passed"
    else
        log_error "Helm lint failed"
        return 1
    fi
}

validate_template_rendering() {
    log_info "Validating template rendering..."
    
    local environments=("dev" "qa" "prod")
    
    for env in "${environments[@]}"; do
        local values_file="environments/${env}-values.yaml"
        
        if [[ -f "$values_file" ]]; then
            log_info "Testing template rendering for $env environment..."
            
            if helm template test-release . --values "$values_file" > /dev/null 2>&1; then
                log_success "✓ Template rendering for $env environment passed"
            else
                log_error "✗ Template rendering for $env environment failed"
                return 1
            fi
        else
            log_warning "Values file for $env environment not found: $values_file"
        fi
    done
    
    log_success "Template rendering validation passed"
}

validate_kubernetes_manifests() {
    log_info "Validating Kubernetes manifests..."
    
    # Generate manifests
    local temp_dir
    temp_dir=$(mktemp -d)
    
    helm template test-release . --values environments/dev-values.yaml > "$temp_dir/manifests.yaml"
    
    # Basic validation using kubectl
    if kubectl apply --dry-run=client -f "$temp_dir/manifests.yaml" > /dev/null 2>&1; then
        log_success "Kubernetes manifest validation passed"
    else
        log_error "Kubernetes manifest validation failed"
        rm -rf "$temp_dir"
        return 1
    fi
    
    rm -rf "$temp_dir"
}

check_best_practices() {
    log_info "Checking Helm best practices..."
    
    local issues=0
    
    # Check for hardcoded values
    if grep -r "localhost" templates/ charts/*/templates/ 2>/dev/null | grep -v "127.0.0.1"; then
        log_warning "Found hardcoded localhost references"
        ((issues++))
    fi
    
    # Check for proper templating
    if grep -r "my-registry" templates/ charts/*/templates/ 2>/dev/null | grep -v "{{"; then
        log_warning "Found hardcoded registry references"
        ((issues++))
    fi
    
    # Check for resource limits
    local manifests
    manifests=$(helm template test-release . --values environments/prod-values.yaml)
    
    if ! echo "$manifests" | grep -q "limits:"; then
        log_warning "No resource limits found in production configuration"
        ((issues++))
    fi
    
    # Check for security contexts
    if ! echo "$manifests" | grep -q "securityContext:"; then
        log_warning "No security contexts found"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        log_success "Best practices check passed"
    else
        log_warning "Best practices check completed with $issues warnings"
    fi
}

# Main validation
main() {
    log_info "Starting Enterprise Platform chart validation..."
    
    # Change to chart directory if script is run from elsewhere
    cd "$(dirname "$0")/.."
    
    local validation_steps=(
        "validate_chart_structure"
        "validate_yaml_syntax"
        "validate_helm_lint"
        "validate_template_rendering"
        "validate_kubernetes_manifests"
        "check_best_practices"
    )
    
    local failed_steps=0
    
    for step in "${validation_steps[@]}"; do
        if ! $step; then
            ((failed_steps++))
        fi
        echo ""
    done
    
    if [[ $failed_steps -eq 0 ]]; then
        log_success "All validation checks passed! 🎉"
        log_info "The chart is ready for deployment."
    else
        log_error "$failed_steps validation step(s) failed."
        log_error "Please fix the issues before deploying."
        exit 1
    fi
}

# Check prerequisites
if ! command -v helm &> /dev/null; then
    log_error "helm is not installed or not in PATH"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed or not in PATH"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    log_error "python3 is not installed or not in PATH"
    exit 1
fi

# Run main validation
main