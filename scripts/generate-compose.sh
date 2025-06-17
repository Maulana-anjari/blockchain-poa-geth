#!/bin/bash
set -e

# Memuat file konfigurasi
source ./config.sh

# Path output
OUTPUT_FILE="docker-compose.yml"

# Memulai file docker-compose.yml
cat > $OUTPUT_FILE <<EOF

services:
EOF

# --- Tambahkan Bootnode (selalu nonsigner1) ---
cat >> $OUTPUT_FILE <<EOF
  # --- Bootnode (Non-Signer 1) ---
  nonsigner1:
    build:
      context: .
      dockerfile: Dockerfile.geth
    container_name: nonsigner1
    hostname: nonsigner1
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/nonsigner1:/root/.ethereum
      - ./config/passwords/nonsigner1.pass:/root/password.txt:ro
    ports:
      - "\${BASE_GETH_P2P_PORT}:${BASE_GETH_P2P_PORT}/tcp"
      - "\${BASE_GETH_P2P_PORT}:${BASE_GETH_P2P_PORT}/udp"
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
      # Hapus metrik untuk sementara untuk menyederhanakan debugging
      # --metrics --metrics.expensive --metrics.influxdb ...
      # --ethstats "nonsigner1:\${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --password /root/password.txt --allow-insecure-unlock
    networks:
      - geth-network
    restart: unless-stopped
EOF

# --- Tambahkan Signer Nodes (Dinamis) ---
for i in $(seq 1 $NUM_SIGNERS); do
  HTTP_PORT=$((BASE_GETH_HTTP_PORT + (i * 2) + 10))
  WS_PORT=$((HTTP_PORT + 1))
  P2P_PORT=$((BASE_GETH_P2P_PORT + i))

cat >> $OUTPUT_FILE <<EOF

  # --- Signer Node ${i} ---
  clef${i}:
    build:
      context: .
      dockerfile: Dockerfile.clef
    container_name: clef${i}
    tty: true
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "8550"]
      interval: 5s
      timeout: 3s
      retries: 5
    environment:
      - CLEF_MASTER_PASSWORD=\${SIGNER_PASS_PREFIX}${i}
      - NETWORK_ID=\${NETWORK_ID}
    volumes:
      - ./data/signer${i}/keystore:/root/.ethereum/keystore:ro
      - ./data/clef${i}:/root/.clef
      - ./config/rules.js:/root/rules.js:ro
    networks:
      - geth-network
    restart: unless-stopped

  signer${i}:
    build:
      context: .
      dockerfile: Dockerfile.geth
    container_name: signer${i}
    depends_on:
      clef${i}:
        condition: service_healthy # Kita bisa kembali ke ini karena healthcheck sudah ada
      nonsigner1:
        condition: service_started
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/signer${i}:/root/.ethereum
    ports:
      - "${HTTP_PORT}:8545"
      - "${WS_PORT}:8546"
    command:
      - "/bin/sh"
      - "-c"
      - |
        apk add --no-cache curl && \
        echo "Waiting for clef${i} to be healthy..." && \
        until curl -s -f -X POST --data '{"jsonrpc":"2.0","method":"admin_peers","params":[],"id":1}' -H 'Content-Type: application/json' http://clef${i}:8550 > /dev/null 2>&1; do \
          sleep 2; \
        done; \
        echo "Clef is up! Starting Geth..."; \
        exec geth \
          --datadir /root/.ethereum \
          --networkid \${NETWORK_ID} \
          --syncmode full \
          --port ${P2P_PORT} \
          --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin" --http.corsdomain "*" --http.vhosts "*" \
          --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin" --ws.origins "*" \
          --bootnodes "\${BOOTNODE_ENODE}" \
          --signer "http://clef${i}:8550" \
          --mine --miner.etherbase "\$(cat /root/.ethereum/keystore/* | jq -r .address | awk '{print "0x" \$0}')"
    networks:
      - geth-network
    restart: unless-stopped
EOF
done

# --- Tambahkan Non-Signer Nodes lainnya (Dinamis) ---
if [ $NUM_NONSIGNERS -gt 1 ]; then
  for i in $(seq 2 $NUM_NONSIGNERS); do
    HTTP_PORT=$((BASE_GETH_HTTP_PORT + (NUM_SIGNERS * 2) + (i * 2) + 20))
    WS_PORT=$((HTTP_PORT + 1))
    P2P_PORT=$((BASE_GETH_P2P_PORT + NUM_SIGNERS + i))

cat >> $OUTPUT_FILE <<EOF

  # --- Non-Signer Node ${i} ---
  nonsigner${i}:
    build:
      context: .
      dockerfile: Dockerfile.geth
    container_name: nonsigner${i}
    depends_on:
      - nonsigner1
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/nonsigner${i}:/root/.ethereum
      - ./config/passwords/nonsigner${i}.pass:/root/password.txt:ro
    ports:
      - "${HTTP_PORT}:8545"
      - "${WS_PORT}:8546"
    command: >
      geth
      --datadir /root/.ethereum --keystore /root/.ethereum/keystore --networkid "\${NETWORK_ID}"
      --syncmode full --gcmode archive --port ${P2P_PORT}
      --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin,personal" --http.corsdomain "*" --http.vhosts "*"
      --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin,personal" --ws.origins "*"
      # Hapus metrik untuk sementara
      # --ethstats "nonsigner${i}:\${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --password /root/password.txt --allow-insecure-unlock
      --bootnodes "\${BOOTNODE_ENODE}"
    networks:
      - geth-network
    restart: unless-stopped
EOF
  done
fi

# --- Tambahkan Monitoring Stack (Statis) ---
# Dikosongkan untuk sekarang

cat >> $OUTPUT_FILE <<EOF

networks:
  geth-network:
    driver: bridge
    name: \${COMPOSE_PROJECT_NAME}_default_net

volumes:
  grafana_data: {}
  influxdb_data: {}
EOF

echo "File docker-compose.yml berhasil dibuat."