#!/bin/bash
# File: scripts/generate-genesis.sh (Versi Final - Menggunakan Parameter Expansion)
set -e

source ./config.sh
TEMPLATE_FILE="./config/genesis.template.json"
OUTPUT_FILE="./config/genesis.json"

if [ ! -f "$TEMPLATE_FILE" ]; then echo "Template not found!"; exit 1; fi
if ! command -v jq &> /dev/null; then echo "'jq' not found!"; exit 1; fi

echo "Membaca konfigurasi... (ChainID: ${NETWORK_ID})"

# --- 'extradata' ---
EXTRADATA="0x$(printf '0%.0s' {1..64})"
SIGNER_ADDRESSES=""
for i in $(seq 1 $NUM_SIGNERS); do
    ADDR=$(cat ./config/addresses/signer${i}.addr)
    SIGNER_ADDRESSES+=${ADDR#0x}
done
EXTRADATA+=$SIGNER_ADDRESSES
EXTRADATA+="$(printf '0%.0s' {1..130})"
echo "'extradata' dibuat."

# --- 'alloc' ---
ALLOC_JSON="{}"
INITIAL_BALANCE="3000000000000000000000" # 3000 ETH
echo "Membuat alokasi dana awal (alloc)..."

for i in $(seq 1 $NUM_SIGNERS); do
    ADDR=$(cat ./config/addresses/signer${i}.addr)
    ALLOC_JSON=$(echo "$ALLOC_JSON" | jq --arg addr "$ADDR" --arg bal "$INITIAL_BALANCE" '. + {($addr): {"balance": $bal}}')
done

for i in $(seq 1 $NUM_NONSIGNERS); do
    ADDR=$(cat ./config/addresses/nonsigner${i}.addr)
    ALLOC_JSON=$(echo "$ALLOC_JSON" | jq --arg addr "$ADDR" --arg bal "$INITIAL_BALANCE" '. + {($addr): {"balance": $bal}}')
done
echo "'alloc' dibuat."

# --- Membuat File genesis.json Final ---
echo "Membuat file ${OUTPUT_FILE}..."

TEMPLATE_CONTENT=$(cat "$TEMPLATE_FILE")

# Ganti placeholder satu per satu
CONTENT_WITH_CHAINID="${TEMPLATE_CONTENT/__CHAIN_ID__/$NETWORK_ID}"
CONTENT_WITH_EXTRA="${CONTENT_WITH_CHAINID/__EXTRADATA__/$EXTRADATA}"
FINAL_CONTENT="${CONTENT_WITH_EXTRA/__ALLOC__/$ALLOC_JSON}"

# Tulis konten final ke file output
echo "$FINAL_CONTENT" > "$OUTPUT_FILE"

echo "File genesis.json berhasil dibuat."