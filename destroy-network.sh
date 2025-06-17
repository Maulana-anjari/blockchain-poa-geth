#!/bin/bash
# File: destroy-network.sh (Diperbarui untuk .env)
# Membersihkan semua yang dibuat oleh setup-network.sh
echo "Menghancurkan semua container dan volume..."
docker-compose down -v --remove-orphans || true
echo "Menghapus data, log, dan file konfigurasi yang digenerate..."
sudo rm -rf ./data ./config/passwords ./config/addresses ./config/genesis.json ./docker-compose.yml ./.env
echo "Pembersihan selesai."