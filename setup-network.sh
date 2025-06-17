#!/bin/bash
# File: setup-network.sh (Versi PERSIAPAN SAJA)
set -e
source ./config.sh

echo "==== MEMULAI PERSIAPAN JARINGAN POA ===="
echo "Signers: ${NUM_SIGNERS}, Non-Signers: ${NUM_NONSIGNERS}"

# --- 1. Pembersihan & Persiapan ---
echo -e "\n---> 1. Membersihkan setup sebelumnya dan membuat direktori..."
if [ -f "./destroy-network.sh" ]; then
    chmod +x ./destroy-network.sh && ./destroy-network.sh
fi
if [ ! -f "./Dockerfile.geth" ]; then
    echo "Error: Dockerfile.geth tidak ditemukan."
    exit 1
fi
chmod +x ./scripts/wait-for-it.sh
mkdir -p config/{passwords,addresses} data/influxdb data/grafana scripts
for i in $(seq 1 $NUM_SIGNERS); do mkdir -p data/signer${i}/keystore data/clef${i}; done
for i in $(seq 1 $NUM_NONSIGNERS); do mkdir -p data/nonsigner${i}/geth data/nonsigner${i}/keystore; done
if [ ! -f "./config/rules.js" ] || [ ! -f "./config/genesis.template.json" ]; then
    echo "Error: File template tidak ditemukan."
    exit 1
fi
echo "File template ditemukan."

# --- 2. Buat .env & Akun ---
echo -e "\n---> 2. Membuat file .env, password, dan akun..."
grep -v '^#' ./config.sh | grep -v '^[[:space:]]*$' | sed 's/export //' > .env
for i in $(seq 1 $NUM_SIGNERS); do
  PASS="${SIGNER_PASS_PREFIX}${i}"; echo -n "$PASS" > ./config/passwords/signer${i}.pass; chmod 600 ./config/passwords/signer${i}.pass
  ADDR=$(docker run --rm -i -v "$(pwd)/data/signer${i}:/data" -v "$(pwd)/config/passwords/signer${i}.pass:/pass" ethereum/client-go:alltools-v1.13.15 geth --datadir /data account new --password /pass | grep "Public address of the key" | awk '{print $NF}')
  echo -n "$ADDR" > ./config/addresses/signer${i}.addr; 
  echo -e "SIGNER${i}_ADDRESS=$ADDR"
  echo "SIGNER${i}_ADDRESS=$ADDR" >> .env
done
for i in $(seq 1 $NUM_NONSIGNERS); do
  PASS="${NONSIGNER_PASS_PREFIX}${i}"; echo -n "$PASS" > ./config/passwords/nonsigner${i}.pass; chmod 600 ./config/passwords/nonsigner${i}.pass
  ADDR=$(docker run --rm -i -v "$(pwd)/data/nonsigner${i}:/data" -v "$(pwd)/config/passwords/nonsigner${i}.pass:/pass" ethereum/client-go:alltools-v1.13.15 geth --datadir /data account new --password /pass | grep "Public address of the key" | awk '{print $NF}')
  echo -n "$ADDR" > ./config/addresses/nonsigner${i}.addr; 
  echo -e "NONSIGNER${i}_ADDRESS=$ADDR"
  echo "NONSIGNER${i}_ADDRESS=$ADDR" >> .env
done

# --- 3. Inisialisasi Clef ---
echo -e "\n---> 3. Inisialisasi Clef untuk setiap signer (interaktif)..."
for i in $(seq 1 $NUM_SIGNERS); do
  ADDR=$(cat ./config/addresses/signer${i}.addr); PASS="${SIGNER_PASS_PREFIX}${i}"; RULE_HASH=$(sha256sum ./config/rules.js | cut -f1 -d' ')
  echo "--- Mengatur Signer ${i} ($ADDR) ---"; echo "Anda akan diminta password 3 kali. Gunakan: '${PASS}'"
  docker run --rm -it -v "$(pwd)/data/signer${i}/keystore:/root/.ethereum/keystore" -v "$(pwd)/data/clef${i}:/root/.clef" ethereum/client-go:alltools-v1.13.15 clef --keystore /root/.ethereum/keystore --configdir /root/.clef init
  docker run --rm -it -v "$(pwd)/data/signer${i}/keystore:/root/.ethereum/keystore" -v "$(pwd)/data/clef${i}:/root/.clef" ethereum/client-go:alltools-v1.13.15 clef --keystore /root/.ethereum/keystore --configdir /root/.clef setpw $ADDR
  docker run --rm -it -v "$(pwd)/data/clef${i}:/root/.clef" ethereum/client-go:alltools-v1.13.15 clef --configdir /root/.clef attest $RULE_HASH
done

# --- 4. Generate Genesis dan nodekey ---
echo -e "\n---> 4. Membuat file genesis.json dan nodekey bootnode..."
chmod +x ./scripts/generate-genesis.sh && ./scripts/generate-genesis.sh
docker run --rm -u $(id -u):$(id -g) -v "$(pwd)/data/nonsigner1/geth:/geth" ethereum/client-go:alltools-v1.13.15 bootnode -genkey /geth/nodekey

# --- 5. Generate docker-compose.yml dan Inisialisasi Geth ---
echo -e "\n---> 5. Membuat docker-compose.yml..."
chmod +x ./scripts/generate-compose.sh && ./scripts/generate-compose.sh
echo "Menginisialisasi database Geth..."
# Perlu menjalankan init di sini sebelum mendapatkan enode
for i in $(seq 1 $NUM_SIGNERS); do docker-compose run --rm --no-deps signer${i} geth init /config/genesis.json; done
for i in $(seq 1 $NUM_NONSIGNERS); do docker-compose run --rm --no-deps nonsigner${i} geth init /config/genesis.json; done

# --- 6. Dapatkan Enode ---
echo -e "\n---> 6. Mendapatkan enode dari bootnode..."
docker-compose up -d nonsigner1; sleep 5
ENODE_URL=$(docker-compose exec nonsigner1 geth attach --exec 'admin.nodeInfo.enode' | tr -d '\r\n' | jq -r '.')
docker-compose stop nonsigner1
ENODE_URL_CLEANED=$(echo $ENODE_URL | sed 's/\[::\]/nonsigner1/' | sed 's/127.0.0.1/nonsigner1/' | sed -E 's/@[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:/@nonsigner1:/')
echo -e "BOOTNODE_ENODE=${ENODE_URL_CLEANED}"
echo "BOOTNODE_ENODE=${ENODE_URL_CLEANED}" >> .env
echo "Bootnode enode ditambahkan ke .env: ${ENODE_URL_CLEANED}"

# --- 7. Finalisasi docker-compose.yml ---
echo "Memfinalisasi docker-compose.yml..."
./scripts/generate-compose.sh

# --- 8. Instruksi Manual ---
echo -e "\n\n==== PERSIAPAN SELESAI ===="
echo "Semua file telah dibuat. Sekarang jalankan jaringan secara manual."
echo "1. Buka terminal ini dan jalankan: 'docker-compose up'"
echo "2. Anda akan melihat prompt 'Enter 'ok' to proceed:' dan 'Please enter the password...' untuk setiap Clef."
echo "3. Untuk setiap prompt, ketik 'ok' (jika diminta) lalu masukkan password yang sesuai (misal: 'pass_signer_1', 'pass_signer_2', ...)"
echo "4. Setelah semua node berjalan, Anda bisa menekan Ctrl+C untuk menghentikan log."
echo "5. Untuk menjalankannya di background, jalankan: 'docker-compose up -d'"