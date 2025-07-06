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
    docker-compose -f docker-compose.poa.yml down -v --remove-orphans > /dev/null 2>&1 || true
fi
if [ -f "docker-compose.pos.yml" ]; then
    docker-compose -f docker-compose.pos.yml down -v --remove-orphans > /dev/null 2>&1 || true
-
fi
log_success "All network services stopped and removed."

log_action "Deleting all generated data, logs, and configuration files"
# Using sudo in case some files were created with root permissions by Docker.
sudo rm -rf \
    ./data \
    ./config/passwords \
    ./config/addresses \
    ./config/genesis.json \
    ./config/pos \
    ./docker-compose.poa.yml \
    ./docker-compose.pos.yml \
log_success "All generated artifacts have been deleted."

log_step "CLEANUP COMPLETE"
