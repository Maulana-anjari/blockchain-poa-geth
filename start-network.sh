#!/bin/bash
# Main orchestrator script for the blockchain network.

set -e

# --- Load Dependencies ---
source ./scripts/logger.sh
source ./config.sh

# Function to display network status and instructions
display_status() {
    local type=$1
    local compose_file="docker-compose.$type.yml"

    log_action "Network Status"
    docker-compose -f $compose_file ps
    log_action "Instructions"

    if [ "$type" == "PoA" ]; then
        log_info "PoA network is running."
        log_info "You can attach to any node using its RPC endpoint."
        log_info "Example for node 1: geth attach http://localhost:8545"
        local total_nodes=$((POA_NODE_COUNT + POA_NON_SEALER_COUNT))
        log_info "Available RPC endpoints:"
        for i in $(seq 1 $total_nodes); do
            echo "  - Node $i: http://localhost:$((8545 + i - 1))"
        done
    elif [ "$type" == "PoS" ]; then
        log_info "PoS network is running."
        log_info "Consensus (Beacon) and Execution (Geth) clients are running for each node."
        log_info "Validator clients are running for validator nodes."
        local total_nodes=$((POS_VALIDATOR_COUNT + POS_NON_VALIDATOR_COUNT))
        log_info "Available Geth RPC endpoints:"
        for i in $(seq 1 $total_nodes); do
            echo "  - Node $i: http://localhost:$((8545 + i - 1))"
        done
        log_info "Available Beacon GRPC endpoints:"
        for i in $(seq 1 $total_nodes); do
            echo "  - Node $i: http://localhost:$((4000 + i - 1))"
        done
    fi

    log_info "To monitor logs, run: docker-compose -f ${COMPOSE_FILE} logs -f"
    log_info "Ethstats dashboard: http://localhost:${BASE_MONITORING_HTTP_PORT}"
    log_info "Grafana dashboard: http://localhost:${BASE_GRAFANA_HTTP_PORT}"
    log_info "To stop the network, run: ./destroy-network.sh $type"
}

# --- Pre-flight Checks ---
log_step "PHASE 1: VALIDATING CONFIGURATION"
log_action "Checking .env file"
if [ ! -f .env ]; then
  log_error ".env file not found. Please create one from .env.example."
fi
log_success ".env file found."

log_action "Validating NETWORK_TYPE"
if [ "$NETWORK_TYPE" != "PoA" ] && [ "$NETWORK_TYPE" != "PoS" ]; then
  log_error "Invalid NETWORK_TYPE. Set it to 'PoA' or 'PoS' in the .env file."
fi
log_success "NETWORK_TYPE is valid: ${NETWORK_TYPE}"

# --- Initial Setup Logic ---
log_step "PHASE 2: CHECKING FOR FIRST-TIME SETUP"
if [ ! -d "${DATA_DIR}" ]; then
  log_info "Data directory not found. Performing first-time setup for ${NETWORK_TYPE} network."
  
  SETUP_SCRIPT=""
  if [ "$NETWORK_TYPE" == "PoA" ]; then
    SETUP_SCRIPT="./setup-network-poa.sh"
  elif [ "$NETWORK_TYPE" == "PoS" ]; then
    SETUP_SCRIPT="./setup-network-pos.sh"
  fi

  if [ -f "$SETUP_SCRIPT" ]; then
    chmod +x $SETUP_SCRIPT && $SETUP_SCRIPT
  else
    log_error "Setup script '$SETUP_SCRIPT' not found for NETWORK_TYPE '$NETWORK_TYPE'."
  fi
  
  log_success "First-time setup complete."
else
  log_info "Data directory found. Skipping first-time setup."
  COMPOSE_FILE="docker-compose.${NETWORK_TYPE,,}.yml"
  if [ ! -f "$COMPOSE_FILE" ]; then
    log_action "Compose file '${COMPOSE_FILE}' is missing, re-generating it"
    chmod +x ./scripts/generate-compose.sh && ./scripts/generate-compose.sh
    log_success "Compose file re-generated."
  fi
fi

# --- Network Deployment ---
log_step "PHASE 3: DEPLOYING NETWORK"
COMPOSE_FILE="docker-compose.${NETWORK_TYPE,,}.yml"
# Construct the network name from the .env file for consistency.
NETWORK_NAME=${COMPOSE_PROJECT_NAME}_net

log_action "Checking for existing Docker network: ${NETWORK_NAME}"
if ! docker network ls | grep -q ${NETWORK_NAME}; then
  log_info "Network not found. Creating Docker network: ${NETWORK_NAME}"
  docker network create ${NETWORK_NAME}
  log_success "Network created."
else
  log_info "Network already exists."
fi

log_action "Tearing down any existing network to ensure a clean start"
docker-compose -f ${COMPOSE_FILE} down --volumes > /dev/null 2>&1 || true
log_success "Previous network services stopped and removed."

log_action "Starting the ${NETWORK_TYPE} network via Docker Compose"
docker-compose -f ${COMPOSE_FILE} up --build -d
log_success "Network deployment complete!"

# --- Final Instructions ---
display_status $NETWORK_TYPE