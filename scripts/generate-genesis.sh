#!/bin/bash
# File: scripts/generate-genesis.sh
# This script dynamically generates the genesis.json file for the PoA network
# by populating a template with configured values.
set -e

# Load the main configuration file.
source ./config.sh
TEMPLATE_FILE="./config/genesis.template.json"
OUTPUT_FILE="./config/genesis.json"

# --- Pre-flight Checks ---
# Ensure the template file and required tools (jq) are available.
if [ ! -f "$TEMPLATE_FILE" ]; then echo "Error: Genesis template file not found at '$TEMPLATE_FILE'!"; exit 1; fi
if ! command -v jq &> /dev/null; then echo "Error: 'jq' is not installed. Please install it to proceed."; exit 1; fi

echo "Loading configuration and generating genesis file... (ChainID: ${NETWORK_ID})"

# --- 1. Construct the 'extradata' Field ---
# The 'extradata' field in a Clique PoA genesis file must contain, among other things,
# the list of initial signer addresses, padded with zeros.
EXTRADATA="0x$(printf '0%.0s' {1..64})" # 32 bytes of vanity data
SIGNER_ADDRESSES=""
for i in $(seq 1 $NUM_SIGNERS); do
    ADDR=$(cat ./config/addresses/signer${i}.addr)
    # Append the address, stripping the "0x" prefix.
    SIGNER_ADDRESSES+=${ADDR#0x}
done
EXTRADATA+=$SIGNER_ADDRESSES
EXTRADATA+="$(printf '0%.0s' {1..130})" # 65 bytes of proposer seal
echo "'extradata' field constructed."

# --- 2. Construct the 'alloc' Field ---
# This section defines the initial balance for all accounts that will be created.
ALLOC_JSON="{}"
INITIAL_BALANCE="3000000000000000000000" # Initial balance in Wei (equivalent to 3000 ETH)
echo "Pre-funding accounts in the 'alloc' field..."

# Allocate initial funds to signer nodes.
for i in $(seq 1 $NUM_SIGNERS); do
    ADDR=$(cat ./config/addresses/signer${i}.addr)
    ALLOC_JSON=$(echo "$ALLOC_JSON" | jq --arg addr "$ADDR" --arg bal "$INITIAL_BALANCE" '. + {($addr): {"balance": $bal}}')
done

# Allocate initial funds to non-signer nodes.
for i in $(seq 1 $NUM_NONSIGNERS); do
    ADDR=$(cat ./config/addresses/nonsigner${i}.addr)
    ALLOC_JSON=$(echo "$ALLOC_JSON" | jq --arg addr "$ADDR" --arg bal "$INITIAL_BALANCE" '. + {($addr): {"balance": $bal}}')
done
echo "'alloc' field constructed."

# --- 3. Generate the Final genesis.json File ---
echo "Generating final ${OUTPUT_FILE} from template..."

TEMPLATE_CONTENT=$(cat "$TEMPLATE_FILE")

# Sequentially replace placeholders in the template with the generated values.
CONTENT_WITH_CHAINID="${TEMPLATE_CONTENT/__CHAIN_ID__/$NETWORK_ID}"
CONTENT_WITH_EXTRA="${CONTENT_WITH_CHAINID/__EXTRADATA__/$EXTRADATA}"
# Note: The __ALLOC__ placeholder does not need quotes in the template
# because ALLOC_JSON is already a valid JSON object string.
FINAL_CONTENT="${CONTENT_WITH_EXTRA/__ALLOC__/$ALLOC_JSON}"

# Write the final, populated content to the output file.
echo "$FINAL_CONTENT" > "$OUTPUT_FILE"

echo "Successfully generated ${OUTPUT_FILE}."