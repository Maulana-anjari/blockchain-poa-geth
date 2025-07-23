#!/bin/bash
# File: setup-network-pos.sh
# Automates the one-time setup for a Proof-of-Stake (PoS) network.

set -e
source ./scripts/logger.sh
source ./config.sh

# Direktori utama untuk data PoS
DATA_DIR_POS="./data/pos"

# Jumlah total node
TOTAL_NODES=$((POS_VALIDATOR_COUNT + POS_NON_VALIDATOR_COUNT))

# Fungsi untuk membuat akun Geth dan bootkey
setup_geth_node() {
    local node_index=$1
    local user_id=$2
    local group_id=$3
    local node_dir="$DATA_DIR_POS/node${node_index}"
    local execution_dir="$node_dir/execution"
    local beacondata_dir="$node_dir/consensus/beacondata"
    local validatordata_dir="$node_dir/consensus/validatordata"

    log_info "Creating directories for node $node_index at $node_dir"
    mkdir -p "$execution_dir/geth" "$beacondata_dir" "$validatordata_dir"
    log_success "Directories created."

    log_info "Creating Geth account for node $node_index..."
    ADDR=$(docker run --rm -i \
        --user "$user_id:$group_id" \
        -v "$(pwd)/$execution_dir:/data" \
        -v "$(pwd)/$DATA_DIR_POS/password.pass:/pass" \
        $GETH_IMAGE_TAG_POS \
        geth account new --datadir /data --password /pass \
        | grep "Public address of the key" | awk '{print $NF}')
    
    echo -n "$ADDR" > ./config/addresses/node${node_index}.addr
    sed -i "/^NODE${node_index}_ADDRESS=/d" .env
    echo "NODE${node_index}_ADDRESS=$ADDR" >> .env
    export "NODE${node_index}_ADDRESS=$ADDR"
    log_success "Geth account created: $ADDR"
}

setup_pos_network() {
    log_step "Starting Proof-of-Stake Network Setup"
    
    local USER_ID=$(id -u)
    local GROUP_ID=$(id -g)

    log_step "PoS SETUP: CLEANUP & PREPARATION"
    log_action "Cleaning up previous data and creating PoS directories"
    if [ -f "./destroy-network.sh" ]; then
        chmod +x ./destroy-network.sh && ./destroy-network.sh > /dev/null 2>&1
    fi

    mkdir -p "$DATA_DIR_POS"
    log_success "Created PoS data directory: $DATA_DIR_POS"
    mkdir -p config/{passwords,addresses}

    log_info "Copying genesis and config templates..."
    cp config/pos_template/password.pass "$DATA_DIR_POS/password.pass"
    cp config/pos_template/genesis.json "$DATA_DIR_POS/genesis.json"
    cp config/pos_template/config.yml "$DATA_DIR_POS/config.yml"
    log_success "Copied templates."

    log_step "PoS SETUP: JWT SECRET GENERATION"
    log_action "Generating JWT secret for secure EL-CL communication"
    openssl rand -hex 32 | tr -d "\n" > "$DATA_DIR_POS/jwt.hex"
    export JWT_SECRET_PATH=$(pwd)/$DATA_DIR_POS/jwt.hex
    log_success "JWT secret generated at $DATA_DIR_POS/jwt.hex"

    for i in $(seq 1 $TOTAL_NODES); do
        setup_geth_node $i $USER_ID $GROUP_ID
    done

    log_step "PoS SETUP: CONSENSUS GENESIS & VALIDATOR KEYS"
    log_info "Generating validator keys for $POS_VALIDATOR_COUNT validators..."
    docker run --rm \
        --user "$USER_ID:$GROUP_ID" \
        -v "$(pwd)/$DATA_DIR_POS:/data" $PRYSM_CTL_IMAGE \
        testnet \
        generate-genesis \
        --fork=deneb \
        --num-validators=$POS_VALIDATOR_COUNT \
        --output-ssz=/data/genesis.ssz \
        --chain-config-file=/data/config.yml \
        --geth-genesis-json-in=/data/genesis.json \
        --geth-genesis-json-out=/data/genesis.json
    log_success "Consensus configuration and validator keys generated."

    log_info "Forcing all forks to activate at genesis..."
    jq '.config.shanghaiTime = 0 | .config.cancunTime = 0' "$DATA_DIR_POS/genesis.json" > "$DATA_DIR_POS/genesis.json.tmp" && mv "$DATA_DIR_POS/genesis.json.tmp" "$DATA_DIR_POS/genesis.json"
    log_success "Genesis file updated for immediate fork activation."

    log_info "PoS SETUP: PRE-GENERATE NODE 1 CONSENSUS DATA"
    log_action "Pre-generating consensus data for node 1 to retrieve bootnode ENR"
    local enr_log
    # Run the container in the background and wait for the ENR to be logged
    docker run --rm -d --name temp_prysm_node \
        --user "$USER_ID:$GROUP_ID" \
        -v "$(pwd)/$DATA_DIR_POS/node1/consensus:/data" \
        -v "$(pwd)/$DATA_DIR_POS/genesis.ssz:/genesis.ssz" \
        -v "$(pwd)/$DATA_DIR_POS/config.yml:/config.yml" \
        "$CONSENSUS_CLIENT_IMAGE" \
        --datadir=/data \
        --chain-config-file=/config.yml \
        --genesis-state=/genesis.ssz \
        --p2p-static-id \
        --accept-terms-of-use \
        --min-sync-peers=999 > /dev/null 2>&1

    log_info "Waiting for ENR to be generated..."
    local bootnode_cl_enr=""
    for i in {1..30}; do
        enr_log=$(docker logs temp_prysm_node 2>&1)
        bootnode_cl_enr=$(echo "$enr_log" | grep -o 'ENR="[^"]*"' | cut -d'"' -f2)
        if [ -n "$bootnode_cl_enr" ]; then
            log_success "ENR found!"
            break
        fi
        sleep 1
    done
    docker stop temp_prysm_node > /dev/null 2>&1
    
    local bootnode_cl_enr
    bootnode_cl_enr=$(echo "$enr_log" | grep -o 'ENR="[^"]*"' | cut -d'"' -f2)

    if [ -z "$bootnode_cl_enr" ]; then
        log_error "Could not find bootnode ENR in the container logs."
        log_error "Prysm log output:"
        echo "$enr_log"
        exit 1
    fi

    log_info "Generated ENR: $bootnode_cl_enr"
    log_info "Updating BOOTSTRAP_CL_ENR in .env file..."
    touch .env
    sed -i '/^BOOTSTRAP_CL_ENR=/d' .env
    echo "BOOTSTRAP_CL_ENR=\"$bootnode_cl_enr\"" >> .env
    log_success "Successfully saved BOOTSTRAP_CL_ENR to .env"

    log_info "Initializing Geth for all nodes..."
    for i in $(seq 1 $TOTAL_NODES); do
        local execution_dir="$DATA_DIR_POS/node$i/execution"
        log_info "Initializing Geth for node $i..."
        docker run --rm -i \
            --user "$USER_ID:$GROUP_ID" \
            -v "$(pwd)/$execution_dir:/data" \
            -v "$(pwd)/$DATA_DIR_POS/genesis.json:/genesis.json" \
            $GETH_IMAGE_TAG_POS \
            geth init --datadir /data /genesis.json
    done
    log_success "All Geth nodes initialized."

    log_step "PoS SETUP: DOCKER COMPOSE FILE GENERATION"
    log_action "Generating the docker-compose.pos.yml file"
    chmod +x ./scripts/generate-compose.sh
    ./scripts/generate-compose.sh
    log_success "docker-compose.pos.yml generated."

    log_success "Proof-of-Stake Network Setup Complete!"
    log_info "Total nodes created: $TOTAL_NODES"
    log_info "  - Validator nodes: $POS_VALIDATOR_COUNT"
    log_info "  - Non-validator nodes: $POS_NON_VALIDATOR_COUNT"
}

setup_pos_network