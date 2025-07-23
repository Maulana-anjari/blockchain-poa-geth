#!/bin/bash
# File: scripts/generate-genesis.sh
# Dynamically generates the genesis.json file based on the NETWORK_TYPE.

set -e
source ./scripts/logger.sh
source ./config.sh

# --- Pre-flight Checks ---
log_action "Checking for 'jq' dependency"
if ! command -v jq &> /dev/null; then
    log_error "'jq' is not installed. Please install it to proceed."
fi
log_success "'jq' is installed."

# --- Helper Function for Account Allocation ---
construct_alloc_field() {
    local num_signers=$1
    local num_nonsigners=$2
    local alloc_json="{}"
    local initial_balance="3000000000000000000000" # 3000 ETH

    for i in $(seq 1 $num_signers); do
        local addr_file="./config/addresses/signer${i}.addr"
        if [ -f "$addr_file" ]; then
            local addr=$(cat "$addr_file")
            alloc_json=$(echo "$alloc_json" | jq --arg addr "$addr" --arg bal "$initial_balance" '. + {($addr): {"balance": $bal}}')
        fi
    done

    for i in $(seq 1 $num_nonsigners); do
        local addr_file="./config/addresses/nonsigner${i}.addr"
        if [ -f "$addr_file" ]; then
            local addr=$(cat "$addr_file")
            alloc_json=$(echo "$alloc_json" | jq --arg addr "$addr" --arg bal "$initial_balance" '. + {($addr): {"balance": $bal}}')
        fi
    done
    
    echo "$alloc_json"
}

# --- Main Generation Logic ---
log_step "GENESIS GENERATION for NETWORK_TYPE: $NETWORK_TYPE"
OUTPUT_FILE="./config/genesis.json"

if [ "$NETWORK_TYPE" == "PoA" ]; then
    POA_TEMPLATE_FILE="./config/genesis.template.poa.json"
    if [ ! -f "$POA_TEMPLATE_FILE" ]; then log_error "PoA genesis template not found!"; fi

    log_action "Constructing 'extradata' for Clique"
    EXTRADATA="0x$(printf '0%.0s' {1..64})"
    SIGNER_ADDRESSES=""
    for i in $(seq 1 $NUM_SIGNERS); do
        ADDR=$(cat ./config/addresses/signer${i}.addr)
        SIGNER_ADDRESSES+=${ADDR#0x}
    done
    EXTRADATA+=$SIGNER_ADDRESSES
    EXTRADATA+="$(printf '0%.0s' {1..130})"
    log_success "'extradata' constructed."

    log_action "Constructing 'alloc' field for genesis"
    ALLOC_JSON=$(construct_alloc_field $NUM_SIGNERS $NUM_NONSIGNERS)
    log_success "'alloc' field constructed."

    log_action "Populating PoA genesis template"
    TEMPLATE_CONTENT=$(cat "$POA_TEMPLATE_FILE")
    CONTENT_WITH_CHAINID="${TEMPLATE_CONTENT/__CHAIN_ID__/$NETWORK_ID}"
    CONTENT_WITH_EXTRA="${CONTENT_WITH_CHAINID/__EXTRADATA__/$EXTRADATA}"
    FINAL_CONTENT="${CONTENT_WITH_EXTRA/__ALLOC__/$ALLOC_JSON}"
    echo "$FINAL_CONTENT" > "$OUTPUT_FILE"

elif [ "$NETWORK_TYPE" == "PoS" ]; then
    POS_TEMPLATE_FILE="./config/genesis.template.pos.json"
    if [ ! -f "$POS_TEMPLATE_FILE" ]; then log_error "PoS genesis template not found!"; fi
    
    TERMINAL_TOTAL_DIFFICULTY=100
    log_info "Using Terminal Total Difficulty: ${TERMINAL_TOTAL_DIFFICULTY}"

    # In our PoS setup, the accounts are not pre-generated in the same way.
    # The 'alloc' field might be simpler or handled differently.
    # For now, we create an empty alloc.
    ALLOC_JSON="{}"
    log_info "PoS genesis does not pre-allocate funds in this script."

    log_action "Populating PoS genesis template"
    TEMPLATE_CONTENT=$(cat "$POS_TEMPLATE_FILE")
    CONTENT_WITH_CHAINID="${TEMPLATE_CONTENT/__CHAIN_ID__/$NETWORK_ID}"
    CONTENT_WITH_TTD="${CONTENT_WITH_CHAINID/__TERMINAL_TOTAL_DIFFICULTY__/$TERMINAL_TOTAL_DIFFICULTY}"
    FINAL_CONTENT="${CONTENT_WITH_TTD/__ALLOC__/$ALLOC_JSON}"
    echo "$FINAL_CONTENT" > "$OUTPUT_FILE"
else
    log_error "Invalid NETWORK_TYPE '$NETWORK_TYPE' defined in .env."
fi

log_success "Successfully generated ${OUTPUT_FILE}."