#!/bin/bash
# File: config.sh
# Konfigurasi utama untuk jaringan Geth PoA dinamis.
# Ubah nilai di sini untuk setiap skenario benchmarking.

# --- Konfigurasi Jumlah Node ---
export NUM_SIGNERS=1
export NUM_NONSIGNERS=2

# --- Konfigurasi Jaringan & Rahasia ---
export NETWORK_ID=477748
export COMPOSE_PROJECT_NAME="geth_clique_poa_dynamic"

# Gunakan prefix untuk password agar mudah ditebak namun unik per node
export SIGNER_PASS_PREFIX="pass_signer_"
export NONSIGNER_PASS_PREFIX="pass_nonsigner_"

# Rahasia untuk Ethstats dan kredensial database
export ETHSTATS_WS_SECRET="YourSuperSecretEthstatsStringHere"
export INFLUXDB_DB="geth_metrics"
export INFLUXDB_USER="geth_user"
export INFLUXDB_PASSWORD="YourStrongInfluxDBPassword"
export INFLUXDB_HOST="influxdb"
export INFLUXDB_PORT="8086"
export GRAFANA_ADMIN_PASSWORD="YourStrongGrafanaAdminPassword"

# --- Konfigurasi Port Mapping ---
# Port akan dihitung secara dinamis dari base port ini
export BASE_GETH_P2P_PORT=30303
export BASE_GETH_HTTP_PORT=8545
export BASE_GETH_WS_PORT=8546
export BASE_MONITORING_HTTP_PORT=8080 # Ethstats
export BASE_GRAFANA_HTTP_PORT=3000