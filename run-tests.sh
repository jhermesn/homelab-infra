#!/bin/bash
# Utility script to execute K6 load tests within a Docker container.
# Usage: ./run-tests.sh <scenario-name>

# Stop on error, undefined variables and pipe failures
set -euo pipefail

# --- Configuration & Constants

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "${SCRIPT_DIR}/.env" ]; then
    source "${SCRIPT_DIR}/.env"
fi

K6_ROOT_DIR="${SCRIPT_DIR}/tests/k6"
SCENARIOS_DIR="${K6_ROOT_DIR}/scenarios"
DOCKER_IMAGE="${K6_IMAGE:-grafana/k6:latest}"
NETWORK_NAME="${NETWORK_NAME:-homelab-network}"

# Output Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Helper Functions

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

check_dependencies() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker não instalado no PATH."
        exit 1
    fi
}

list_scenarios() {
    if [ ! -d "$SCENARIOS_DIR" ]; then
        log_error "Pasta não encontrada: $SCENARIOS_DIR"
        return 1
    fi

    echo -e "${YELLOW}Cenários Disponíveis:${NC}"
    find "$SCENARIOS_DIR" -maxdepth 1 -name "*.js" -printf "%f\n" | sed 's/\.js$//'
}

resolve_scenario_filename() {
    local scenario_name="$1"
    if [[ "$scenario_name" != *.js ]]; then
        scenario_name="${scenario_name}.js"
    fi
    echo "$scenario_name"
}

run_k6_container() {
    local scenario_filename="$1"
    local local_file_path="${SCENARIOS_DIR}/${scenario_filename}"
    
    if [ ! -f "$local_file_path" ]; then
        log_error "Arquivo de cenário não encontrado: $local_file_path"
        echo ""
        list_scenarios
        exit 1
    fi

    log_info "Iniciando teste de carga: ${scenario_filename}"
    log_info "Rede: ${NETWORK_NAME}"
    log_info "Montando: ${K6_ROOT_DIR} -> /scripts"

    local container_script_path="/scripts/scenarios/${scenario_filename}"

    docker run --rm -i \
        --network "$NETWORK_NAME" \
        -v "${K6_ROOT_DIR}:/scripts" \
        "$DOCKER_IMAGE" run "$container_script_path"
}

main() {
    check_dependencies
    
    if [ $# -eq 0 ]; then
        echo "Uso: $0 <nome-do-cenário>"
        echo ""
        list_scenarios
        exit 1
    fi

    local input_name="$1"
    local scenario_file
    
    scenario_file=$(resolve_scenario_filename "$input_name")
    run_k6_container "$scenario_file"
}

main "$@"