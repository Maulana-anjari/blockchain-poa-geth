#!/bin/bash
# Main orchestrator script for the blockchain network.
# Refactored for improved readability and maintainability.

set -e

# --- Load Dependencies ---
source ./scripts/logger.sh
source ./config.sh

# --- Function Definitions ---

#
# Validates the configuration from the .env file.
# Globals:
#   NETWORK_TYPE
#
validate_configuration() {
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
}

#
# Performs the first-time setup if the data directory does not exist.
# Also re-generates compose file if it's missing.
# Globals:
#   DATA_DIR, NETWORK_TYPE
#
perform_initial_setup() {
    log_step "PHASE 2: CHECKING FOR SETUP STATUS"
    if [ ! -d "${DATA_DIR}" ]; then
      log_info "Data directory not found. Performing first-time setup for ${NETWORK_TYPE} network."
      
      local setup_script=""
      if [ "$NETWORK_TYPE" == "PoA" ]; then
        setup_script="./setup-network-poa.sh"
      elif [ "$NETWORK_TYPE" == "PoS" ]; then
        setup_script="./setup-network-pos.sh"
      fi

      if [ -f "$setup_script" ]; then
        chmod +x "$setup_script" && "$setup_script"
      else
        log_error "Setup script '$setup_script' not found for NETWORK_TYPE '$NETWORK_TYPE'."
      fi
      
      log_success "First-time setup complete."
    else
      log_info "Data directory found. Skipping first-time setup."
      local compose_file="docker-compose.${NETWORK_TYPE,,}.yml"
      if [ ! -f "$compose_file" ]; then
        log_action "Compose file '${compose_file}' is missing, re-generating it"
        chmod +x ./scripts/generate-compose.sh && ./scripts/generate-compose.sh
        log_success "Compose file re-generated."
      fi
    fi
}

#
# Deploys the network using Docker Compose.
# Globals:
#   NETWORK_TYPE, COMPOSE_PROJECT_NAME
#
deploy_network() {
    log_step "PHASE 3: DEPLOYING NETWORK"
    local compose_file="docker-compose.${NETWORK_TYPE,,}.yml"
    local network_name="skripsidchain"

    log_action "Checking for existing Docker network: ${network_name}"
    if ! docker network ls | grep -q "${network_name}"; then
      log_info "Network not found. Creating Docker network: ${network_name}"
      docker network create "${network_name}"
      log_success "Network created."
    else
      log_info "Network already exists."
    fi

    log_action "Tearing down any existing services to ensure a clean start"
    docker compose -f "${compose_file}" down --volumes > /dev/null 2>&1 || true
    log_success "Previous network services stopped and removed."

    log_action "Starting the ${NETWORK_TYPE} network via Docker Compose"
    docker compose -f "${compose_file}" --env-file .env up --build -d
    log_success "Network deployment complete!"
}

#
# Displays the network status and instructions for interaction.
# Globals:
#   NETWORK_TYPE, NUM_SIGNERS, NUM_NONSIGNERS, POS_VALIDATOR_COUNT, POS_NON_VALIDATOR_COUNT
#   BASE_GETH_HTTP_PORT, BASE_MONITORING_HTTP_PORT, BASE_GRAFANA_HTTP_PORT
#
display_status() {
    local type=$NETWORK_TYPE
    local compose_file="docker-compose.${type,,}.yml"

    log_action "Network Status"
    docker compose -f "$compose_file" ps
    log_action "Instructions"

    if [ "$type" == "PoA" ]; then
        log_info "PoA network is running."
        log_info "You can attach to any node using its RPC endpoint."
        log_info "Available RPC endpoints:"
        local boot_label
        boot_label=$(get_poa_nonsigner_label 1)
        local boot_display=${boot_label:-nonsigner1}
        echo "  - ${boot_display} (non-signer bootnode): http://localhost:${BASE_GETH_HTTP_PORT}"
        for i in $(seq 1 "$NUM_SIGNERS"); do
            local http_port=$((BASE_GETH_HTTP_PORT + (i * 2) + 10))
            local signer_label
            signer_label=$(get_poa_signer_label "$i")
            local signer_display=${signer_label:-signer${i}}
            echo "  - ${signer_display} (signer): http://localhost:${http_port}"
        done
        if [ "$NUM_NONSIGNERS" -gt 1 ]; then
            for i in $(seq 2 "$NUM_NONSIGNERS"); do
                local http_port=$((BASE_GETH_HTTP_PORT + (NUM_SIGNERS * 2) + (i * 2) + 20))
                local nonsigner_label
                nonsigner_label=$(get_poa_nonsigner_label "$i")
                local nonsigner_display=${nonsigner_label:-nonsigner${i}}
                echo "  - ${nonsigner_display} (non-signer): http://localhost:${http_port}"
            done
        fi
    elif [ "$type" == "PoS" ]; then
        log_info "PoS network is running."
        log_info "Consensus (Beacon) and Execution (Geth) clients are running for each node."
        log_info "Validator clients are running for validator nodes."
        local total_nodes=$((POS_VALIDATOR_COUNT + POS_NON_VALIDATOR_COUNT))
        log_info "Available Geth RPC endpoints:"
        for i in $(seq 1 "$total_nodes"); do
            echo "  - Node $i: http://localhost:$((8545 + i - 1))"
        done
        log_info "Available Beacon GRPC endpoints:"
        for i in $(seq 1 "$total_nodes"); do
            echo "  - Node $i: http://localhost:$((4000 + i - 1))"
        done

        log_info "Open Consensus Node 1 Log, then copy the current ENR to BOOTSTRAP_CL_ENR in .env, then run:"
        log_info "docker compose -f docker-compose.pos.yml --env-file .env up --build -d"
        echo ""
        log_info "To check the peer-to-peer connectivity of the execution nodes, run: ./pos-connection-test.sh"
        log_info "If the execution nodes are not yet connected, run : ./pos-connect-peers.sh"
        echo ""
        log_info "How to check if consensus node 1 and 2 are connected:"
        log_info "curl -s http://localhost:3500/eth/v1/node/peers | jq"
        log_info "curl -s http://localhost:3501/eth/v1/node/peers | jq"
        echo "  - If 'state' is \"connected\" in the output, it means they are connected."
        echo "  - You should see consensus_node2 in the peer list of consensus_node1, and vice versa."
        echo "  - 'direction' will indicate whether the connection is inbound or outbound."
        echo ""
    fi

    log_info "To monitor logs, run: docker compose -f ${compose_file} logs -f"
    log_info "Ethstats dashboard: http://localhost:${BASE_MONITORING_HTTP_PORT}"
    log_info "Grafana dashboard: http://localhost:${BASE_GRAFANA_HTTP_PORT}"
    log_info "To stop the network, run: ./destroy-network.sh"
}

#
# Main execution function.
#
main() {
    validate_configuration
    perform_initial_setup
    deploy_network
    display_status
}

# --- Script Entrypoint ---
main
