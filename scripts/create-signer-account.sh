# Signer 1
echo "Membuat akun untuk Signer 1. Masukkan password '${SIGNER1_PASSWORD}' dua kali."
docker run --rm -it -v "$(pwd)/data/signer1/keystore:/root/.ethereum/keystore" \
  ethereum/client-go:alltools-v1.13.15 clef newaccount --keystore /root/.ethereum/keystore

# Signer 2
echo "Membuat akun untuk Signer 2. Masukkan password '${SIGNER2_PASSWORD}' dua kali."
docker run --rm -it -v "$(pwd)/data/signer2/keystore:/root/.ethereum/keystore" \
  ethereum/client-go:alltools-v1.13.15 clef newaccount --keystore /root/.ethereum/keystore

# Signer 3
echo "Membuat akun untuk Signer 3. Masukkan password '${SIGNER3_PASSWORD}' dua kali."
docker run --rm -it -v "$(pwd)/data/signer3/keystore:/root/.ethereum/keystore" \
  ethereum/client-go:alltools-v1.13.15 clef newaccount --keystore /root/.ethereum/keystore

# Signer 4
echo "Membuat akun untuk Signer 4. Masukkan password '${SIGNER4_PASSWORD}' dua kali."
docker run --rm -it -v "$(pwd)/data/signer4/keystore:/root/.ethereum/keystore" \
  ethereum/client-go:alltools-v1.13.15 clef newaccount --keystore /root/.ethereum/keystore

# Signer 5
echo "Membuat akun untuk Signer 5. Masukkan password '${SIGNER5_PASSWORD}' dua kali."
docker run --rm -it -v "$(pwd)/data/signer5/keystore:/root/.ethereum/keystore" \
  ethereum/client-go:alltools-v1.13.15 clef newaccount --keystore /root/.ethereum/keystore