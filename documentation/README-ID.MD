# **Toolkit Jaringan Private Blockchain Geth Clique PoA Otomatis**

### (v1.13.15) dengan Docker, Clef External Signer, dan Monitoring Terintegrasi

## **Pendahuluan**

Selamat datang di repositori untuk membangun jaringan blockchain Ethereum privat menggunakan mekanisme konsensus Proof of Authority (PoA) Clique. Proyek ini menyediakan serangkaian skrip untuk **sepenuhnya mengotomatiskan** proses pembuatan, konfigurasi, dan pengelolaan jaringan. Tujuannya adalah untuk menghilangkan langkah-langkah manual yang rumit dan rawan kesalahan, memungkinkan Anda untuk fokus pada pengembangan dan pengujian.

Arsitektur ini modern dan aman, dengan **memisahkan penandatangan (signer) dari node Geth** menggunakan **Clef** sebagai _external signer_. Seluruh infrastruktur, termasuk jumlah node yang **dinamis**, instance Clef, dan tumpukan monitoring (Ethstats, InfluxDB, Grafana), diorkestrasi secara otomatis menggunakan **Docker dan Docker Compose**.

**✨ Keunggulan Utama:**

- **Setup Sepenuhnya Otomatis:** Cukup satu perintah untuk mempersiapkan seluruh jaringan.
- **Konfigurasi Dinamis:** Ubah jumlah _signer_ dan _non-signer_ dengan mudah melalui satu file konfigurasi (`config.sh`).
- **Aman sejak Awal:** Implementasi Clef dengan aturan penandatanganan yang ketat (`rules.js`) untuk melindungi akun validator.
- **Monitoring Terintegrasi:** Dasbor Ethstats dan Grafana siap pakai secara otomatis.
- **Reproducibility & Portability:** Berkat Docker, jaringan yang sama dapat dibuat di mana saja dengan hasil yang konsisten.

**Target Audiens:** Pengembang atau _DevOps Engineer_ tingkat menengah (intermediate) yang memiliki pemahaman dasar tentang:

- Konsep Blockchain dan Ethereum (PoA, Node, Akun).
- Penggunaan baris perintah (CLI) Linux.
- Dasar-dasar Docker dan Docker Compose.

**Teknologi yang Digunakan:**

- **Geth:** `1.13.15` (via image Docker `ethereum/client-go:alltools-v1.13.15`)
- **Konsensus:** Clique Proof of Authority (PoA)
- **External Signer:** Clef `1.13.15`
- **Otomatisasi:** Bash, Expect, `jq`
- **Orkestrasi:** Docker & Docker Compose
- **Monitoring:** Ethstats, InfluxDB v1.8, Grafana

## **Arsitektur Jaringan**

Sistem ini secara dinamis akan membuat arsitektur berikut:

- **Node Geth:**
  - **Node Signer (Jumlah Dinamis):** Bertugas memvalidasi blok baru. Setiap _signer_ didampingi oleh instance Clef-nya sendiri.
  - **Node Non-Signer (Jumlah Dinamis):** Bertindak sebagai node RPC biasa. Node `nonsigner1` secara otomatis ditetapkan sebagai **Bootnode** utama.
- **Instance Clef:** Satu instance untuk setiap node _signer_, berjalan dalam kontainer terpisah untuk isolasi kunci.
- **Layanan Monitoring:** Ethstats, InfluxDB, dan Grafana, masing-masing dalam kontainer terpisah.
- Semua komponen terhubung dalam jaringan Docker internal yang sama untuk komunikasi yang lancar.

## **Panduan Penggunaan Cepat**

Lupakan proses manual yang panjang. Berikut cara cepat untuk menjalankan jaringan Anda.

### **Langkah 1: Prasyarat**

Pastikan perangkat lunak berikut telah terinstal di sistem host Anda (misalnya Ubuntu atau WSL):

1.  **Docker Engine** (v24.0+)
2.  **Docker Compose** (mendukung Compose spec v3.7+)
3.  **Git**
4.  **jq** (Wajib, untuk memproses JSON di skrip): `sudo apt-get install jq`
5.  **(Opsional) curl:** Berguna untuk pengujian.

### **Langkah 2: Clone Repositori**

```bash
git clone https://github.com/Maulana-anjari/blockchain-poa-geth.git
cd blockchain-poa-geth
```

### **Langkah 3: Konfigurasi Jaringan**

Ini adalah **satu-satunya langkah konfigurasi manual** yang perlu Anda lakukan. Buka dan edit file `config.sh`.

```bash
# File: config.sh

# --- Konfigurasi Jumlah Node ---
# Atur berapa banyak node signer dan non-signer yang Anda inginkan.
export NUM_SIGNERS=3
export NUM_NONSIGNERS=2

# --- Konfigurasi Jaringan & Rahasia ---
export NETWORK_ID=477748
export COMPOSE_PROJECT_NAME="geth_poa_dynamic"

# Gunakan prefix untuk password agar mudah ditebak namun unik per node
export SIGNER_PASS_PREFIX="pass_signer_"
export NONSIGNER_PASS_PREFIX="pass_nonsigner_"

# Ganti dengan rahasia Anda sendiri untuk Ethstats, InfluxDB, dan Grafana
export ETHSTATS_WS_SECRET="YourSuperSecretEthstatsStringHere"
export INFLUXDB_PASSWORD="YourStrongInfluxDBPassword"
export GRAFANA_ADMIN_PASSWORD="YourStrongGrafanaAdminPassword"
# ... (konfigurasi lain bisa dibiarkan default)
```
> 💡 **Catatan:** Samakan penamaan PoA dengan topologi PoS dengan mengisi `POA_SIGNER_LABELS` dan `POA_NONSIGNER_LABELS` di `.env`; label tersebut otomatis dipakai untuk nama kontainer dan ID Ethstats sesuai urutan.


### **Langkah 4: Jalankan Skrip Setup Otomatis**

Jalankan satu perintah ini. Skrip ini akan melakukan semua pekerjaan berat untuk Anda.

```bash
chmod +x ./**/*.sh
./setup-network.sh
```

**Apa yang dilakukan skrip ini?**

- Membersihkan setup lama (jika ada).
- Membuat semua direktori yang diperlukan.
- Membuat akun Ethereum dan password untuk setiap node.
- Membuat file `.env` dari konfigurasi Anda.
- **Secara interaktif** memandu Anda untuk inisialisasi Clef bagi setiap _signer_. Anda akan diminta memasukkan password beberapa kali untuk setiap _signer_.
- Membuat `genesis.json` secara dinamis dengan alamat _signer_ dan alokasi dana yang benar.
- Membuat `docker-compose.yml` secara dinamis sesuai jumlah node Anda.
- Menjalankan _bootnode_ sementara untuk mendapatkan `enode`-nya, lalu menyuntikkannya ke konfigurasi node lain.

### **Langkah 5: Jalankan Jaringan**

Setelah skrip setup selesai, hidupkan seluruh jaringan dengan Docker Compose.

```bash
# --build diperlukan saat pertama kali atau jika Dockerfile.clef berubah
docker-compose up -d --build
```

Jaringan Anda sekarang berjalan! Tunggu beberapa menit hingga semua node saling terhubung dan mulai memproduksi blok.

## **Verifikasi dan Pengelolaan Jaringan**

#### **Melihat Log**

Gunakan perintah `docker-compose logs` untuk memantau aktivitas:

```bash
# Melihat log dari semua layanan (tekan Ctrl+C untuk keluar)
docker-compose logs -f

# Melihat log dari layanan spesifik (misal, signer1 atau clef1)
docker-compose logs -f signer1
docker-compose logs -f clef1
```

Di log `clef1`, Anda akan melihat pesan `Approved clique header signing for block...` yang menandakan otomasi berjalan.

#### **Mengakses Dasbor Monitoring**

- **Ethstats**: Buka `http://localhost:8080` di browser Anda.
- **Grafana**: Buka `http://localhost:3000` di browser Anda.
  - Login dengan `admin` / password yang Anda atur di `config.sh`.
  - Anda perlu menambahkan _datasource_ InfluxDB dan mengimpor dasbor Geth (ID: `13136`) saat pertama kali menggunakan.

#### **Interaksi via Konsol Geth**

Hubungkan ke konsol Geth dari node mana pun untuk menjalankan perintah:

```bash
# Hubungkan ke bootnode (nonsigner1)
docker-compose exec nonsigner1 geth attach
```

Di dalam konsol Geth:

```javascript
> eth.blockNumber          // Harus bertambah setiap ~15 detik
> net.peerCount            // Harus mendekati (Total Node - 1)
> clique.getSigners()      // Harus menampilkan daftar alamat signer Anda
```

## **Menghentikan dan Membersihkan Jaringan**

#### **Menghentikan Jaringan**

Untuk menghentikan semua kontainer tanpa menghapus data:

```bash
docker-compose down
```

#### **Menghancurkan Jaringan (Cleanup Total)**

Untuk menghentikan kontainer **DAN MENGHAPUS SEMUA DATA** (chaindata, konfigurasi, dll.) untuk memulai dari awal, gunakan skrip `destroy-network.sh`:

```bash
./destroy-network.sh
```

## **Bagaimana Otomasi Bekerja (Detail Teknis)**

Bagi yang penasaran, keajaiban terjadi berkat skrip-skrip berikut:

- `config.sh`: Pusat kendali untuk semua variabel.
- `setup-network.sh`: Orkestrator utama yang menjalankan semua tugas persiapan.
- `destroy-network.sh`: Membersihkan semua artefak yang dihasilkan.
- `generate-genesis.sh`: Menggunakan `jq` dan template untuk membuat `genesis.json` yang valid secara dinamis.
- `generate-compose.sh`: Menggunakan perulangan `bash` untuk membuat file `docker-compose.yml` dengan jumlah layanan yang tepat.
- `Dockerfile.clef`: Membuat image Docker khusus untuk Clef yang menyertakan `expect`.
- `start-clef.sh`: Skrip `expect` yang secara otomatis menangani prompt interaktif dari Clef saat startup.
- `rules.js`: File aturan JavaScript yang menginstruksikan Clef untuk hanya menyetujui penandatanganan blok PoA.

---

Selamat! Anda sekarang memiliki toolkit yang kuat untuk bereksperimen dengan jaringan Ethereum PoA. Arsitektur ini menyediakan fondasi yang solid untuk pengembangan dan pengujian DApp, serta _benchmarking_.
