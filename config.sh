#!/bin/bash
# File: config.sh
# Primary configuration for the dynamic Geth Proof-of-Authority (PoA) network.
# Adjust the values in this file to define different network or benchmarking scenarios.

# --- Node Count Configuration ---
# Defines the number of signer (validator) and non-signer (RPC) nodes.
export NUM_SIGNERS=1
export NUM_NONSIGNERS=1

# --- Network & Secrets Configuration ---
export NETWORK_ID=477748
export COMPOSE_PROJECT_NAME="geth_clique_poa_dynamic"

# Use a common prefix for passwords to make them predictable during setup, yet unique for each node.
export SIGNER_PASS_PREFIX="pass_signer_"
export NONSIGNER_PASS_PREFIX="pass_nonsigner_"

# Secrets for the Ethstats monitoring service and database credentials.
# IMPORTANT: Change these default values for any production-like environment.
export ETHSTATS_WS_SECRET="YourSuperSecretEthstatsStringHere"
export INFLUXDB_DB="geth_metrics"
export INFLUXDB_USER="geth_user"
export INFLUXDB_PASSWORD="YourStrongInfluxDBPassword"
export INFLUXDB_HOST="influxdb"
export INFLUXDB_PORT="8086"
export GRAFANA_ADMIN_PASSWORD="YourStrongGrafanaAdminPassword"

# --- Port Mapping Configuration ---
# Node-specific ports will be calculated dynamically, starting from these base numbers.
# For example, the first node will use port 30303, the second 30304, and so on.
# P2P discovery port for Geth nodes
export BASE_GETH_P2P_PORT=30303
# HTTP JSON-RPC port
export BASE_GETH_HTTP_PORT=8545
# WebSocket JSON-RPC port
export BASE_GETH_WS_PORT=8546
# Ethstats dashboard web server port
export BASE_MONITORING_HTTP_PORT=8085
# Grafana dashboard web server port
export BASE_GRAFANA_HTTP_PORT=3000