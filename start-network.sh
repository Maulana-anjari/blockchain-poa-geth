#!/bin/bash
# Main orchestrator script for the blockchain network.

set -e

# --- Load Dependencies ---
source ./scripts/logger.sh
source ./config.sh

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

log_action "Tearing down any existing network to ensure a clean start"
docker-compose -f ${COMPOSE_FILE} down --volumes > /dev/null 2>&1 || true
log_success "Previous network services stopped and removed."

log_action "Starting the ${NETWORK_TYPE} network via Docker Compose"
docker-compose -f ${COMPOSE_FILE} up --build -d
log_success "Network deployment complete!"

# --- Final Instructions ---
log_step "NEXT STEPS"
log_info "To monitor logs, run: docker-compose -f ${COMPOSE_FILE} logs -f"
if [ "$NETWORK_TYPE" == "PoA" ]; then
    log_info "Ethstats dashboard: http://localhost:${BASE_MONITORING_HTTP_PORT}"
    log_info "Grafana dashboard: http://localhost:${BASE_GRAFANA_HTTP_PORT}"
fi