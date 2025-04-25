########################################################################
# Inisialisasi Clef, Penyimpanan Password Akun, & Attestasi Aturan
########################################################################

# --- Signer 1 ---
echo "Menginisialisasi Clef & Menyimpan Kredensial untuk Signer 1..."
# 1. Init Clef
docker run --rm -it \
  -v "$(pwd)/data/signer1/keystore:/root/.ethereum/keystore" \
  -v "$(pwd)/data/clef1:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --keystore /root/.ethereum/keystore \
    --configdir /root/.clef \
    init
# (Masukkan password master seed 'passsigner1' dua kali)

# 2. Set Password Akun
docker run --rm -it \
  -v "$(pwd)/data/signer1/keystore:/root/.ethereum/keystore" \
  -v "$(pwd)/data/clef1:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --keystore /root/.ethereum/keystore \
    --configdir /root/.clef \
    setpw ${SIGNER1_ADDRESS}
# (Ketik 'ok', lalu masukkan password akun 'passsigner1' dua kali)

# 3. Attest Rules
RULE_HASH=$(sha256sum ./config/rules.js | cut -f1 -d' ')
docker run --rm -it \
  -v "$(pwd)/data/clef1:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --configdir /root/.clef \
    attest ${RULE_HASH}
# (Masukkan password master seed 'passsigner1' sekali)

# --- Signer 2 ---
echo "Menginisialisasi Clef & Menyimpan Kredensial untuk Signer 2..."
# 1. Init Clef
docker run --rm -it \
  -v "$(pwd)/data/signer2/keystore:/root/.ethereum/keystore" \
  -v "$(pwd)/data/clef2:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --keystore /root/.ethereum/keystore \
    --configdir /root/.clef \
    init
# (Masukkan password master seed 'passsigner2' dua kali)

# 2. Set Password Akun
docker run --rm -it \
  -v "$(pwd)/data/signer2/keystore:/root/.ethereum/keystore" \
  -v "$(pwd)/data/clef2:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --keystore /root/.ethereum/keystore \
    --configdir /root/.clef \
    setpw ${SIGNER2_ADDRESS}
# (Ketik 'ok', lalu masukkan password akun 'passsigner2' dua kali)

# 3. Attest Rules
RULE_HASH=$(sha256sum ./config/rules.js | cut -f1 -d' ')
docker run --rm -it \
  -v "$(pwd)/data/clef2:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --configdir /root/.clef \
    attest ${RULE_HASH}
# (Masukkan password master seed 'passsigner2' sekali)

# --- Signer 3 ---
# 1. Init Clef
docker run --rm -it \
  -v "$(pwd)/data/signer3/keystore:/root/.ethereum/keystore" \
  -v "$(pwd)/data/clef3:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --keystore /root/.ethereum/keystore \
    --configdir /root/.clef \
    init
# (Masukkan password master seed 'passsigner3' dua kali)

# 2. Set Password Akun
docker run --rm -it \
  -v "$(pwd)/data/signer3/keystore:/root/.ethereum/keystore" \
  -v "$(pwd)/data/clef3:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --keystore /root/.ethereum/keystore \
    --configdir /root/.clef \
    setpw ${SIGNER3_ADDRESS}
# (Ketik 'ok', lalu masukkan password akun 'passsigner3' dua kali)

# 3. Attest Rules
RULE_HASH=$(sha256sum ./config/rules.js | cut -f1 -d' ')
docker run --rm -it \
  -v "$(pwd)/data/clef3:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --configdir /root/.clef \
    attest ${RULE_HASH}
# (Masukkan password master seed 'passsigner3' sekali)

# --- Signer 4 ---
# 1. Init Clef
docker run --rm -it \
  -v "$(pwd)/data/signer4/keystore:/root/.ethereum/keystore" \
  -v "$(pwd)/data/clef4:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --keystore /root/.ethereum/keystore \
    --configdir /root/.clef \
    init
# (Masukkan password master seed 'passsigner4' dua kali)

# 2. Set Password Akun
docker run --rm -it \
  -v "$(pwd)/data/signer4/keystore:/root/.ethereum/keystore" \
  -v "$(pwd)/data/clef4:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --keystore /root/.ethereum/keystore \
    --configdir /root/.clef \
    setpw ${SIGNER4_ADDRESS}
# (Ketik 'ok', lalu masukkan password akun 'passsigner4' dua kali)

# 3. Attest Rules
RULE_HASH=$(sha256sum ./config/rules.js | cut -f1 -d' ')
docker run --rm -it \
  -v "$(pwd)/data/clef4:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --configdir /root/.clef \
    attest ${RULE_HASH}
# (Masukkan password master seed 'passsigner4' sekali)

# --- Signer 5 ---
# 1. Init Clef
docker run --rm -it \
  -v "$(pwd)/data/signer5/keystore:/root/.ethereum/keystore" \
  -v "$(pwd)/data/clef5:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --keystore /root/.ethereum/keystore \
    --configdir /root/.clef \
    init
# (Masukkan password master seed 'passsigner5' dua kali)

# 2. Set Password Akun
docker run --rm -it \
  -v "$(pwd)/data/signer5/keystore:/root/.ethereum/keystore" \
  -v "$(pwd)/data/clef5:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --keystore /root/.ethereum/keystore \
    --configdir /root/.clef \
    setpw ${SIGNER5_ADDRESS}
# (Ketik 'ok', lalu masukkan password akun 'passsigner5' dua kali)

# 3. Attest Rules
RULE_HASH=$(sha256sum ./config/rules.js | cut -f1 -d' ')
docker run --rm -it \
  -v "$(pwd)/data/clef5:/root/.clef" \
  ethereum/client-go:alltools-v1.13.15 clef \
    --configdir /root/.clef \
    attest ${RULE_HASH}
# (Masukkan password master seed 'passsigner5' sekali)

echo "Persiapan Clef Selesai."