#!/bin/bash
# File: setup-network-pos.sh
# Automates the one-time setup for a Proof-of-Stake (PoS) network.

set -e
source ./scripts/logger.sh
source ./config.sh

log_step "PoS SETUP: CLEANUP & PREPARATION"
log_action "Cleaning up previous data and creating PoS directories"
if [ -f "./destroy-network.sh" ]; then
    chmod +x ./destroy-network.sh && ./destroy-network.sh > /dev/null 2>&1
fi
mkdir -p ./data/pos/jwtsecret
mkdir -p ./data/pos/consensus/beacondata
mkdir -p ./data/pos/consensus/validatordata
mkdir -p ./data/pos/execution/geth
mkdir -p ./config/pos
log_success "Directories created."

log_step "PoS SETUP: JWT SECRET GENERATION"
log_action "Generating JWT secret for secure EL-CL communication"
openssl rand -hex 32 | tr -d "\n" > ./data/pos/jwtsecret/jwt.hex
export JWT_SECRET_PATH=$(pwd)/data/pos/jwtsecret/jwt.hex
log_success "JWT secret generated at: ${JWT_SECRET_PATH}"

log_step "PoS SETUP: CONSENSUS GENESIS & VALIDATOR KEYS"
log_action "Generating consensus layer genesis and validator keys using Prysm"
log_info "This may take a moment..."
docker run --rm -it \
    -v $(pwd)/config/pos:/conf \
    -v $(pwd)/data/pos/consensus/validatordata:/validator_keys \
    -v $(pwd)/config/genesis.template.pos.json:/genesis_in.json \
    -v $(pwd)/config/genesis.json:/genesis_out.json \
    ${CONSENSUS_CLIENT_IMAGE} \
    testnet-generator \
    --fork-version=0x00000079 \
    --num-validators=${NUM_VALIDATORS} \
    --output-ssz=/conf/genesis.ssz \
    --chain-config-file=/conf/config.yml \
    --geth-genesis-json-in=/genesis_in.json \
    --geth-genesis-json-out=/genesis_out.json
log_success "Consensus configuration and validator keys generated."

log_step "PoS SETUP: DOCKER COMPOSE FILE GENERATION"
log_action "Generating the docker-compose.pos.yml file"
chmod +x ./scripts/generate-compose.sh
./scripts/generate-compose.sh
log_success "docker-compose.pos.yml generated."