#!/bin/bash
# File: destroy-network.sh
# This script tears down the network and cleans up all artifacts created by setup-network.sh.

echo "Stopping and removing all network containers, volumes, and networks..."
# The '-v' flag removes associated volumes. '--remove-orphans' removes containers for services
# that are no longer in the compose file. '|| true' ensures the script doesn't fail if the
# network is already down.
docker-compose down -v --remove-orphans || true

echo "Deleting all generated data, logs, and configuration files..."
# Using sudo in case some files (e.g., within the 'data' directory) were created with
# root permissions by the Docker daemon.
sudo rm -rf ./data ./config/passwords ./config/addresses ./config/genesis.json ./docker-compose.yml ./.env

echo "Cleanup complete."