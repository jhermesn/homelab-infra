#!/bin/bash
# Main orchestration script for the homelab infrastructure.
# Usage: ./deploy.sh [command] [options]
# Help: ./deploy.sh help

set -euo pipefail

# --- Configuration & Constants

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="${SCRIPT_DIR}/services"
ENV_FILE="${SCRIPT_DIR}/.env"

# Output Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

ensure_env_file() {
    local target_dir="$1"
    local env_path="${target_dir}/.env"
    local example_path="${target_dir}/.env.example"

    if [ ! -f "$env_path" ]; then
        if [ ! -f "$example_path" ]; then
            log_error "Neither .env nor .env.example found in ${target_dir}."
            return 1
        fi
    
        log_warning ".env not found in ${target_dir}. Copying from .env.example..."
        cp "$example_path" "$env_path"
        log_warning "Please edit ${env_path} with your configuration!"
        return 1
    fi
    return 0
}

load_script_env() {
    if [ -f "$ENV_FILE" ]; then
        set +u
        source "$ENV_FILE"
        set -u
    fi
}

check_container_health() {
    local services_list="$1"
    log_info "Verifying health of core services..."
    
    # Wait a bit for orchestrator to stabilize
    sleep 5 

    for service in $services_list; do
        if ! docker inspect "$service" &>/dev/null; then
             log_warning "Service '$service' not found (container is not running)."
             continue
        fi

        local health
        health=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "unknown")

        if [ ! "$health" == "healthy" ]; then
            log_warning "$service status: $health"
        fi
        
        log_success "$service is healthy"
    done
}

# --- Infrastructure Management

start_infrastructure() {
    log_info "Starting base infrastructure..."
    
    if ! ensure_env_file "${SCRIPT_DIR}"; then
        exit 1
    fi
    
    load_script_env

    (cd "${SCRIPT_DIR}" && docker compose up -d)
    
    log_info "Waiting for services to initialize..."
    sleep 10
    
    # Define default core services dynamically
    local default_core_services="${MYSQL_CONTAINER_NAME:-homelab-mysql} ${REDIS_CONTAINER_NAME:-homelab-redis} ${LOKI_CONTAINER_NAME:-homelab-loki} ${PROMETHEUS_CONTAINER_NAME:-homelab-prometheus} ${TEMPO_CONTAINER_NAME:-homelab-tempo} ${GRAFANA_CONTAINER_NAME:-homelab-grafana} ${NPM_CONTAINER_NAME:-homelab-npm}"

    # Use env var or default
    local core_services="${CORE_SERVICES:-$default_core_services}"
    check_container_health "$core_services"
    
    log_success "Infrastructure started successfully!"
}

stop_infrastructure() {
    log_info "Stopping base infrastructure..."
    (cd "${SCRIPT_DIR}" && docker compose down)
    log_success "Infrastructure stopped."
}

# --- Service Management

validate_service() {
    local service_name="$1"
    local service_path="$2"

    if [ ! -d "$service_path" ]; then
        log_error "Service not found: ${service_name}"
        return 1
    fi

    # Block specific templates
    if [[ "${service_name}" == "_template" || "${service_name}" == "demo-crud" ]]; then
        log_error "Service '${service_name}' is a template and cannot be started directly."
        return 1
    fi

    return 0
}

start_service() {
    local service_name="$1"
    local service_path="${SERVICES_DIR}/${service_name}"

    validate_service "$service_name" "$service_path" || exit 1

    log_info "Starting service: ${service_name}..."
    
    ensure_env_file "${service_path}" || log_warning "Proceeding without specific .env validation for the service."
    (cd "${service_path}" && docker compose up -d)
    
    log_success "Service ${service_name} started!"
}

stop_service() {
    local service_name="$1"
    local service_path="${SERVICES_DIR}/${service_name}"

    if [ ! -d "$service_path" ]; then
         log_error "Service not found: ${service_name}"
         exit 1
    fi

    log_info "Stopping service: ${service_name}..."
    (cd "${service_path}" && docker compose down)
    log_success "Service ${service_name} stopped!"
}

list_services() {
    log_info "Available Services:"
    if [ -d "$SERVICES_DIR" ]; then
        for dir in "${SERVICES_DIR}"/*/; do
            local name
            name=$(basename "$dir")
            # Filter templates
            if [[ "$name" != "_template" && "$name" != "demo-crud" ]]; then
                echo "  - $name"
            fi
        done
    fi
}

start_all_services() {
    log_info "Starting all detected services..."
    if [ -d "$SERVICES_DIR" ]; then
        for dir in "${SERVICES_DIR}"/*/; do
            local name
            name=$(basename "$dir")
            if [[ "$name" != "_template" && "$name" != "demo-crud" ]] && [ -f "${dir}/docker-compose.yaml" ]; then
                start_service "$name"
            fi
        done
    fi
    log_success "All services startup sequence completed."
}

# --- Main CLI

show_help() {
    echo "Homelab - Deploy CLI"
    echo "Usage:"
    echo "  $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  infra [start|stop]          Manage base infrastructure (default: start)"
    echo "  service <name> [start|stop] Manage specific services"
    echo "  all                         Start infrastructure and all services"
    echo "  list                        List available services"
    echo "  status                      Show status of running containers"
    echo "  logs <container>            Show logs of a container"
}

main() {
    local command="${1:-infra}"
    local arg2="${2:-}"
    local arg3="${3:-}"

    case "$command" in
        (infra)
            local action="${arg2:-start}"
            if [[ "$action" == "stop" ]]; then stop_infrastructure; else start_infrastructure; fi
            ;;
        (service)
            if [ -z "$arg2" ]; then
                log_error "Missing service name."
                list_services
                exit 1
            fi
            local action="${arg3:-start}"
            if [[ "$action" == "stop" ]]; then stop_service "$arg2"; else start_service "$arg2"; fi
            ;;
        (all)
            start_infrastructure
            echo ""
            start_all_services
            ;;
        (list)   list_services ;;
        (status) 
            log_info "Container Status:"
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "homelab" || echo "No containers found."
            ;;
        (logs)
            if [ -z "$arg2" ]; then log_error "Missing container name."; exit 1; fi
            docker logs -f "$arg2"
            ;;
        (help|--help|-h) show_help ;;
        (*) show_help ;;
    esac
}

main "$@"
