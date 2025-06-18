#!/bin/bash
# File: setup-network.sh
# This script automates the setup of a Proof-of-Authority (PoA) Ethereum network using Docker.

set -e
source ./config.sh

echo "==== STARTING POA NETWORK SETUP ===="
echo "Signers: ${NUM_SIGNERS}, Non-Signers: ${NUM_NONSIGNERS}"

# --- 1. Cleanup & Preparation ---
echo -e "\n---> 1. Cleaning up any previous setup and creating necessary directories..."
# If a script to destroy the network exists, execute it to ensure a clean slate.
if [ -f "./destroy-network.sh" ]; then
    chmod +x ./destroy-network.sh && ./destroy-network.sh
fi
# Create directory structure for configuration, data, and scripts.
mkdir -p config/{passwords,addresses} data/influxdb data/grafana scripts
mkdir -p data/nonsigner1/geth data/nonsigner1/keystore
for i in $(seq 1 $NUM_SIGNERS); do mkdir -p data/signer${i}/keystore data/clef${i}; done
if [ $NUM_NONSIGNERS -gt 1 ]; then for i in $(seq 2 $NUM_NONSIGNERS); do mkdir -p data/nonsigner${i}/geth data/nonsigner${i}/keystore; done; fi
# Check for required template files.
if [ ! -f "./config/rules.js" ] || [ ! -f "./config/genesis.template.json" ]; then
    echo "Error: Required template files not found (rules.js or genesis.template.json)."
    exit 1
fi
echo "Template files found."

# --- 2. Create .env File & Accounts ---
echo -e "\n---> 2. Generating the .env file, passwords, and Ethereum accounts..."
# Create a .env file from config.sh for Docker Compose.
grep -v '^#' ./config.sh | grep -v '^[[:space:]]*$' | sed 's/export //' > .env
# Generate accounts and passwords for each signer node.
for i in $(seq 1 $NUM_SIGNERS); do
  PASS="${SIGNER_PASS_PREFIX}${i}"; echo -n "$PASS" > ./config/passwords/signer${i}.pass; chmod 600 ./config/passwords/signer${i}.pass
  # Use the official Ethereum Docker image to create a new account.
  ADDR=$(docker run --rm -i -v "$(pwd)/data/signer${i}:/data" -v "$(pwd)/config/passwords/signer${i}.pass:/pass" ethereum/client-go:alltools-v1.13.15 geth --datadir /data account new --password /pass | grep "Public address of the key" | awk '{print $NF}')
  echo -n "$ADDR" > ./config/addresses/signer${i}.addr; 
  echo -e "SIGNER${i}_ADDRESS=$ADDR"
  echo "SIGNER${i}_ADDRESS=$ADDR" >> .env
done
# Generate accounts and passwords for each non-signer node.
for i in $(seq 1 $NUM_NONSIGNERS); do
  PASS="${NONSIGNER_PASS_PREFIX}${i}"; echo -n "$PASS" > ./config/passwords/nonsigner${i}.pass; chmod 600 ./config/passwords/nonsigner${i}.pass
  ADDR=$(docker run --rm -i -v "$(pwd)/data/nonsigner${i}:/data" -v "$(pwd)/config/passwords/nonsigner${i}.pass:/pass" ethereum/client-go:alltools-v1.13.15 geth --datadir /data account new --password /pass | grep "Public address of the key" | awk '{print $NF}')
  echo -n "$ADDR" > ./config/addresses/nonsigner${i}.addr; 
  echo -e "NONSIGNER${i}_ADDRESS=$ADDR"
  echo "NONSIGNER${i}_ADDRESS=$ADDR" >> .env
done

# --- 3. Initialize Clef Signer ---
echo -e "\n---> 3. Interactively initializing Clef for each signer node..."
# Clef is an external account management tool used for signing transactions.
for i in $(seq 1 $NUM_SIGNERS); do
  ADDR=$(cat ./config/addresses/signer${i}.addr); PASS="${SIGNER_PASS_PREFIX}${i}"; RULE_HASH=$(sha256sum ./config/rules.js | cut -f1 -d' ')
  echo "--- Configuring Signer ${i} ($ADDR) ---"; echo "You will be prompted for a password 3 times. Please use: '${PASS}'"
  # Initialize Clef, set the account password, and attest to the signing rules.
  docker run --rm -it -v "$(pwd)/data/signer${i}/keystore:/root/.ethereum/keystore" -v "$(pwd)/data/clef${i}:/root/.clef" ethereum/client-go:alltools-v1.13.15 clef --keystore /root/.ethereum/keystore --configdir /root/.clef init
  docker run --rm -it -v "$(pwd)/data/signer${i}/keystore:/root/.ethereum/keystore" -v "$(pwd)/data/clef${i}:/root/.clef" ethereum/client-go:alltools-v1.13.15 clef --keystore /root/.ethereum/keystore --configdir /root/.clef setpw $ADDR
  docker run --rm -it -v "$(pwd)/data/clef${i}:/root/.clef" ethereum/client-go:alltools-v1.13.15 clef --configdir /root/.clef attest $RULE_HASH
done

# --- 4. Generate Genesis File & Bootnode Key ---
echo -e "\n---> 4. Generating the genesis.json file and the bootnode's nodekey..."
chmod +x ./scripts/generate-genesis.sh && ./scripts/generate-genesis.sh
# Ensure the current user owns the generated files to avoid permission issues.
sudo chown -R $(id -u):$(id -g) ./data/nonsigner1
# Generate the cryptographic key for the bootnode.
docker run --rm -v "$(pwd)/data/nonsigner1/geth:/geth" ethereum/client-go:alltools-v1.13.15 bootnode -genkey /geth/nodekey

# --- 5. Generate Docker Compose Config & Initialize Geth ---
echo -e "\n---> 5. Generating the docker-compose.yml file..."
chmod +x ./scripts/generate-compose.sh && ./scripts/generate-compose.sh
echo "Initializing the Geth database for each node..."
# Geth must be initialized with the genesis block for each node before starting the network.
# This ensures all nodes start from the same state.
for i in $(seq 1 $NUM_SIGNERS); do docker-compose run --rm --no-deps signer${i} geth init /config/genesis.json; done
for i in $(seq 1 $NUM_NONSIGNERS); do docker-compose run --rm --no-deps nonsigner${i} geth init /config/genesis.json; done

# --- 6. Retrieve the Bootnode Enode ---
echo -e "\n---> 6. Retrieving the enode address from the bootnode..."
# Start only the bootnode service to retrieve its enode.
docker-compose up -d nonsigner1
# Wait for the bootnode's HTTP RPC to become available.
echo "Waiting for bootnode RPC to be available..."
until curl -s -f -X POST --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}' -H 'Content-Type: application/json' http://localhost:${BASE_GETH_HTTP_PORT} > /dev/null 2>&1; do
  sleep 1;
done
echo "Bootnode RPC is up. Getting enode..."
# Fetch the enode via an RPC call.
ENODE_INFO=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' -H 'Content-Type: application/json' http://localhost:${BASE_GETH_HTTP_PORT})
ENODE_URL=$(echo $ENODE_INFO | jq -r '.result.enode')
# Stop the bootnode temporarily.
docker-compose stop nonsigner1
# Clean up the enode URL (replace local IP with the Docker service name) and add it to the .env file.
ENODE_URL_CLEANED=$(echo $ENODE_URL | sed 's/\[::\]/nonsigner1/' | sed 's/127.0.0.1/nonsigner1/' | sed -E 's/@[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:/@nonsigner1:/')
echo -e "BOOTNODE_ENODE=${ENODE_URL_CLEANED}"
echo "BOOTNODE_ENODE=${ENODE_URL_CLEANED}" >> .env
echo "Bootnode enode added to .env file: ${ENODE_URL_CLEANED}"

# --- 7. Finalize Docker Compose Configuration ---
echo "Finalizing the docker-compose.yml file (re-generating with the bootnode enode)..."
# Re-run the script to inject the BOOTNODE_ENODE into the final docker-compose.yml.
./scripts/generate-compose.sh

# --- 8. Next Steps (Manual) ---
echo -e "\n\n==== SETUP COMPLETE ===="
echo "All configuration files have been generated. You can now start the network manually."
echo "1. In this terminal, run: 'docker-compose up -d --build'"
echo "2. To view the logs for clef1, run: 'docker-compose logs -f clef1'"
echo "3. To view the logs for signer1, run: 'docker-compose logs -f signer1'"
echo "4. To view the logs for the bootnode (nonsigner1), run: 'docker-compose logs -f nonsigner1'"
echo "5. To monitor the network, open the Ethstats dashboard in your browser at: http://localhost:8080"
echo "6. To view the Grafana dashboard for performance metrics, open this URL in your browser: http://localhost:3000"