# **Tutorial Lengkap: Membangun Jaringan Private Blockchain Geth Clique PoA (v1.13.15) dengan Docker, Clef External Signer, dan Monitoring dengan NetStats dan Grafana**

## **Pendahuluan**

Selamat datang di panduan komprehensif untuk membangun jaringan blockchain Ethereum private Anda sendiri menggunakan mekanisme konsensus Proof of Authority (PoA) Clique. Tutorial ini secara spesifik menggunakan **Geth versi 1.13.15**, versi terakhir sebelum Clique di-deprecate, memastikan fungsionalitas PoA penuh.

Kita akan menerapkan arsitektur modern dan aman dengan **memisahkan penandatangan (signer) dari node Geth utama** menggunakan **Clef** sebagai external signer. Seluruh infrastruktur jaringan, termasuk 10 node Geth (5 sebagai signer/authority, 5 sebagai non-authority), 5 instance Clef pendamping, dan tumpukan monitoring (Ethstats, InfluxDB, Grafana), akan diorkestrasi menggunakan **Docker dan Docker Compose** untuk kemudahan pengelolaan, reproduktibilitas, dan deployment.

Arsitektur ini terinspirasi oleh praktik yang baik dalam mengelola jaringan PoA dan menggabungkan solusi dari berbagai tantangan konfigurasi yang umum ditemui.

**👷Target Audiens:** Pengguna tingkat menengah (intermediate) yang memiliki pemahaman dasar tentang:

- Konsep Blockchain dan Ethereum (PoA, Node, Akun, Genesis).
- Penggunaan baris perintah (Command Line Interface - CLI) Linux.
- Dasar-dasar Docker dan Docker Compose.

**🖥️Teknologi yang Digunakan:**

- **Geth:** 1.13.15 (via image Docker ethereum/client-go:alltools-v1.13.15)
- **Konsensus:** Clique Proof of Authority (PoA)
- **External Signer:** Clef 1.13.15 (dari image Docker yang sama)
- **Orkestrasi:** Docker & Docker Compose
- **Konfigurasi:** File .env, genesis.json, rules.js (Clef)
- **Monitoring:**
    - Ethstats (Server dari fork Goerli, dibangun dari source github)
    - InfluxDB v1.8 (Time-series Database)
    - Grafana (Visualisasi Dashboard)

🔗**Struktur Jaringan Target:**

- **Total 10 Node Geth:**
    - 5 Node Signer (Authority): Bertugas memvalidasi dan menandatangani blok baru, menggunakan Clef untuk penandatanganan.
    - 5 Node Non-Signer (Regular/RPC Nodes): Menyinkronkan blockchain, melayani permintaan RPC, tetapi tidak berpartisipasi dalam penandatanganan blok. Salah satunya akan bertindak sebagai bootnode utama.
- **5 Instance Clef:** Satu instance untuk setiap node signer, berjalan dalam container terpisah.
- **Layanan Monitoring:** Ethstats Server, InfluxDB, Grafana, masing-masing dalam container terpisah.
- Semua komponen terhubung dalam jaringan Docker internal.

Mari kita mulai proses pembangunan jaringan ini!

## **Bagian 1: Prasyarat Perangkat Lunak di Host**

Sebelum melanjutkan, pastikan perangkat lunak berikut telah terinstal dan berfungsi dengan baik di sistem host Anda (baik WSL Ubuntu 24 maupun VPS Ubuntu 22):

1. **Docker Engine:** Versi 24.0 atau yang kompatibel.
2. **Docker Compose:** Versi yang mendukung spesifikasi Compose v3.7 atau lebih tinggi.
3. **Git:** Diperlukan untuk membangun image Ethstats dari source GitHub.
4. **Text Editor:** (misal: nano, vim, VS Code) Untuk membuat dan mengedit file konfigurasi.
5. **(Sangat Direkomendasikan) curl:** Alat bantu untuk menguji endpoint RPC Geth.
6. **(Sangat Direkomendasikan) jq:** Alat bantu untuk memproses output JSON dari CLI atau RPC.
7. **Web Browser:** Untuk mengakses antarmuka web Ethstats dan Grafana.

**Catatan Penting:**

- Anda **tidak perlu** menginstal Geth atau Clef secara manual di sistem host Anda untuk menjalankan jaringan final. Kita akan menggunakan image Docker yang sudah menyediakannya.
- Namun, **memiliki geth v1.13.x terinstal di host** akan berguna untuk langkah persiapan pembuatan akun non-signer. Jika Anda tidak memilikinya, Anda bisa menggunakan container Docker sementara seperti yang akan ditunjukkan.
- Pastikan user Anda memiliki **izin untuk menjalankan perintah Docker** (biasanya dengan menambahkan user ke grup docker dan memulai sesi terminal baru).

## **Bagian 2: Struktur Direktori Proyek**

Organisasi yang baik akan mempermudah pengelolaan. Buat struktur direktori berikut di lokasi proyek Anda:

``` bash
# Ganti 'proyek-blockchain-poa' dengan nama direktori pilihan Anda 
mkdir proyek-blockchain-poa 
cd proyek-blockchain-poa  # Direktori konfigurasi 
mkdir -p \
  config \
  scripts \
  data/bootnode1/geth \
  data/{signer,nonsigner}{1..5}/keystore \
  data/clef{1..5} \
  data/influxdb \
  data/grafana
```

Struktur dasar Anda akan terlihat seperti ini:

``` structure folder
proyek-blockchain-poa/ 
├── config/ 
├── data/ 
│   ├── bootnode1/ 
│   │   └── geth/ 
│   ├── clef1/ 
│   ├── clef2/ 
│   ├── clef3/ 
│   ├── clef4/ 
│   ├── clef5/
│   ├── grafana/ 
│   ├── influxdb/ 
│   ├── nonsigner1/ 
│   │   └── keystore/ 
│   ├── nonsigner2/ 
│   │   └── keystore/ 
│   ├── nonsigner3/ 
│   │   └── keystore/ 
│   ├── nonsigner4/ 
│   │   └── keystore/ 
│   ├── nonsigner5/ 
│   │   └── keystore/ 
│   ├── signer1/ │   
│   └── keystore/ 
│   ├── signer2/ 
│   │   └── keystore/ 
│   # ... (signer3-5) 
├── scripts/ 
├── docker-compose.yml  # Akan dibuat 
└── .env                # Akan dibuat
```

## **Bagian 3: File Konfigurasi Inti**

Kita perlu menyiapkan tiga file konfigurasi utama: aturan Clef, blok genesis, dan variabel lingkungan.

### **3.1. File Aturan Clef (config/rules.js)**

File ini sangat penting agar Clef dapat secara otomatis menyetujui permintaan penandatanganan blok Clique dari node Geth signer. Buat file bernama rules.js di dalam direktori config/ dengan konten berikut (diambil dari contoh dokumentasi Clef/Dchain):

``` javascript
// File: config/rules.js
// Fungsi ini bisa dikosongkan atau digunakan untuk logging saat Clef dimulai
function OnSignerStartup(info) {
// console.log("Clef Signer Started: ", JSON.stringify(info));
}

// Fungsi ini mengizinkan Geth (atau klien lain) untuk melihat daftar
// akun yang dikelola oleh instance Clef ini. Penting untuk Geth
// saat menggunakan flag --signer.
function ApproveListing() {
    return "Approve";
}

// Fungsi ini adalah inti untuk otomatisasi PoA.
// Ia memeriksa apakah permintaan penandatanganan data adalah untuk header blok Clique.
function ApproveSignData(r) {
// Periksa tipe konten permintaan
    if (r.content_type == "application/x-clique-header") {
        // Lakukan verifikasi internal Clef pada pesan
        for (var i = 0; i < r.messages.length; i++) {
            var msg = r.messages[i];
            // Jika pesan terverifikasi sebagai header Clique yang valid oleh Clef
            if (msg.name == "Clique header" && msg.type == "clique") {
                // Setujui penandatanganan secara otomatis
                console.log("Approved clique header signing for block ", msg.value);
                return "Approve";
            }
        }
    }
    // Tolak semua jenis permintaan penandatanganan data lainnya secara default.
    // Ini mencegah Clef menandatangani transaksi arbitrer kecuali ada aturan spesifik lain.
    console.log("Rejected signing request: ", JSON.stringify(r));
    return "Reject";
}

// Fungsi ini menangani persetujuan transaksi. Untuk PoA murni di mana
// signer hanya menandatangani blok, fungsi ini bisa dibuat sangat ketat
// (selalu Reject) atau dibiarkan kosong (akan meminta persetujuan manual
// jika ada permintaan penandatanganan transaksi).
function ApproveTx(r) {
    console.log("Received Tx request: ", JSON.stringify(r));
    // Untuk keamanan maksimal, tolak semua transaksi keluar dari akun signer ini.
    // Transaksi bisa dikirim dari akun lain atau melalui metode lain.
    return "Reject";
}
```

### **3.2. File Genesis (config/genesis.json)**

File ini mendefinisikan blok pertama dan parameter dasar jaringan Anda. Buat file bernama genesis.json di dalam direktori config/.

**PENTING:** Anda harus mengganti 0x<ALAMAT_SIGNER_X> dengan 5 alamat Ethereum **tanpa** awalan 0x yang akan Anda buat untuk signer pada langkah berikutnya. Anda juga perlu mengganti 0x<ALAMAT_NON_SIGNER_X> dengan 5 alamat untuk node non-signer.

``` JSON
// File: config/genesis.json 
{
    "config": {
        "chainId": 2904,
        "homesteadBlock": 0,
        "eip150Block": 0,
        "eip155Block": 0,
        "eip158Block": 0,
        "byzantiumBlock": 0,
        "constantinopleBlock": 0,
        "petersburgBlock": 0,
        "istanbulBlock": 0,
        "berlinBlock": 0,
        "londonBlock": 0,
        "clique": {
            "period": 15,
            "epoch": 30000
        }
    },
    "difficulty": "1",
    "gasLimit": "8000000",
    "extradata": "0x0000000000000000000000000000000000000000000000000000000000000000<ALAMAT_SIGNER_1><ALAMAT_SIGNER_2><ALAMAT_SIGNER_3><ALAMAT_SIGNER_4><ALAMAT_SIGNER_5>0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    "alloc": {
        "0x<ALAMAT_SIGNER_1>": {
            "balance": "30000000000000000000"
        },
        "0x<ALAMAT_SIGNER_2>": {
            "balance": "30000000000000000000"
        },
        "0x<ALAMAT_SIGNER_3>": {
            "balance": "30000000000000000000"
        },
        "0x<ALAMAT_SIGNER_4>": {
            "balance": "30000000000000000000"
        },
        "0x<ALAMAT_SIGNER_5>": {
            "balance": "30000000000000000000"
        },
        "0x<ALAMAT_NON_SIGNER_1>": {
            "balance": "30000000000000000000"
        },
        "0x<ALAMAT_NON_SIGNER_2>": {
            "balance": "30000000000000000000"
        },
        "0x<ALAMAT_NON_SIGNER_3>": {
            "balance": "30000000000000000000"
        },
        "0x<ALAMAT_NON_SIGNER_4>": {
            "balance": "30000000000000000000"
        },
        "0x<ALAMAT_NON_SIGNER_5>": {
            "balance": "30000000000000000000"
        }
    }
}
```


- chainId: ID unik jaringan Anda (dalam tutorial ini dipakai 2904, Anda bisa gunakan yang lain misal 1212, 123456, dll.).
- clique.period: Waktu target antar blok (15 detik).
- clique.epoch: Jumlah blok sebelum vote signer di-reset (default Geth 30000).
- extradata: Harus berisi 32 byte padding nol, diikuti oleh 5 alamat signer (masing-masing 20 byte, **tanpa** 0x), diikuti 65 byte padding nol. Pastikan panjang totalnya benar.
- alloc: Alokasi saldo awal 30 ETH (dalam Wei) untuk semua 10 akun awal. Alamat di sini **harus** diawali 0x.

### **3.3. File Variabel Lingkungan (.env)**

File ini menyimpan semua konfigurasi spesifik dan rahasia. Docker Compose akan otomatis memuatnya. Buat file bernama .env di direktori root proyek Anda.

**PENTING:** Ganti semua nilai placeholder <...> dengan nilai sebenarnya. Simpan file ini dengan aman dan **jangan pernah** memasukkannya ke dalam repositori Git publik jika berisi informasi sensitif.

``` environtment
# File: .env
# ================================================
# Environment Configuration for Geth Clique PoA Network
# ================================================

# -- General Settings --
NETWORK_ID=2904
# Nama proyek untuk Docker Compose
COMPOSE_PROJECT_NAME=geth_clique_poa

# -- Node & Account Passwords --
# !!! PERINGATAN KEAMANAN: Menyimpan password dalam teks biasa seperti ini SANGAT TIDAK AMAN untuk lingkungan produksi. !!!
# !!! Gunakan metode yang lebih aman (misalnya, Docker secrets, HashiCorp Vault, atau input manual yang aman) di luar konteks tutorial ini. !!!
SIGNER1_PASSWORD=passsigner1
SIGNER2_PASSWORD=passsigner2
SIGNER3_PASSWORD=passsigner3
SIGNER4_PASSWORD=passsigner4
SIGNER5_PASSWORD=passsigner5

# Juga digunakan untuk akun Bootnode
NONSIGNER1_PASSWORD=passnonsigner1
NONSIGNER2_PASSWORD=passnonsigner2
NONSIGNER3_PASSWORD=passnonsigner3
NONSIGNER4_PASSWORD=passnonsigner4
NONSIGNER5_PASSWORD=passnonsigner5

# -- Signer Addresses --
# GANTI dengan alamat Ethereum (diawali 0x) yang dihasilkan untuk setiap signer pada Langkah 4.1
SIGNER1_ADDRESS=0x<ALAMAT_SIGNER_1>
SIGNER2_ADDRESS=0x<ALAMAT_SIGNER_2>
SIGNER3_ADDRESS=0x<ALAMAT_SIGNER_3>
SIGNER4_ADDRESS=0x<ALAMAT_SIGNER_4>
SIGNER5_ADDRESS=0x<ALAMAT_SIGNER_5>

# -- Non-Signer Addresses --
# GANTI dengan alamat Ethereum (diawali 0x) yang dihasilkan untuk setiap non-signer pada Langkah 4.1
NONSIGNER1_ADDRESS=0x<ALAMAT_NONSIGNER_1>
NONSIGNER2_ADDRESS=0x<ALAMAT_NONSIGNER_2>
NONSIGNER3_ADDRESS=0x<ALAMAT_NONSIGNER_3>
NONSIGNER4_ADDRESS=0x<ALAMAT_NONSIGNER_4>
NONSIGNER5_ADDRESS=0x<ALAMAT_NONSIGNER_5>

# -- Clef Master Password Variable (Untuk digunakan oleh shell script) --
# Kita samakan dengan password akun untuk tutorial ini
CLEF1_MASTER_PASSWORD=${SIGNER1_PASSWORD}
CLEF2_MASTER_PASSWORD=${SIGNER2_PASSWORD}
CLEF3_MASTER_PASSWORD=${SIGNER3_PASSWORD}
CLEF4_MASTER_PASSWORD=${SIGNER4_PASSWORD}
CLEF5_MASTER_PASSWORD=${SIGNER5_PASSWORD}

# -- Bootnode Configuration --
# KOSONGKAN AWALNYA. Akan diisi dengan enode URL lengkap dari bootnode1 setelah langkah persiapan. contoh=enode<ID>@<bootnode>:<port>
BOOTNODE_ENODE=

# -- Ethstats Configuration --
# Ganti dengan secret string yang kuat dan unik. Geth node dan Ethstats Server harus menggunakan secret yang sama.
ETHSTATS_WS_SECRET=<GANTI_DENGAN_SECRET_AMAN_ETHSTATS>
# Password ini hanya digunakan oleh Geth untuk mengirim data, BUKAN untuk mengakses dashboard.

# -- InfluxDB Configuration --
INFLUXDB_DB=geth_metrics
INFLUXDB_USER=geth_user
# Ganti dengan password yang kuat dan aman untuk user database InfluxDB.
INFLUXDB_PASSWORD=<GANTI_DENGAN_PASSWORD_AMAN_INFLUXDB>
# Nama service InfluxDB di Docker Compose
INFLUXDB_HOST=influxdb
# Port default internal InfluxDB
INFLUXDB_PORT=8086

# -- Grafana Configuration --
# Ganti dengan password admin yang kuat untuk login awal ke Grafana. Anda akan diminta menggantinya saat login pertama.
GRAFANA_ADMIN_PASSWORD=<GANTI_DENGAN_PASSWORD_ADMIN_GRAFANA>

# -- Port Mappings (Host -> Container) --
# Port yang akan diekspos di mesin host Anda (WSL/VPS).
# Sesuaikan jika port default bentrok di host Anda.

# Bootnode (Non-Signer 1)
# Port P2P harus diekspos untuk koneksi dari node lain
BOOTNODE1_P2P_PORT=30303
BOOTNODE1_HTTP_PORT=8545
BOOTNODE1_WS_PORT=8546

# Signer Nodes (Hanya RPC)
SIGNER1_HTTP_PORT=8550
SIGNER1_WS_PORT=8551
SIGNER2_HTTP_PORT=8552
SIGNER2_WS_PORT=8553
SIGNER3_HTTP_PORT=8554
SIGNER3_WS_PORT=8555
SIGNER4_HTTP_PORT=8556
SIGNER4_WS_PORT=8557
SIGNER5_HTTP_PORT=8558
SIGNER5_WS_PORT=8559

# Non-Signer Nodes (Selain Bootnode - Hanya RPC)
NONSIGNER2_HTTP_PORT=8562
NONSIGNER2_WS_PORT=8563
NONSIGNER3_HTTP_PORT=8564
NONSIGNER3_WS_PORT=8565
NONSIGNER4_HTTP_PORT=8566
NONSIGNER4_WS_PORT=8567
NONSIGNER5_HTTP_PORT=8568
NONSIGNER5_WS_PORT=8569

# Monitoring Services (Akses via Browser)
# Port host untuk mengakses dashboard Ethstats
ETHSTATS_PORT=8080
# Port host untuk mengakses dashboard Grafana
GRAFANA_PORT=3000
```

## **Bagian 4: Persiapan Akun, Kunci, dan Kredensial (Langkah Interaktif)**

Bagian ini melibatkan perintah yang memerlukan input manual Anda (terutama password) dan harus dijalankan di terminal pada direktori root proyek Anda (proyek-blockchain-poa/).

### **4.1. Membuat Akun Ethereum (Total 10 Akun)**

- **Akun Signer (5 Akun - Menggunakan Clef):**  
    Jalankan perintah satu per satu, sekali untuk setiap signer. Anda akan diminta memasukkan password signer (passsigner1, dst.) dua kali untuk setiap akun. **CATAT alamat publik (Address: {0x...}) yang dihasilkan untuk setiap signer.**

``` bash
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
```

- **Akun Non-Signer (5 Akun - Menggunakan Geth):**  
    Jalankan perintah berikut 5 kali. Ini menggunakan file password sementara untuk otomatisasi. **CATAT alamat publik (Public address of the key: 0x...) yang dihasilkan untuk setiap non-signer.**

``` bash
# Non-Signer 1 (Bootnode)
echo "${NONSIGNER1_PASSWORD}" > config/nonsigner1.pass
docker run --rm -it -v "$(pwd)/data/nonsigner1/keystore:/root/.ethereum/keystore" -v "$(pwd)/config/nonsigner1.pass:/root/password.txt" \
  ethereum/client-go:alltools-v1.13.15 geth account new --keystore /root/.ethereum/keystore --password /root/password.txt
rm config/nonsigner1.pass

# Non-Signer 2
echo "${NONSIGNER2_PASSWORD}" > config/nonsigner2.pass
docker run --rm -it -v "$(pwd)/data/nonsigner2/keystore:/root/.ethereum/keystore" -v "$(pwd)/config/nonsigner2.pass:/root/password.txt" \
  ethereum/client-go:alltools-v1.13.15 geth account new --keystore /root/.ethereum/keystore --password /root/password.txt
rm config/nonsigner2.pass

# Non-Signer 3
echo "${NONSIGNER3_PASSWORD}" > config/nonsigner3.pass
docker run --rm -it -v "$(pwd)/data/nonsigner3/keystore:/root/.ethereum/keystore" -v "$(pwd)/config/nonsigner3.pass:/root/password.txt" \
  ethereum/client-go:alltools-v1.13.15 geth account new --keystore /root/.ethereum/keystore --password /root/password.txt
rm config/nonsigner3.pass

# Non-Signer 4
echo "${NONSIGNER4_PASSWORD}" > config/nonsigner4.pass
docker run --rm -it -v "$(pwd)/data/nonsigner4/keystore:/root/.ethereum/keystore" -v "$(pwd)/config/nonsigner4.pass:/root/password.txt" \
  ethereum/client-go:alltools-v1.13.15 geth account new --keystore /root/.ethereum/keystore --password /root/password.txt
rm config/nonsigner4.pass

# Non-Signer 5
echo "${NONSIGNER5_PASSWORD}" > config/nonsigner5.pass
docker run --rm -it -v "$(pwd)/data/nonsigner5/keystore:/root/.ethereum/keystore" -v "$(pwd)/config/nonsigner5.pass:/root/password.txt" \
  ethereum/client-go:alltools-v1.13.15 geth account new --keystore /root/.ethereum/keystore --password /root/password.txt
rm config/nonsigner5.pass
```

**PENTING**: Sekarang, kembali ke file config/genesis.json dan .env Anda untuk mengisi placeholder alamat signer dan non-signer dengan alamat yang baru saja Anda catat.

### **4.2. Inisialisasi Clef, Penyimpanan Password Akun, & Attestasi Aturan**

Langkah ini mempersiapkan setiap instance Clef untuk berjalan secara otomatis. Ini memerlukan input password interaktif.

- **Ekspor Variabel .env (Penting):** Agar perintah docker run dapat mengenali ${SIGNERX_ADDRESS}, ekspor variabel dari .env ke sesi terminal Anda saat ini:

``` bash
export $(grep -v '^#' .env | xargs)
```

(Catatan: Perintah ini mungkin perlu penyesuaian untuk shell selain bash/zsh atau jika nilai .env kompleks).

- **Jalankan Persiapan untuk Setiap Signer (jalankan satu per satu jangan sekaligus):**  
    Anda akan diminta password **Master Seed** (saat init), lalu ketik ok, lalu password **Akun Signer** (saat setpw), lalu password **Master Seed** lagi (saat attest). Gunakan password yang sesuai (passsigner1, passsigner2, dst.) untuk setiap signer.
    
``` bash
########################################################################
# Inisialisasi Clef, Penyimpanan Password Akun, & Attestasi Aturan
########################################################################

########################################################################
# --- Signer 1 ---
########################################################################
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

########################################################################
# --- Signer 2 ---
########################################################################
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

########################################################################
# --- Signer 3 ---
########################################################################
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

########################################################################
# --- Signer 4 ---
########################################################################
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

########################################################################
# --- Signer 5 ---
########################################################################
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
```

### **4.3. Membuat Node Key untuk Bootnode (bootnode1)**

Ini memastikan bootnode memiliki identitas jaringan (enode) yang stabil.

``` bash
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
```

### **4.4. Membuat Dockerfile untuk Clef**

``` Dockerfile
# File: Dockerfile.clef
# Gunakan image resmi sebagai basis (yang kemungkinan Alpine)
FROM ethereum/client-go:alltools-v1.13.15

# Instal expect menggunakan package manager Alpine (apk)
# 'apk update' memperbarui daftar paket
# 'apk add --no-cache' menginstal paket tanpa menyimpan cache (lebih hemat ruang)
RUN apk update && apk add --no-cache expect

# Salin skrip startup yang akan menggunakan expect
COPY scripts/start-clef.sh /usr/local/bin/start-clef.sh
RUN chmod +x /usr/local/bin/start-clef.sh

# Set skrip startup sebagai entrypoint atau command default
ENTRYPOINT ["/usr/local/bin/start-clef.sh"]
```

Lalu buat file bash untuk dijalankan oleh container clef. Ini berguna untuk mengatasi permintaan input password pada clef pada saat docker-compose up -d

``` bash
#!/usr/bin/expect -f
# File: scripts/start-clef.sh

# Ambil password dari environment variable yang akan kita set di docker-compose
set clef_master_password $env(CLEF_MASTER_PASSWORD)
# Ambil variabel lain yang diperlukan dari env (jika perlu, contoh: chain id)
set chain_id $env(NETWORK_ID)
set keystore_path "/root/.ethereum/keystore"
set config_dir "/root/.clef"
set rules_path "/root/rules.js"

# Set timeout tak terbatas agar expect tidak keluar terlalu cepat
set timeout -1

# Jalankan (spawn) proses Clef
# Perhatikan: Kita tidak lagi menyalurkan 'echo ok'
spawn clef --keystore $keystore_path --configdir $config_dir --chainid $chain_id --rules $rules_path --nousb --advanced --http --http.addr 0.0.0.0 --http.port 8550 --http.vhosts "*"

# Harapkan (expect) prompt "Enter 'ok' to proceed:"
expect "Enter 'ok' to proceed:"
# Kirim (send) "ok" diikuti newline (\r)
send "ok\n"

# Harapkan prompt password master seed
expect "Please enter the password to decrypt the master seed"
# Kirim password dari environment variable diikuti newline
send "$clef_master_password\n"

# Biarkan proses Clef berjalan di foreground
# interact
# 'interact' memberikan kontrol kembali ke user, tapi dalam Docker detached,
# ini akan menjaga skrip tetap berjalan dan Clef aktif.
# Alternatif lain adalah 'expect eof' jika Anda ingin skrip selesai
# setelah Clef berhasil dimulai, tapi Clef mungkin keluar jika skrip induknya selesai.
# Gunakan 'interact' agar Clef tetap berjalan.


# Tunggu hingga proses clef selesai/menutup output, bukan interact
expect eof
```

## **Bagian 5: Inisialisasi Database Node Geth**

Setiap node Geth perlu diinisialisasi dengan genesis.json sebelum dijalankan pertama kali.

``` bash
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
```  

## **Bagian 6: File docker-compose.yml Lengkap**

File ini mendefinisikan semua service (Geth, Clef, Monitoring) dan bagaimana mereka terhubung. Buat file docker-compose.yml di direktori root proyek Anda dengan konten berikut:

``` yml
# File: docker-compose.yml
version: '3.8'

services:
  # --- Bootnode (Non-Signer 1) ---
  bootnode1:
    image: ethereum/client-go:alltools-v1.13.15
    container_name: bootnode1
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/bootnode1:/root/.ethereum # Volume untuk chaindata & nodekey
      # Keystore non-signer 1 diperlukan jika Anda ingin menggunakan API 'personal'
      - ./data/nonsigner1/keystore:/root/.ethereum/keystore:ro
      # File password non-signer 1 jika menggunakan API 'personal'
      - ./config/nonsigner1.pass:/root/password.txt:ro
    ports:
      # Port P2P HARUS diekspos agar node lain bisa terhubung
      - "${BOOTNODE1_P2P_PORT:-30303}:${BOOTNODE1_P2P_PORT:-30303}/tcp"
      - "${BOOTNODE1_P2P_PORT:-30303}:${BOOTNODE1_P2P_PORT:-30303}/udp"
      # Port RPC untuk interaksi
      - "${BOOTNODE1_HTTP_PORT:-8545}:8545"
      - "${BOOTNODE1_WS_PORT:-8546}:8546"
    command: >
      geth
      --nodekey /root/.ethereum/geth/nodekey
      --datadir /root/.ethereum
      --keystore /root/.ethereum/keystore
      --networkid "${NETWORK_ID:-2904}"
      --syncmode full
      --gcmode archive
      --port "${BOOTNODE1_P2P_PORT:-30303}"
      --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin,personal" --http.corsdomain "*" --http.vhosts "*"
      --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin,personal" --ws.origins "*"
      --metrics --metrics.expensive --metrics.influxdb
      --metrics.influxdb.endpoint "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}"
      --metrics.influxdb.database "${INFLUXDB_DB}"
      --metrics.influxdb.username "${INFLUXDB_USER}"
      --metrics.influxdb.password "${INFLUXDB_PASSWORD}"
      --ethstats "bootnode1:${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --password /root/password.txt
      --allow-insecure-unlock
    networks:
      - geth-network
    restart: unless-stopped

  # --- Signer Node 1 ---
  clef1:
    # image: ethereum/client-go:alltools-v1.13.15
    build:
      context: .
      dockerfile: Dockerfile.clef
    container_name: clef1
    volumes:
      - ./data/signer1/keystore:/root/.ethereum/keystore:ro # Hanya perlu baca keystore
      - ./data/clef1:/root/.clef # Direktori config & data Clef (termasuk masterseed, credentials)
      - ./config/rules.js:/root/rules.js:ro # File aturan
    # Jalankan clef via sh untuk melewati prompt 'ok'
    environment:
      # Sediakan password dan variabel lain yang dibutuhkan skrip expect
      CLEF_MASTER_PASSWORD: ${SIGNER1_PASSWORD}
      NETWORK_ID: ${NETWORK_ID:-2904}
    networks:
      - geth-network
    restart: unless-stopped

  signer1:
    image: ethereum/client-go:alltools-v1.13.15
    container_name: signer1
    depends_on:
      - clef1
      - bootnode1
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/signer1:/root/.ethereum # Volume untuk chaindata
    ports:
      - "${SIGNER1_HTTP_PORT:-8550}:8545"
      - "${SIGNER1_WS_PORT:-8551}:8546"
    command: >
      geth
      --datadir /root/.ethereum
      --networkid "${NETWORK_ID:-2904}"
      --syncmode full
      --port 30304
      --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin" --http.corsdomain "*" --http.vhosts "*"
      --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin" --ws.origins "*"
      --metrics --metrics.expensive --metrics.influxdb
      --metrics.influxdb.endpoint "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}"
      --metrics.influxdb.database "${INFLUXDB_DB}"
      --metrics.influxdb.username "${INFLUXDB_USER}"
      --metrics.influxdb.password "${INFLUXDB_PASSWORD}"
      --ethstats "signer1:${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --bootnodes "${BOOTNODE_ENODE}"
      --signer "http://clef1:8550"
      --mine
      --miner.etherbase "${SIGNER1_ADDRESS}"
    networks:
      - geth-network
    restart: unless-stopped

  # --- Signer Node 2 ---
  clef2:
    build:
      context: .
      dockerfile: Dockerfile.clef
    container_name: clef2
    volumes:
      - ./data/signer2/keystore:/root/.ethereum/keystore:ro
      - ./data/clef2:/root/.clef
      - ./config/rules.js:/root/rules.js:ro
    environment:
      # Sediakan password dan variabel lain yang dibutuhkan skrip expect
      CLEF_MASTER_PASSWORD: ${SIGNER2_PASSWORD}
      NETWORK_ID: ${NETWORK_ID:-2904}
    networks:
      - geth-network
    restart: unless-stopped

  signer2:
    image: ethereum/client-go:alltools-v1.13.15
    container_name: signer2
    depends_on: [clef2, bootnode1]
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/signer2:/root/.ethereum
    ports:
      - "${SIGNER2_HTTP_PORT:-8552}:8545"
      - "${SIGNER2_WS_PORT:-8553}:8546"
    command: >
      geth --datadir /root/.ethereum --networkid "${NETWORK_ID:-2904}" --syncmode full --port 30305
      --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin" --http.corsdomain "*" --http.vhosts "*"
      --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin" --ws.origins "*"
      --metrics --metrics.expensive --metrics.influxdb --metrics.influxdb.endpoint "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}" --metrics.influxdb.database "${INFLUXDB_DB}" --metrics.influxdb.username "${INFLUXDB_USER}" --metrics.influxdb.password "${INFLUXDB_PASSWORD}"
      --ethstats "signer2:${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --bootnodes "${BOOTNODE_ENODE}" --signer "http://clef2:8550" --mine --miner.etherbase "${SIGNER2_ADDRESS}"
    networks:
      - geth-network
    restart: unless-stopped

  # --- Signer Node 3 ---
  clef3:
    build:
      context: .
      dockerfile: Dockerfile.clef
    container_name: clef3
    volumes:
      - ./data/signer3/keystore:/root/.ethereum/keystore:ro
      - ./data/clef3:/root/.clef
      - ./config/rules.js:/root/rules.js:ro
    environment:
      # Sediakan password dan variabel lain yang dibutuhkan skrip expect
      CLEF_MASTER_PASSWORD: ${SIGNER3_PASSWORD}
      NETWORK_ID: ${NETWORK_ID:-2904}
    networks:
      - geth-network
    restart: unless-stopped

  signer3:
    image: ethereum/client-go:alltools-v1.13.15
    container_name: signer3
    depends_on: [clef3, bootnode1]
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/signer3:/root/.ethereum
    ports:
      - "${SIGNER3_HTTP_PORT:-8554}:8545"
      - "${SIGNER3_WS_PORT:-8555}:8546"
    command: >
      geth --datadir /root/.ethereum --networkid "${NETWORK_ID:-2904}" --syncmode full --port 30306
      --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin" --http.corsdomain "*" --http.vhosts "*"
      --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin" --ws.origins "*"
      --metrics --metrics.expensive --metrics.influxdb --metrics.influxdb.endpoint "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}" --metrics.influxdb.database "${INFLUXDB_DB}" --metrics.influxdb.username "${INFLUXDB_USER}" --metrics.influxdb.password "${INFLUXDB_PASSWORD}"
      --ethstats "signer3:${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --bootnodes "${BOOTNODE_ENODE}" --signer "http://clef3:8550" --mine --miner.etherbase "${SIGNER3_ADDRESS}"
    networks:
      - geth-network
    restart: unless-stopped

  # --- Signer Node 4 ---
  clef4:
    build:
      context: .
      dockerfile: Dockerfile.clef
    container_name: clef4
    volumes:
      - ./data/signer4/keystore:/root/.ethereum/keystore:ro
      - ./data/clef4:/root/.clef
      - ./config/rules.js:/root/rules.js:ro
    environment:
      # Sediakan password dan variabel lain yang dibutuhkan skrip expect
      CLEF_MASTER_PASSWORD: ${SIGNER4_PASSWORD}
      NETWORK_ID: ${NETWORK_ID:-2904}
    networks:
      - geth-network
    restart: unless-stopped

  signer4:
    image: ethereum/client-go:alltools-v1.13.15
    container_name: signer4
    depends_on: [clef4, bootnode1]
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/signer4:/root/.ethereum
    ports:
      - "${SIGNER4_HTTP_PORT:-8556}:8545"
      - "${SIGNER4_WS_PORT:-8557}:8546"
    command: >
      geth --datadir /root/.ethereum --networkid "${NETWORK_ID:-2904}" --syncmode full --port 30307
      --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin" --http.corsdomain "*" --http.vhosts "*"
      --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin" --ws.origins "*"
      --metrics --metrics.expensive --metrics.influxdb --metrics.influxdb.endpoint "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}" --metrics.influxdb.database "${INFLUXDB_DB}" --metrics.influxdb.username "${INFLUXDB_USER}" --metrics.influxdb.password "${INFLUXDB_PASSWORD}"
      --ethstats "signer4:${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --bootnodes "${BOOTNODE_ENODE}" --signer "http://clef4:8550" --mine --miner.etherbase "${SIGNER4_ADDRESS}"
    networks:
      - geth-network
    restart: unless-stopped

  # --- Signer Node 5 ---
  clef5:
    build:
      context: .
      dockerfile: Dockerfile.clef
    container_name: clef5
    volumes:
      - ./data/signer5/keystore:/root/.ethereum/keystore:ro
      - ./data/clef5:/root/.clef
      - ./config/rules.js:/root/rules.js:ro
    environment:
      # Sediakan password dan variabel lain yang dibutuhkan skrip expect
      CLEF_MASTER_PASSWORD: ${SIGNER5_PASSWORD}
      NETWORK_ID: ${NETWORK_ID:-2904}
    networks:
      - geth-network
    restart: unless-stopped

  signer5:
    image: ethereum/client-go:alltools-v1.13.15
    container_name: signer5
    depends_on: [clef5, bootnode1]
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/signer5:/root/.ethereum
    ports:
      - "${SIGNER5_HTTP_PORT:-8558}:8545"
      - "${SIGNER5_WS_PORT:-8559}:8546"
    command: >
      geth --datadir /root/.ethereum --networkid "${NETWORK_ID:-2904}" --syncmode full --port 30308
      --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin" --http.corsdomain "*" --http.vhosts "*"
      --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin" --ws.origins "*"
      --metrics --metrics.expensive --metrics.influxdb --metrics.influxdb.endpoint "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}" --metrics.influxdb.database "${INFLUXDB_DB}" --metrics.influxdb.username "${INFLUXDB_USER}" --metrics.influxdb.password "${INFLUXDB_PASSWORD}"
      --ethstats "signer5:${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --bootnodes "${BOOTNODE_ENODE}" --signer "http://clef5:8550" --mine --miner.etherbase "${SIGNER5_ADDRESS}"
    networks:
      - geth-network
    restart: unless-stopped

  # --- Non-Signer Node 2 ---
  nonsigner2:
    image: ethereum/client-go:alltools-v1.13.15
    container_name: nonsigner2
    depends_on: [bootnode1]
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/nonsigner2:/root/.ethereum # Chaindata
      - ./data/nonsigner2/keystore:/root/.ethereum/keystore:ro # Optional, for personal API
      - ./config/nonsigner2.pass:/root/password.txt:ro # Optional, for personal API
    ports:
      - "${NONSIGNER2_HTTP_PORT:-8562}:8545"
      - "${NONSIGNER2_WS_PORT:-8563}:8546"
    command: >
      geth --datadir /root/.ethereum --keystore /root/.ethereum/keystore --networkid "${NETWORK_ID:-2904}"
      --syncmode full --gcmode archive --port 30309
      --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin,personal" --http.corsdomain "*" --http.vhosts "*"
      --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin,personal" --ws.origins "*"
      --metrics --metrics.expensive --metrics.influxdb --metrics.influxdb.endpoint "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}" --metrics.influxdb.database "${INFLUXDB_DB}" --metrics.influxdb.username "${INFLUXDB_USER}" --metrics.influxdb.password "${INFLUXDB_PASSWORD}"
      --ethstats "nonsigner2:${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --password /root/password.txt --allow-insecure-unlock
      --bootnodes "${BOOTNODE_ENODE}"
    networks:
      - geth-network
    restart: unless-stopped

  # --- Non-Signer Node 3 ---
  nonsigner3:
    image: ethereum/client-go:alltools-v1.13.15
    container_name: nonsigner3
    depends_on: [bootnode1]
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/nonsigner3:/root/.ethereum
      - ./data/nonsigner3/keystore:/root/.ethereum/keystore:ro
      - ./config/nonsigner3.pass:/root/password.txt:ro
    ports:
      - "${NONSIGNER3_HTTP_PORT:-8564}:8545"
      - "${NONSIGNER3_WS_PORT:-8565}:8546"
    command: >
      geth --datadir /root/.ethereum --keystore /root/.ethereum/keystore --networkid "${NETWORK_ID:-2904}"
      --syncmode full --gcmode archive --port 30310
      --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin,personal" --http.corsdomain "*" --http.vhosts "*"
      --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin,personal" --ws.origins "*"
      --metrics --metrics.expensive --metrics.influxdb --metrics.influxdb.endpoint "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}" --metrics.influxdb.database "${INFLUXDB_DB}" --metrics.influxdb.username "${INFLUXDB_USER}" --metrics.influxdb.password "${INFLUXDB_PASSWORD}"
      --ethstats "nonsigner3:${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --password /root/password.txt --allow-insecure-unlock
      --bootnodes "${BOOTNODE_ENODE}"
    networks:
      - geth-network
    restart: unless-stopped

  # --- Non-Signer Node 4 ---
  nonsigner4:
    image: ethereum/client-go:alltools-v1.13.15
    container_name: nonsigner4
    depends_on: [bootnode1]
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/nonsigner4:/root/.ethereum
      - ./data/nonsigner4/keystore:/root/.ethereum/keystore:ro
      - ./config/nonsigner4.pass:/root/password.txt:ro
    ports:
      - "${NONSIGNER4_HTTP_PORT:-8566}:8545"
      - "${NONSIGNER4_WS_PORT:-8567}:8546"
    command: >
      geth --datadir /root/.ethereum --keystore /root/.ethereum/keystore --networkid "${NETWORK_ID:-2904}"
      --syncmode full --gcmode archive --port 30311
      --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin,personal" --http.corsdomain "*" --http.vhosts "*"
      --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin,personal" --ws.origins "*"
      --metrics --metrics.expensive --metrics.influxdb --metrics.influxdb.endpoint "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}" --metrics.influxdb.database "${INFLUXDB_DB}" --metrics.influxdb.username "${INFLUXDB_USER}" --metrics.influxdb.password "${INFLUXDB_PASSWORD}"
      --ethstats "nonsigner4:${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --password /root/password.txt --allow-insecure-unlock
      --bootnodes "${BOOTNODE_ENODE}"
    networks:
      - geth-network
    restart: unless-stopped

  # --- Non-Signer Node 5 ---
  nonsigner5:
    image: ethereum/client-go:alltools-v1.13.15
    container_name: nonsigner5
    depends_on: [bootnode1]
    volumes:
      - ./config/genesis.json:/config/genesis.json:ro
      - ./data/nonsigner5:/root/.ethereum
      - ./data/nonsigner5/keystore:/root/.ethereum/keystore:ro
      - ./config/nonsigner5.pass:/root/password.txt:ro
    ports:
      - "${NONSIGNER5_HTTP_PORT:-8568}:8545"
      - "${NONSIGNER5_WS_PORT:-8569}:8546"
    command: >
      geth --datadir /root/.ethereum --keystore /root/.ethereum/keystore --networkid "${NETWORK_ID:-2904}"
      --syncmode full --gcmode archive --port 30312
      --http --http.addr "0.0.0.0" --http.port 8545 --http.api "eth,net,web3,clique,admin,personal" --http.corsdomain "*" --http.vhosts "*"
      --ws --ws.addr "0.0.0.0" --ws.port 8546 --ws.api "eth,net,web3,clique,admin,personal" --ws.origins "*"
      --metrics --metrics.expensive --metrics.influxdb --metrics.influxdb.endpoint "http://${INFLUXDB_HOST}:${INFLUXDB_PORT}" --metrics.influxdb.database "${INFLUXDB_DB}" --metrics.influxdb.username "${INFLUXDB_USER}" --metrics.influxdb.password "${INFLUXDB_PASSWORD}"
      --ethstats "nonsigner5:${ETHSTATS_WS_SECRET}@ethstats-server:3000"
      --password /root/password.txt --allow-insecure-unlock
      --bootnodes "${BOOTNODE_ENODE}"
    networks:
      - geth-network
    restart: unless-stopped

  # --- Monitoring Stack ---
  ethstats-server:
    build:
      context: https://github.com/goerli/ethstats-server.git # Build dari Goerli fork
    container_name: ethstats-server
    environment:
      WS_SECRET: "${ETHSTATS_WS_SECRET}"
      # PORT, RPC_HOST, RPC_PORT diatur oleh entrypoint repo
    ports:
      - "${ETHSTATS_PORT:-8080}:3000" # Ekspos port internal 3000 ke host
    networks:
      - geth-network
    restart: unless-stopped

  influxdb:
    image: influxdb:1.8
    container_name: influxdb
    volumes:
      - influxdb_data:/var/lib/influxdb
    environment:
      INFLUXDB_DB: "${INFLUXDB_DB}"
      INFLUXDB_ADMIN_USER: "${INFLUXDB_USER}"
      INFLUXDB_ADMIN_PASSWORD: "${INFLUXDB_PASSWORD}"
      INFLUXDB_HTTP_AUTH_ENABLED: "true"
      INFLUXDB_USER: "${INFLUXDB_USER}"
      INFLUXDB_USER_PASSWORD: "${INFLUXDB_PASSWORD}"
    networks:
      - geth-network
    restart: unless-stopped

  grafana:
    image: grafana/grafana-oss:latest
    container_name: grafana
    depends_on:
      - influxdb
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "${GRAFANA_PORT:-3000}:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: "${GRAFANA_ADMIN_PASSWORD}" # Ambil dari .env
    networks:
      - geth-network
    restart: unless-stopped

# --- Network Definition ---
networks:
  geth-network:
    driver: bridge
    name: ${COMPOSE_PROJECT_NAME}_default_net # Beri nama jaringan agar lebih mudah diidentifikasi

volumes:
  grafana_data: {}
  influxdb_data: {}
```


## **Bagian 7: Mendapatkan Enode Bootnode & Menjalankan Jaringan**

Langkah ini tetap sama seperti sebelumnya:

1. **Jalankan Bootnode Saja:**
``` bash
docker-compose up -d bootnode1
```
Tunggu beberapa detik.
2. **Dapatkan Enode Bootnode:**
``` bash
docker-compose exec bootnode1 geth attach --exec admin.nodeInfo.enode
```
Salin enode URL yang muncul (string di dalam tanda kutip).
3. **Hentikan Bootnode Sementara:**
``` bash
docker-compose down
```

4. **Perbarui File .env:**
    - Buka file .env.
    - Tempelkan enode URL ke variabel BOOTNODE_ENODE=.
    - **Sangat Penting:** Ganti alamat IP (misal 172.x.x.x) di dalam enode URL dengan nama service: bootnode1.
        - Contoh: enode://abcd...@172.20.0.5:30303 -> enode://abcd...@bootnode1:30303
    - Simpan file .env.
5. **Jalankan Seluruh Jaringan:**
``` bash
docker-compose up -d build
```
Proses ini mungkin memakan waktu, terutama saat membangun image pertama kali.

## **Bagian 8: Verifikasi Jaringan**

Tunggu beberapa menit agar node saling terhubung dan blok mulai diproduksi.

1. **Cek Log Container:**
    - Lihat log semua service: docker-compose logs -f
    - Lihat log spesifik, misal signer1: docker-compose logs -f signer1
    - Lihat log Clef, misal clef1: docker-compose logs -f clef1 (Anda seharusnya melihat 'Op approved' untuk penandatanganan).
    - Lihat log Ethstats: docker-compose logs -f ethstats-server  
        Tekan Ctrl+C untuk keluar dari mode follow log.
2. **Akses Ethstats:** Buka browser ke http://localhost:${ETHSTATS_PORT} (misal: http://localhost:8080). Node Anda seharusnya mulai muncul di dashboard.
3. **Akses Grafana & Konfigurasi:**
    - Buka browser ke http://localhost:${GRAFANA_PORT} (misal: http://localhost:3000).
    - Login dengan admin / password Grafana yang Anda set di .env. Ganti password saat diminta.
    - **Tambah Datasource InfluxDB:**
        - Configuration (Gear icon) > Data Sources > Add data source > InfluxDB.
        - **Name:** InfluxDB_Geth (atau nama pilihan Anda).
        - **URL:** http://influxdb:8086 (gunakan nama service).
        - **Database:** geth_metrics (sesuai .env).
        - **User:** geth_user (sesuai .env).
        - **Password:** Password InfluxDB Anda dari .env.
        - **HTTP Method:** POST.
        - Klik "Save & Test". Seharusnya berhasil.
    - **Impor Dashboard Geth:**
        - Dashboards (Square icon) > Browse > New > Import.
        - Masukkan ID 13136 di "Import via grafana.com" > Load.
        - Pilih datasource InfluxDB_Geth yang baru dibuat > Import.
        - Anda akan melihat metrik Geth (memerlukan waktu untuk terisi).
4. **Interaksi via Konsol Geth:**  
    Hubungkan ke salah satu node (misalnya bootnode1 atau nonsigner2):
``` bash
docker-compose exec bootnode1 geth attach
```
Jalankan perintah di konsol Geth:

    - admin.peers.length (Harus mendekati 9 setelah beberapa saat).
    - eth.blockNumber (Harus bertambah setiap 15 detik).
    - clique.getSigners() (Harus menampilkan 5 alamat signer dari genesis).
    - net.peerCount

**Bagian 9: Mengelola Jaringan (Contoh: Voting Signer)**

Untuk menambah/menghapus signer setelah jaringan berjalan:

1. Hubungkan ke mayoritas (>50%) node **signer** aktif:
``` bash
docker-compose exec signer1 geth attach 
# (Buka terminal lain dan hubungkan ke signer2, signer3)
```
    
2. Dari setiap konsol signer, jalankan clique.propose():
```bash
# Menambah signer baru 
clique.propose("0xAlamatSignerBaru", true)  
# Menghapus signer lama 
clique.propose("0xAlamatSignerLama", false)
```
    
3. Perubahan akan efektif setelah blok epoch berikutnya.

**Bagian 10: Menghentikan Jaringan**

- Untuk menghentikan semua container:
``` bash
docker-compose down
```

- Untuk menghentikan dan **menghapus semua volume data** (termasuk chaindata, data Clef, data monitoring - **GUNAKAN DENGAN HATI-HATI!**):
    
``` bash
docker-compose down -v
```

**Penutup**

Selamat! Anda telah berhasil melalui proses konfigurasi dan deployment jaringan blockchain private Geth Clique PoA yang canggih menggunakan Docker, Clef sebagai external signer, dan tumpukan monitoring. Arsitektur ini memberikan keamanan yang lebih baik dibandingkan metode unlock akun langsung dan menyediakan fondasi yang solid untuk pengembangan dan pengujian DApp, serta benchmarking.

Langkah selanjutnya bisa berupa:
- Mendeploy dan menguji smart contract.
- Melakukan benchmark kinerja menggunakan Hyperledger Caliper.
- Mengeksplorasi lebih lanjut fitur monitoring atau manajemen jaringan.
- Men-deploy arsitektur ini ke lingkungan multi-VPS.

Semoga tutorial yang komprehensif ini bermanfaat dan menjawab kebutuhan proyek Anda!