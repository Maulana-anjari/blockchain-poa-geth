#!/bin/bash
# File: destroy-network.sh
# Tears down the network and cleans up all generated artifacts.

# Load the logger library. It's safe even if it's about to be deleted.
if [ -f "./scripts/logger.sh" ]; then
    source ./scripts/logger.sh
else
    # Fallback to simple echo if logger is missing
    log_step() { echo -e "\n=== $1 ==="; }
    log_action() { echo "-> $1..."; }
    log_success() { echo "✅ $1"; }
fi

log_step "DESTROYING NETWORK"

log_action "Stopping and removing all possible network containers and volumes"
# Attempt to tear down both PoA and PoS configurations to ensure a full cleanup.
# The '|| true' prevents errors if one of the files or networks doesn't exist.
if [ -f "docker-compose.poa.yml" ]; then
    docker compose -f docker-compose.poa.yml down -v --remove-orphans > /dev/null 2>&1 || true
fi
if [ -f "docker-compose.pos.yml" ]; then
    docker compose -f docker-compose.pos.yml down -v --remove-orphans > /dev/null 2>&1 || true
fi
log_success "All network services stopped and removed."

log_action "Removing Docker network"
if [ -f ".env" ]; then
    # Load config to get COMPOSE_PROJECT_NAME
    source ./config.sh
    NETWORK_NAME="skripsidchain"
    if docker network ls | grep -q ${NETWORK_NAME}; then
        docker network rm ${NETWORK_NAME} > /dev/null 2>&1
        log_success "Network '${NETWORK_NAME}' removed."
    else
        log_info "Network '${NETWORK_NAME}' not found, skipping."
    fi
fi

log_action "Deleting all generated data, logs, and configuration files"
# Using sudo in case some files were created with root permissions by Docker.
WIPE_SECRETS=${WIPE_SECRETS:-false}

sudo rm -rf \
    ./data \
    ./config/genesis.json \
    ./docker-compose.poa.yml \
    ./docker-compose.pos.yml \
    ./docker-compose.node1.yml \
    ./prysm-debug.log

if [[ "$WIPE_SECRETS" == "true" || "$WIPE_SECRETS" == "1" ]]; then
    log_action "WIPE_SECRETS enabled: deleting config/passwords and config/addresses"
    sudo rm -rf ./config/passwords ./config/addresses
    log_success "Sensitive directories removed."
else
    log_info "Preserving config/passwords and config/addresses (set WIPE_SECRETS=true to delete)."
fi
log_success "All generated artifacts have been deleted."

log_action "Cleaning up dynamic variables from .env file"
if [ -f ".env" ]; then
    # Remove all dynamically generated variables, leaving others intact.
    sed -i \
        -e '/^USER_ID=/d' \
        -e '/^GROUP_ID=/d' \
        -e '/^NODE[0-9]*_ADDRESS=/d' \
        -e '/^ENODE[0-9]*=/d' \
        -e '/^SIGNER[0-9]*_ADDRESS=/d' \
        -e '/^NONSIGNER[0-9]*_ADDRESS=/d' \
        -e '/^BOOTSTRAP_CL_ENR=/d' \
        -e '/^BOOTNODE_ENODE=/d' \
        -e '/^BOOTNODE_EL_ENODE=/d' \
        -e '/^BOOTSTRAP_CL_PEER_ID=/d' \
        .env
    log_success ".env file cleaned."
fi

log_step "CLEANUP COMPLETE"
