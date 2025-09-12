#!/bin/bash
# File: setup-network-poa.sh
# Automates the one-time setup for a Proof-of-Authority (PoA) network.

set -e
source ./scripts/logger.sh
source ./config.sh

log_step "PoA SETUP: CLEANUP & PREPARATION"
log_action "Cleaning up previous data and creating directories"
if [ -f "./destroy-network.sh" ]; then
    chmod +x ./destroy-network.sh && ./destroy-network.sh > /dev/null 2>&1
fi
mkdir -p config/{passwords,addresses} data/influxdb data/grafana scripts
mkdir -p data/nonsigner1/geth data/nonsigner1/keystore
for i in $(seq 1 $NUM_SIGNERS); do mkdir -p data/signer${i}/keystore data/clef${i}; done
if [ $NUM_NONSIGNERS -gt 1 ]; then for i in $(seq 2 $NUM_NONSIGNERS); do mkdir -p data/nonsigner${i}/geth data/nonsigner${i}/keystore; done; fi
log_success "Directories created."

log_step "PoA SETUP: ACCOUNT & PASSWORD GENERATION"
log_action "Generating passwords and Ethereum accounts for ${NUM_SIGNERS} signers and ${NUM_NONSIGNERS} non-signers"
for i in $(seq 1 $NUM_SIGNERS); do
  PASS="${SIGNER_PASS_PREFIX}${i}"; echo -n "$PASS" > ./config/passwords/signer${i}.pass; chmod 600 ./config/passwords/signer${i}.pass
  ADDR=$(docker run --rm -i -v "$(pwd)/data/signer${i}:/data" -v "$(pwd)/config/passwords/signer${i}.pass:/pass" ${GETH_IMAGE_TAG_POA} geth --datadir /data account new --password /pass | grep "Public address of the key" | awk '{print $NF}')
  echo -n "$ADDR" > ./config/addresses/signer${i}.addr
  echo -e "SIGNER${i}_ADDRESS=$ADDR"
  echo "SIGNER${i}_ADDRESS=$ADDR" >> .env
  export SIGNER${i}_ADDRESS=$ADDR
done
for i in $(seq 1 $NUM_NONSIGNERS); do
  PASS="${NONSIGNER_PASS_PREFIX}${i}"; echo -n "$PASS" > ./config/passwords/nonsigner${i}.pass; chmod 600 ./config/passwords/nonsigner${i}.pass
  ADDR=$(docker run --rm -i -v "$(pwd)/data/nonsigner${i}:/data" -v "$(pwd)/config/passwords/nonsigner${i}.pass:/pass" ${GETH_IMAGE_TAG_POA} geth --datadir /data account new --password /pass | grep "Public address of the key" | awk '{print $NF}')
  echo -n "$ADDR" > ./config/addresses/nonsigner${i}.addr
  echo -e "NONSIGNER${i}_ADDRESS=$ADDR"
  echo "NONSIGNER${i}_ADDRESS=$ADDR" >> .env
  export NONSIGNER${i}_ADDRESS=$ADDR
done
log_success "Accounts and passwords generated."

log_step "PoA SETUP: CLEF INITIALIZATION"
log_info "You will be prompted for passwords during Clef initialization."
for i in $(seq 1 $NUM_SIGNERS); do
  ADDR=$(cat ./config/addresses/signer${i}.addr); PASS="${SIGNER_PASS_PREFIX}${i}"; RULE_HASH=$(sha256sum ./config/rules.js | cut -f1 -d' ')
  log_action "Configuring Clef for Signer ${i} ($ADDR)"
  log_info "Please use password: '${PASS}' when prompted."
  docker run --rm -it -v "$(pwd)/data/signer${i}/keystore:/root/.ethereum/keystore" -v "$(pwd)/data/clef${i}:/root/.clef" ${GETH_IMAGE_TAG_POA} clef --keystore /root/.ethereum/keystore --configdir /root/.clef init
  docker run --rm -it -v "$(pwd)/data/signer${i}/keystore:/root/.ethereum/keystore" -v "$(pwd)/data/clef${i}:/root/.clef" ${GETH_IMAGE_TAG_POA} clef --keystore /root/.ethereum/keystore --configdir /root/.clef setpw $ADDR
  docker run --rm -it -v "$(pwd)/data/clef${i}:/root/.clef" ${GETH_IMAGE_TAG_POA} clef --configdir /root/.clef attest $RULE_HASH
done
log_success "All Clef instances initialized."

log_step "PoA SETUP: GENESIS & COMPOSE FILE GENERATION"
log_action "Generating genesis file and bootnode key"
chmod +x ./scripts/generate-genesis.sh && ./scripts/generate-genesis.sh
sudo chown -R $(id -u):$(id -g) ./data/nonsigner1
docker run --rm -v "$(pwd)/data/nonsigner1/geth:/geth" ${GETH_IMAGE_TAG_POA} bootnode -genkey /geth/nodekey
log_success "Genesis and bootkey generated."

log_action "Generating initial Docker Compose file"
chmod +x ./scripts/generate-compose.sh && ./scripts/generate-compose.sh
log_success "Initial docker-compose.poa.yml generated."

# Ensure the external Docker network exists before using docker compose
NETWORK_NAME="skripsidchain"
log_action "Ensuring Docker network '${NETWORK_NAME}' exists"
if ! docker network ls | grep -q "${NETWORK_NAME}\b"; then
  log_info "Network not found. Creating Docker network: ${NETWORK_NAME}"
  docker network create "${NETWORK_NAME}"
  log_success "Docker network '${NETWORK_NAME}' created."
else
  log_info "Docker network '${NETWORK_NAME}' already exists."
fi

log_action "Initializing Geth database for all nodes"
POA_OUTPUT_FILE="docker-compose.poa.yml"
for i in $(seq 1 $NUM_SIGNERS); do docker compose -f ${POA_OUTPUT_FILE} run --rm --no-deps signer${i} geth init /config/genesis.json; done
for i in $(seq 1 $NUM_NONSIGNERS); do docker compose -f ${POA_OUTPUT_FILE} run --rm --no-deps nonsigner${i} geth init /config/genesis.json; done
log_success "Geth databases initialized."

log_step "PoA SETUP: BOOTNODE ENODE RETRIEVAL"
log_action "Starting bootnode to retrieve its enode"
docker compose -f ${POA_OUTPUT_FILE} up -d nonsigner1
log_action "Waiting for bootnode RPC to become available"
until curl -s -f -X POST --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}' -H 'Content-Type: application/json' http://localhost:${BASE_GETH_HTTP_PORT} > /dev/null 2>&1; do
  sleep 1
done
ENODE_INFO=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' -H 'Content-Type: application/json' http://localhost:${BASE_GETH_HTTP_PORT})
ENODE_URL=$(echo $ENODE_INFO | jq -r '.result.enode')
docker compose -f ${POA_OUTPUT_FILE} stop nonsigner1
ENODE_URL_CLEANED=$(echo $ENODE_URL | sed 's/\[::\]/nonsigner1/' | sed 's/127.0.0.1/nonsigner1/' | sed -E 's/@[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:/@nonsigner1:/')
echo "BOOTNODE_ENODE=${ENODE_URL_CLEANED}" >> .env
export BOOTNODE_ENODE=$ENODE_URL_CLEANED
log_success "Bootnode enode retrieved: ${BOOTNODE_ENODE}"

log_step "PoA SETUP: FINALIZING CONFIGURATION"
log_action "Re-generating final Docker Compose file with bootnode enode"
./scripts/generate-compose.sh
log_success "Final docker-compose.poa.yml generated."
