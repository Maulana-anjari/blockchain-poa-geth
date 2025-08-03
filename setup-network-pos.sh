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

# Global variables for bootnode details, will be set by generate_bootnode_details
bootnode_cl_enr=""
bootnode_cl_peer_id=""

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

cleanup_and_prepare() {
    log_step "PoS SETUP: CLEANUP & PREPARATION"
    log_action "Cleaning up previous data and creating PoS directories"
    if [ -f "./destroy-network.sh" ]; then
        chmod +x ./destroy-network.sh && ./destroy-network.sh > /dev/null 2>&1
    fi

    local network_name="skripsidchain"
    if ! docker network inspect "$network_name" >/dev/null 2>&1; then
        log_info "Creating Docker network: $network_name"
        docker network create --driver bridge "$network_name"
        log_success "Network $network_name created."
    else
        log_info "Docker network $network_name already exists."
    fi

    mkdir -p "$DATA_DIR_POS"
    log_success "Created PoS data directory: $DATA_DIR_POS"
    mkdir -p config/{passwords,addresses}

    log_info "Copying genesis and config templates..."
    cp config/pos_template/password.pass "$DATA_DIR_POS/password.pass"
    cp config/pos_template/genesis.json "$DATA_DIR_POS/genesis.json"
    cp config/pos_template/config.yml "$DATA_DIR_POS/config.yml"
    log_success "Copied templates."
}

generate_jwt_secret() {
    log_step "PoS SETUP: JWT SECRET GENERATION"
    log_action "Generating JWT secret for secure EL-CL communication"
    openssl rand -hex 32 | tr -d "\n" > "$DATA_DIR_POS/jwt.hex"
    export JWT_SECRET_PATH=$(pwd)/$DATA_DIR_POS/jwt.hex
    log_success "JWT secret generated at $DATA_DIR_POS/jwt.hex"
}

setup_all_geth_nodes() {
    local user_id=$1
    local group_id=$2
    log_step "PoS SETUP: GETH NODE ACCOUNT GENERATION"
    for i in $(seq 1 $TOTAL_NODES); do
        setup_geth_node $i $user_id $group_id
    done
}

generate_consensus_genesis_and_keys() {
    local user_id=$1
    local group_id=$2
    log_step "PoS SETUP: CONSENSUS GENESIS & VALIDATOR KEYS"
    log_info "Generating validator keys for $POS_VALIDATOR_COUNT validators..."
    docker run --rm \
        --user "$user_id:$group_id" \
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
}

update_genesis_for_forks() {
    log_info "Forcing all forks to activate at genesis..."
    jq '.config.shanghaiTime = 0 | .config.cancunTime = 0' "$DATA_DIR_POS/genesis.json" > "$DATA_DIR_POS/genesis.json.tmp" && mv "$DATA_DIR_POS/genesis.json.tmp" "$DATA_DIR_POS/genesis.json"
    log_success "Genesis file updated for immediate fork activation."
}

generate_bootnode_details() {
    local user_id=$1
    local group_id=$2
    log_step "PoS SETUP: GENERATE BOOTNODE DETAILS"
    
    # --- Geth Bootnode Enode ---
    log_action "Generating Geth nodekey for node 1..."
    docker run --rm --user "$user_id:$group_id" --entrypoint bootnode \
        -v "$(pwd)/$DATA_DIR_POS/node1/execution/geth:/geth" \
        ${GETH_IMAGE_TAG_POS} -genkey /geth/nodekey
    log_success "Geth nodekey generated."

    log_action "Extracting Geth bootnode enode for node 1"
    local el_pubkey=$(docker run --rm --user "$user_id:$group_id" --entrypoint bootnode \
        -v "$(pwd)/$DATA_DIR_POS/node1/execution/geth:/geth" \
        ${GETH_IMAGE_TAG_POS} --nodekey=/geth/nodekey -writeaddress)
    if [ -z "$el_pubkey" ]; then
        log_error "Failed to get Geth pubkey for node 1."
        exit 1
    fi
    local bootnode_el_enode="enode://$el_pubkey@execution_node1:30303"
    log_info "Generated Geth enode: $bootnode_el_enode"
    touch .env
    sed -i '/^BOOTNODE_EL_ENODE=/d' .env
    echo "BOOTNODE_EL_ENODE=\"$bootnode_el_enode\"" >> .env
    log_success "Successfully saved BOOTNODE_EL_ENODE to .env"

    # --- Prysm Bootnode ENR and Peer ID ---
    log_action "Pre-generating consensus data for node 1 to retrieve bootnode ENR and Peer ID"
    local network_name="skripsidchain"
    docker run --rm -d --name temp_prysm_node \
        --user "$user_id:$group_id" \
        --network "$network_name" \
        --network-alias consensus_node1 \
        -v "$(pwd)/$DATA_DIR_POS/node1/consensus:/data" \
        -v "$(pwd)/$DATA_DIR_POS/genesis.ssz:/genesis.ssz" \
        -v "$(pwd)/$DATA_DIR_POS/config.yml:/config.yml" \
        "$CONSENSUS_CLIENT_IMAGE" \
        --datadir=/data \
        --chain-config-file=/config.yml \
        --genesis-state=/genesis.ssz \
        --p2p-static-id \
        --p2p-host-dns=consensus_node1 \
        --p2p-tcp-port=13000 \
        --p2p-udp-port=13000 \
        --accept-terms-of-use \
        --min-sync-peers=999 > /dev/null 2>&1

    log_info "Waiting for ENR and Peer ID to be generated..."
    local enr_log
    for i in {1..30}; do
        sleep 2
        enr_log=$(docker logs temp_prysm_node 2>&1)
        bootnode_cl_enr=$(echo "$enr_log" | grep -o 'ENR="[^"]*"' | cut -d'"' -f2)
        bootnode_cl_peer_id=$(echo "$enr_log" | grep "Running node with peer id" | grep -o '16Uiu2H[a-zA-Z0-9]*')

        if [ -n "$bootnode_cl_enr" ] && [ -n "$bootnode_cl_peer_id" ]; then
            log_success "ENR and Peer ID found!"
            break
        fi
    done
    docker stop temp_prysm_node > /dev/null 2>&1
    
    if [ -z "$bootnode_cl_enr" ] || [ -z "$bootnode_cl_peer_id" ]; then
        log_error "Could not find bootnode ENR or Peer ID in the container logs."
        log_error "Prysm log output:"
        echo "$enr_log"
        exit 1
    fi

    log_info "Generated ENR: $bootnode_cl_enr"
    log_info "Generated Peer ID: $bootnode_cl_peer_id"
    
    log_info "Updating BOOTSTRAP_CL_ENR and BOOTSTRAP_CL_PEER_ID in .env file..."
    touch .env
    sed -i '/^BOOTSTRAP_CL_ENR=/d' .env
    sed -i '/^BOOTSTRAP_CL_PEER_ID=/d' .env
    echo "BOOTSTRAP_CL_ENR=\"$bootnode_cl_enr\"" >> .env
    echo "BOOTSTRAP_CL_PEER_ID=\"$bootnode_cl_peer_id\"" >> .env
    log_success "Successfully saved bootstrap info to .env"
}

initialize_all_geth_nodes() {
    local user_id=$1
    local group_id=$2
    log_step "PoS SETUP: INITIALIZE GETH NODES"
    log_info "Initializing Geth for all nodes..."
    for i in $(seq 1 $TOTAL_NODES); do
        local execution_dir="$DATA_DIR_POS/node$i/execution"
        log_info "Initializing Geth for node $i..."
        docker run --rm -i \
            --user "$user_id:$group_id" \
            -v "$(pwd)/$execution_dir:/data" \
            -v "$(pwd)/$DATA_DIR_POS/genesis.json:/genesis.json" \
            $GETH_IMAGE_TAG_POS \
            geth init --datadir /data /genesis.json
    done
    log_success "All Geth nodes initialized."
}

generate_and_configure_compose_file() {
    local bootnode_enr=$1
    log_step "PoS SETUP: DOCKER COMPOSE FILE GENERATION"
    log_action "Generating the docker-compose.pos.yml file"
    
    chmod +x ./scripts/generate-compose.sh
    ./scripts/generate-compose.sh
    
    log_action "Injecting bootnode ENR into docker-compose.pos.yml"
    local compose_file="docker-compose.pos.yml"
    local temp_file=$(mktemp)
    
    sed "s|--bootstrap-node=PLACEHOLDER_ENR|--bootstrap-node=${bootnode_enr}|g" "$compose_file" > "$temp_file" && mv "$temp_file" "$compose_file"
    log_success "docker-compose.pos.yml has been configured with the correct bootnode."
}

setup_pos_network() {
    log_step "Starting Proof-of-Stake Network Setup"
    
    local USER_ID=$(id -u)
    local GROUP_ID=$(id -g)

    cleanup_and_prepare
    generate_jwt_secret
    setup_all_geth_nodes "$USER_ID" "$GROUP_ID"
    generate_consensus_genesis_and_keys "$USER_ID" "$GROUP_ID"
    update_genesis_for_forks
    generate_bootnode_details "$USER_ID" "$GROUP_ID"
    initialize_all_geth_nodes "$USER_ID" "$GROUP_ID"
    generate_and_configure_compose_file "$bootnode_cl_enr"

    log_success "Proof-of-Stake Network Setup Complete!"
    log_info "Total nodes created: $TOTAL_NODES"
    log_info "  - Validator nodes: $POS_VALIDATOR_COUNT"
    log_info "  - Non-validator nodes: $POS_NON_VALIDATOR_COUNT"
}

setup_pos_network