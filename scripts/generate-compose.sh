#!/bin/bash
# File: scripts/generate-compose.sh
# This script dynamically generates the docker-compose.yml file based on the settings
# in config.sh. It creates services for the bootnode, signer nodes (with Clef),
# non-signer nodes, and a monitoring stack.

set -e

# Load configuration variables
source ./config.sh

# Define the output file path
OUTPUT_FILE="docker-compose.yml"

# Start the docker-compose.yml file with the service definitions
cat > $OUTPUT_FILE <<EOF
# This file is auto-generated by ./scripts/generate-compose.sh
# Do not edit it manually, as your changes will be overwritten.

services:
EOF

# --- Section 1: Add the Bootnode (always nonsigner1) ---
# The bootnode is a critical, stable node that other nodes connect to in order to discover peers.
# It is configured here as the first non-signer node.
cat >> $OUTPUT_FILE <<EOF
  # --- Bootnode (Non-Signer 1) ---
  # This node serves as the primary discovery point for all other nodes.
  # It also functions as a regular RPC node with unlocked accounts for easy development access.
  nonsigner1:
    image: ethereum/client-go:alltools-v1.13.15
    container_name: nonsigner1
    hostname: nonsigner1
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/nonsigner1:/root/.ethereum
      - ./config/passwords/nonsigner1.pass:/root/password.txt:ro
      - ./data/nonsigner1/keystore:/root/.ethereum/keystore:ro
    ports:
      # Expose P2P ports for discovery by nodes outside the Docker network (if needed).
      - "\${BASE_GETH_P2P_PORT}:${BASE_GETH_P2P_PORT}/tcp"
      - "\${BASE_GETH_P2P_PORT}:${BASE_GETH_P2P_PORT}/udp"
      # Expose standard RPC and WebSocket ports.
      - "\${BASE_GETH_HTTP_PORT}:8545"
      - "\${BASE_GETH_WS_PORT}:8546"
    command: >
      geth
      --nodekey /root/.ethereum/geth/nodekey
      --datadir /root/.ethereum --keystore /root/.ethereum/keystore
      --networkid "\${NETWORK_ID}" --syncmode full --gcmode archive
      --port \${BASE_GETH_P2P_PORT}
      --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin,personal" --http.corsdomain "*" --http.vhosts "*"
      --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin,personal" --ws.origins "*"
      --metrics --metrics.expensive --metrics.influxdb
      --metrics.influxdb.endpoint "http://influxdb:8086"
      --metrics.influxdb.database "\${INFLUXDB_DB}"
      --metrics.influxdb.username "\${INFLUXDB_USER}"
      --metrics.influxdb.password "\${INFLUXDB_PASSWORD}"
      --ethstats "nonsigner1:\${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --password /root/password.txt --allow-insecure-unlock
    networks:
      - geth-network
    restart: unless-stopped
EOF

# --- Section 2: Add Signer Nodes (Dynamically) ---
# Each signer node is composed of two services: a Clef instance for secure signing
# and a Geth instance that delegates signing operations to Clef.
for i in $(seq 1 $NUM_SIGNERS); do
  # Calculate unique ports for each signer node to avoid conflicts on the host machine.
  HTTP_PORT=$((BASE_GETH_HTTP_PORT + (i * 2) + 10))
  WS_PORT=$((HTTP_PORT + 1))
  P2P_PORT=$((BASE_GETH_P2P_PORT + i))

cat >> $OUTPUT_FILE <<EOF

  # --- Signer Node ${i} ---
  clef${i}:
    # Builds a custom Docker image for Clef using the specified Dockerfile.
    build:
      context: .
      dockerfile: Dockerfile.clef
    container_name: clef${i}
    environment:
      - CLEF_MASTER_PASSWORD=\${SIGNER_PASS_PREFIX}${i}
      - NETWORK_ID=\${NETWORK_ID}
    volumes:
      - ./data/signer${i}/keystore:/root/.ethereum/keystore:ro
      - ./data/clef${i}:/root/.clef
      - ./config/rules.js:/root/rules.js:ro
    # The entrypoint script automates the Clef startup prompts.
    command: /usr/local/bin/start-clef.sh
    networks:
      - geth-network
    restart: unless-stopped

  signer${i}:
    image: ethereum/client-go:alltools-v1.13.15
    container_name: signer${i}
    # This node will not start until its Clef companion and the bootnode are ready.
    depends_on:
      clef${i}:
        condition: service_started
      nonsigner1:
        condition: service_started
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/signer${i}:/root/.ethereum
    ports:
      - "${HTTP_PORT}:8545"
      - "${WS_PORT}:8546"
    command: >
      geth \
        --datadir /root/.ethereum \
        --networkid \${NETWORK_ID} \
        --syncmode full \
        --port ${P2P_PORT} \
        --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin" --http.corsdomain "*" --http.vhosts "*" \
        --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin" --ws.origins "*" \
        --metrics --metrics.expensive --metrics.influxdb \
        --metrics.influxdb.endpoint "http://influxdb:8086" \
        --metrics.influxdb.database "\${INFLUXDB_DB}" \
        --metrics.influxdb.username "\${INFLUXDB_USER}" \
        --metrics.influxdb.password "\${INFLUXDB_PASSWORD}" \
        --ethstats "signer${i}:\${ETHSTATS_WS_SECRET}@ethstats-server:3000" \
        --bootnodes "\${BOOTNODE_ENODE}" \
        --signer "http://clef${i}:8550" \
        --mine --miner.etherbase "\${SIGNER${i}_ADDRESS}"
    networks:
      - geth-network
    restart: unless-stopped
EOF
done

# --- Section 3: Add Other Non-Signer Nodes (Dynamically) ---
# These are additional RPC nodes that do not participate in block creation.
if [ $NUM_NONSIGNERS -gt 1 ]; then
  for i in $(seq 2 $NUM_NONSIGNERS); do
    # Calculate unique ports for each additional non-signer.
    HTTP_PORT=$((BASE_GETH_HTTP_PORT + (NUM_SIGNERS * 2) + (i * 2) + 20))
    WS_PORT=$((HTTP_PORT + 1))
    P2P_PORT=$((BASE_GETH_P2P_PORT + NUM_SIGNERS + i))

cat >> $OUTPUT_FILE <<EOF

  # --- Non-Signer Node ${i} ---
  nonsigner${i}:
    image: ethereum/client-go:alltools-v1.13.15
    container_name: nonsigner${i}
    depends_on:
      - nonsigner1
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/nonsigner${i}:/root/.ethereum
      - ./config/passwords/nonsigner${i}.pass:/root/password.txt:ro
      - ./data/nonsigner${i}/keystore:/root/.ethereum/keystore:ro
    ports:
      - "${HTTP_PORT}:8545"
      - "${WS_PORT}:8546"
    command: >
      geth
      --datadir /root/.ethereum --keystore /root/.ethereum/keystore --networkid "\${NETWORK_ID}"
      --syncmode full --gcmode archive --port ${P2P_PORT}
      --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin,personal" --http.corsdomain "*" --http.vhosts "*"
      --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin,personal" --ws.origins "*"
      --metrics --metrics.expensive --metrics.influxdb
      --metrics.influxdb.endpoint "http://influxdb:8086"
      --metrics.influxdb.database "\${INFLUXDB_DB}"
      --metrics.influxdb.username "\${INFLUXDB_USER}"
      --metrics.influxdb.password "\${INFLUXDB_PASSWORD}"
      --ethstats "nonsigner${i}:\${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --password /root/password.txt --allow-insecure-unlock
      --bootnodes "\${BOOTNODE_ENODE}"
    networks:
      - geth-network
    restart: unless-stopped
EOF
  done
fi

# --- Section 4: Add the Monitoring Stack (Static) ---
# This includes Ethstats for network visualization, InfluxDB for metrics storage,
# and Grafana for creating dashboards from the metrics.
cat >> $OUTPUT_FILE <<EOF

# --- Monitoring Stack ---
  ethstats-server:
    # Builds the Ethstats server image directly from its GitHub repository.
    build:
      context: https://github.com/goerli/ethstats-server.git
    container_name: ethstats-server
    environment:
      WS_SECRET: "\${ETHSTATS_WS_SECRET}"
    ports:
      - "\${BASE_MONITORING_HTTP_PORT}:3000"
    networks:
      - geth-network
    restart: unless-stopped

  influxdb:
    image: influxdb:1.8
    container_name: influxdb
    volumes:
      # Use a named volume for persistent metrics data.
      - influxdb_data:/var/lib/influxdb
    environment:
      INFLUXDB_DB: "\${INFLUXDB_DB}"
      INFLUXDB_ADMIN_USER: "\${INFLUXDB_USER}"
      INFLUXDB_ADMIN_PASSWORD: "\${INFLUXDB_PASSWORD}"
      INFLUXDB_HTTP_AUTH_ENABLED: "true"
      # These credentials are used by Geth to write data.
      INFLUXDB_USER: "\${INFLUXDB_USER}"
      INFLUXDB_USER_PASSWORD: "\${INFLUXDB_PASSWORD}"
    networks:
      - geth-network
    restart: unless-stopped

  grafana:
    image: grafana/grafana-oss:latest
    container_name: grafana
    depends_on: [influxdb]
    volumes:
      # Use a named volume for persistent dashboard configurations.
      - grafana_data:/var/lib/grafana
    ports:
      - "\${BASE_GRAFANA_HTTP_PORT}:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: "\${GRAFANA_ADMIN_PASSWORD}"
    networks:
      - geth-network
    restart: unless-stopped
  
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ../caliper-poa-workspace/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
    networks:
      - geth-network
    restart: unless-stopped

  pushgateway:
    image: prom/pushgateway:latest
    container_name: pushgateway
    ports:
      - "9091:9091"
    networks:
      - geth-network
    restart: unless-stopped

# --- Network & Volume Definitions ---
networks:
  geth-network:
    driver: bridge
    name: \${COMPOSE_PROJECT_NAME}_default_net

volumes:
  grafana_data: {}
  influxdb_data: {}
EOF

echo "Successfully generated docker-compose.yml."