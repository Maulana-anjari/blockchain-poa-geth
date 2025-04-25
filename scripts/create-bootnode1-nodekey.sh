echo "Membuat nodekey untuk bootnode1..."
# Pastikan direktori target ada (seharusnya sudah dibuat oleh volume mount sebelumnya)
mkdir -p data/bootnode1/geth

# Jalankan bootnode -genkey
docker run \
  --rm \
  -u $(id -u):$(id -g) \
  -v "$(pwd)/data/bootnode1/geth:/geth_data" \
  ethereum/client-go:alltools-v1.13.15 \
  bootnode -genkey /geth_data/nodekey

echo "File nodekey telah dibuat di ./data/bootnode1/geth/nodekey"