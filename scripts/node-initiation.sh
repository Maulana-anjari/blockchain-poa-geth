echo "Inisialisasi database Geth untuk semua node..."

# Bootnode (Non-Signer 1)
docker-compose run --rm --no-deps bootnode1 geth init /config/genesis.json

# Signer Nodes (1-5)
docker-compose run --rm --no-deps signer1 geth init /config/genesis.json
docker-compose run --rm --no-deps signer2 geth init /config/genesis.json
docker-compose run --rm --no-deps signer3 geth init /config/genesis.json
docker-compose run --rm --no-deps signer4 geth init /config/genesis.json
docker-compose run --rm --no-deps signer5 geth init /config/genesis.json

# Non-Signer Nodes (2-5)
docker-compose run --rm --no-deps nonsigner2 geth init /config/genesis.json
docker-compose run --rm --no-deps nonsigner3 geth init /config/genesis.json
docker-compose run --rm --no-deps nonsigner4 geth init /config/genesis.json
docker-compose run --rm --no-deps nonsigner5 geth init /config/genesis.json

echo "Inisialisasi Geth Selesai."