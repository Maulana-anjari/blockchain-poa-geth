Oke, mari kita bedah file docker-compose.yml Anda baris per baris dan jelaskan fungsinya seperti dokumentasi. File ini mendefinisikan multi-container Docker application yang bertujuan untuk menjalankan jaringan blockchain Ethereum privat berbasis Proof-of-Authority (Clique) lengkap dengan node penandatangan (signer), node non-penandatangan, bootnode, dan tumpukan pemantauan (monitoring stack).

Struktur Umum File docker-compose.yml

version: '3.8': Menentukan versi sintaks file Docker Compose yang digunakan. Versi 3.8 adalah versi yang relatif modern dan mendukung fitur-fitur terbaru.

services: Bagian utama yang mendefinisikan setiap kontainer (disebut service) yang akan dijalankan. Setiap kunci di bawah services adalah nama logis dari service tersebut (misalnya, bootnode1, clef1, signer1, dll.).

networks: Mendefinisikan jaringan kustom yang akan digunakan oleh service-service ini agar dapat berkomunikasi satu sama lain.

volumes: Mendefinisikan named volumes yang digunakan untuk menyimpan data secara persisten di luar siklus hidup kontainer.

Penjelasan Detail per Service

1. bootnode1 (Bootnode / Non-Signer 1)

Tujuan:

Berfungsi sebagai Bootnode: Titik masuk utama bagi node lain di jaringan untuk saling menemukan (peer discovery). Node lain akan menghubunginya untuk mendapatkan daftar node aktif lainnya.

Berfungsi sebagai Non-Signer Node: Node ini menyinkronkan blockchain dan dapat melayani permintaan RPC, tetapi tidak ikut serta dalam pembuatan blok baru (signing).

image: ethereum/client-go:alltools-v1.13.15: Menggunakan image Docker resmi Go Ethereum (Geth) versi 1.13.15 yang berisi semua alat Geth.

container_name: bootnode1: Memberikan nama spesifik bootnode1 pada kontainer yang berjalan, bukan nama acak yang dibuat Docker Compose.

volumes:

./config/genesis.json:/config/genesis.json:ro: Memasang file genesis.json dari direktori ./config di host ke /config/genesis.json di dalam kontainer. :ro berarti read-only (hanya baca). File Genesis mendefinisikan blok pertama dan konfigurasi awal blockchain.

./data/bootnode1:/root/.ethereum: Memasang direktori ./data/bootnode1 dari host ke /root/.ethereum di kontainer. Ini adalah direktori data default Geth, digunakan untuk menyimpan data blockchain (chaindata), kunci node (nodekey), dan data lainnya. Ini memastikan data blockchain dan identitas node (nodekey) tetap ada meskipun kontainer dihentikan dan dimulai ulang.

./data/nonsigner1/keystore:/root/.ethereum/keystore:ro: Memasang direktori keystore (berisi kunci akun Ethereum) dari host ke dalam kontainer (read-only). Diperlukan jika Anda ingin menggunakan API personal untuk mengirim transaksi atau mengelola akun dari node ini.

./config/nonsigner1.pass:/root/password.txt:ro: Memasang file password yang sesuai dengan akun di keystore (read-only). Juga diperlukan untuk API personal.

ports:

"${BOOTNODE1_P2P_PORT:-30303}:${BOOTNODE1_P2P_PORT:-30303}/tcp" dan .../udp: Memetakan port P2P (Peer-to-Peer) Geth di host ke port yang sama di kontainer. Port ini digunakan oleh node Geth lain untuk berkomunikasi (sinkronisasi, propagasi transaksi/blok). Menggunakan variabel lingkungan (${BOOTNODE1_P2P_PORT}) dengan nilai default (:-30303) memungkinkan fleksibilitas konfigurasi via file .env. TCP dan UDP diperlukan untuk penemuan dan komunikasi node.

"${BOOTNODE1_HTTP_PORT:-8545}:8545": Memetakan port HTTP RPC Geth di host ke port 8545 di kontainer. Digunakan untuk interaksi via JSON-RPC over HTTP.

"${BOOTNODE1_WS_PORT:-8546}:8546": Memetakan port WebSocket RPC Geth di host ke port 8546 di kontainer. Alternatif RPC yang lebih persisten.

command: Perintah yang dijalankan saat kontainer dimulai. Ini adalah perintah geth dengan banyak flags (opsi):

--nodekey /root/.ethereum/geth/nodekey: Menentukan lokasi file kunci node (identitas P2P unik). Geth akan membuatnya jika belum ada di volume yang dipasang.

--datadir /root/.ethereum: Menentukan direktori data utama.

--keystore /root/.ethereum/keystore: Menentukan lokasi keystore (untuk API personal).

--networkid "${NETWORK_ID:-2904}": ID unik jaringan privat Anda. Semua node harus menggunakan ID yang sama. Mengambil dari env var NETWORK_ID atau default ke 2904.

--syncmode full: Mode sinkronisasi standar (download semua blok dan eksekusi transaksi).

--gcmode archive: Mode garbage collection. archive menyimpan semua state historis, berguna untuk debugging atau analisis, tapi memakan banyak disk.

--port "${BOOTNODE1_P2P_PORT:-30303}": Menentukan port P2P internal yang akan didengarkan Geth.

--http ...: Mengaktifkan server HTTP RPC, mendengarkan di semua interface (0.0.0.0) pada port 8545, mengaktifkan API eth,net,web3,clique,admin,personal, mengizinkan koneksi dari domain manapun (*), dan menerima semua host virtual (*).

--ws ...: Mengaktifkan server WebSocket RPC dengan konfigurasi serupa.

--metrics ...: Mengaktifkan pengumpulan metrik dan mengirimkannya ke InfluxDB.

--metrics.influxdb.endpoint ...: URL server InfluxDB (mengambil detail dari env vars).

--metrics.influxdb.database ..., --metrics.influxdb.username ..., --metrics.influxdb.password ...: Detail koneksi InfluxDB (dari env vars).

--ethstats "bootnode1:${ETHSTATS_WS_SECRET}@ethstats-server:3000": Mengirim statistik node ke server ethstats-server (nama service Docker) pada port 3000, menggunakan nama bootnode1 dan secret dari env var ETHSTATS_WS_SECRET.

--password /root/password.txt: Menyediakan path ke file password untuk membuka kunci akun (jika API personal digunakan).

--allow-insecure-unlock: Mengizinkan pembukaan kunci akun melalui RPC non-localhost (diperlukan jika Anda berinteraksi dengan API personal dari luar kontainer). Peringatan Keamanan: Gunakan ini hanya di lingkungan pengembangan/privat yang terpercaya.

networks: - geth-network: Menghubungkan service ini ke jaringan geth-network.

restart: unless-stopped: Kontainer akan otomatis restart jika berhenti karena error, kecuali jika dihentikan secara manual.

2. clef1 (dan clef2 hingga clef5)

Tujuan: Berfungsi sebagai Signer Eksternal untuk node Geth signerX. Clef menyimpan kunci privat dan menangani permintaan penandatanganan (misalnya, menandatangani blok atau transaksi) dari Geth tanpa mengekspos kunci privat ke proses Geth itu sendiri. Ini meningkatkan keamanan.

build:

context: .: Menunjukkan bahwa build context (file yang dapat digunakan saat membangun image) adalah direktori saat ini (tempat docker-compose.yml berada).

dockerfile: Dockerfile.clef: Menentukan bahwa image untuk service ini harus dibangun menggunakan instruksi dalam file Dockerfile.clef yang ada di direktori saat ini. Ini berarti Anda memiliki file Dockerfile.clef kustom.

container_name: clefX: Nama kontainer yang spesifik.

volumes:

./data/signerX/keystore:/root/.ethereum/keystore:ro: Memasang keystore yang berisi kunci signer (read-only). Clef perlu membaca kunci ini.

./data/clefX:/root/.clef: Memasang direktori data Clef. Ini menyimpan konfigurasi Clef, masterseed, credentials, dll., secara persisten.

./config/rules.js:/root/rules.js:ro: Memasang file aturan (rules) Javascript untuk Clef (read-only). File ini mendefinisikan kebijakan kapan Clef boleh atau tidak boleh menandatangani permintaan tertentu secara otomatis atau manual.

environment:

CLEF_MASTER_PASSWORD: ${SIGNERX_PASSWORD}: Menyediakan password utama Clef (atau password akun yang relevan) sebagai variabel lingkungan. Kemungkinan besar digunakan oleh skrip di dalam Dockerfile.clef (misalnya, skrip expect) untuk mengotomatisasi input password saat Clef dimulai.

NETWORK_ID: ${NETWORK_ID:-2904}: Menyediakan Network ID ke dalam environment Clef, mungkin diperlukan oleh skrip startup atau konfigurasi Clef.

command: Penting: Dalam file docker-compose.yml Anda yang berfungsi, tidak ada command eksplisit untuk clefX. Ini berarti perintah untuk menjalankan Clef (kemungkinan besar clef --keystore ... --configdir ... --chainid ... --rules ... dst.) didefinisikan di dalam Dockerfile.clef (menggunakan CMD atau ENTRYPOINT). Skrip di dalam Dockerfile tersebut kemungkinan besar menggunakan variabel environment yang disediakan untuk berjalan. (Berbeda dengan file documentation-docker-compose.yml Anda yang mencoba menjalankan clef langsung di command).

networks: - geth-network: Terhubung ke jaringan yang sama.

restart: unless-stopped: Kebijakan restart.

3. signer1 (dan signer2 hingga signer5)

Tujuan: Node Geth yang bertindak sebagai Validator/Signer dalam jaringan Clique PoA. Node ini secara aktif membuat dan menandatangani blok baru. Penandatanganan sebenarnya didelegasikan ke service clefX yang sesuai.

image: ethereum/client-go:alltools-v1.13.15: Menggunakan image Geth standar.

container_name: signerX: Nama kontainer yang spesifik.

depends_on:

clefX: Memastikan kontainer clefX dimulai sebelum kontainer signerX ini, karena signerX membutuhkan Clef untuk berfungsi.

bootnode1: Memastikan bootnode1 dimulai terlebih dahulu, kemungkinan untuk memfasilitasi penemuan peer awal.

volumes:

./config/genesis.json:/config/genesis.json:ro: Memasang file genesis (sama seperti bootnode).

./data/signerX:/root/.ethereum: Memasang direktori data Geth untuk node signer ini. Menyimpan chaindata. Perhatikan: Tidak perlu memasang keystore di sini karena kunci dikelola oleh Clef.

ports:

"${SIGNERX_HTTP_PORT:-8550}:8545": Memetakan port HTTP RPC Geth (misalnya, default 8550 di host) ke port 8545 di kontainer. Port host berbeda untuk setiap signer agar tidak bentrok.

"${SIGNERX_WS_PORT:-8551}:8546": Memetakan port WebSocket RPC Geth (misalnya, default 8551 di host) ke port 8546 di kontainer.

command: Perintah geth untuk node signer:

--datadir /root/.ethereum: Direktori data.

--networkid "${NETWORK_ID:-2904}": ID Jaringan.

--syncmode full: Mode sinkronisasi.

--port 3030X: Menentukan port P2P internal yang unik untuk setiap signer (misal: 30304, 30305, ...). Port ini tidak perlu diekspos ke host karena komunikasi P2P terjadi di dalam jaringan Docker geth-network.

--http ...: Mengaktifkan HTTP RPC. Perhatikan API yang diaktifkan (eth,net,web3,clique,admin) tidak termasuk personal karena penandatanganan transaksi didelegasikan ke Clef.

--ws ...: Mengaktifkan WebSocket RPC dengan API yang sama.

--metrics ..., --metrics.influxdb...: Konfigurasi metrik ke InfluxDB (sama seperti bootnode).

--ethstats "signerX:${ETHSTATS_WS_SECRET}@ethstats-server:3000": Mengirim statistik ke ethstats-server.

--bootnodes "${BOOTNODE_ENODE}": Memberitahu Geth alamat enode dari bootnode1 untuk memulai penemuan peer. Nilai ${BOOTNODE_ENODE} harus disediakan di file .env.

--signer "http://clefX:8550": Kunci: Memberitahu Geth untuk menggunakan Clef sebagai signer eksternal. Geth akan mengirim permintaan penandatanganan ke URL internal http://clefX:8550 (nama service Clef dan port default internal Clef).

--mine: Mengaktifkan node ini untuk mencoba membuat blok baru (menjadi miner atau signer dalam konteks PoA).

--miner.etherbase "${SIGNERX_ADDRESS}": Menentukan alamat Ethereum yang akan digunakan untuk menandatangani blok. Alamat ini harus merupakan salah satu akun yang dikelola oleh service clefX yang terhubung dan nilainya diambil dari env var ${SIGNERX_ADDRESS}.

networks: - geth-network: Terhubung ke jaringan.

restart: unless-stopped: Kebijakan restart.

4. nonsigner2 (dan nonsigner3 hingga nonsigner5)

Tujuan: Node Geth penuh (Full Node) yang berpartisipasi dalam jaringan, menyinkronkan blockchain, dan dapat melayani permintaan RPC, tetapi tidak menandatangani blok baru. Berguna sebagai titik akses RPC untuk aplikasi atau pengguna akhir.

image: ethereum/client-go:alltools-v1.13.15: Image Geth standar.

container_name: nonsignerX: Nama kontainer spesifik.

depends_on: [bootnode1]: Memastikan bootnode sudah berjalan.

volumes: Mirip dengan bootnode1, termasuk pemasangan keystore dan password opsional jika API personal ingin diaktifkan pada node ini.

./config/genesis.json:/config/genesis.json:ro

./data/nonsignerX:/root/.ethereum

./data/nonsignerX/keystore:/root/.ethereum/keystore:ro (Opsional)

./config/nonsignerX.pass:/root/password.txt:ro (Opsional)

ports: Memetakan port HTTP dan WS RPC ke port unik di host (misalnya, 8562, 8563, dst.).

"${NONSIGNERX_HTTP_PORT:-8562}:8545"

"${NONSIGNERX_WS_PORT:-8563}:8546"

command: Perintah geth untuk node non-signer:

Flags umum: --datadir, --keystore, --networkid, --syncmode full, --gcmode archive.

--port 303XX: Port P2P internal yang unik (misal: 30309, 30310, ...).

--http ..., --ws ...: Mengaktifkan RPC. API personal disertakan di sini, mengindikasikan node ini mungkin digunakan untuk mengirim transaksi atas nama akun yang kuncinya dipasang di volume keystore.

--metrics ..., --metrics.influxdb...: Konfigurasi metrik.

--ethstats ...: Mengirim statistik.

--password /root/password.txt, --allow-insecure-unlock: Diperlukan jika API personal digunakan.

--bootnodes "${BOOTNODE_ENODE}": Menunjuk ke bootnode.

Perhatikan: Tidak ada flags --mine, --signer, atau --miner.etherbase karena ini bukan node signer.

networks: - geth-network: Terhubung ke jaringan.

restart: unless-stopped: Kebijakan restart.

5. ethstats-server (Monitoring)

Tujuan: Backend untuk dasbor Ethstats. Menerima data dari node Geth melalui WebSocket dan menyajikannya ke frontend (yang biasanya diakses melalui browser).

build: context: https://github.com/goerli/ethstats-server.git: Membangun image langsung dari repositori GitHub goerli/ethstats-server. Ini adalah fork populer dari server Ethstats asli.

container_name: ethstats-server: Nama kontainer.

environment: WS_SECRET: "${ETHSTATS_WS_SECRET}": Mengatur secret WebSocket yang harus cocok dengan yang digunakan di flag --ethstats pada node Geth.

ports: "${ETHSTATS_PORT:-8080}:3000": Memetakan port internal server Ethstats (3000) ke port di host (default 8080) yang bisa diakses dari luar.

networks: - geth-network: Terhubung ke jaringan agar node Geth bisa mengirim data padanya.

restart: unless-stopped: Kebijakan restart.

6. influxdb (Monitoring)

Tujuan: Database Time-Series yang digunakan untuk menyimpan data metrik yang dikirim oleh node Geth (via flag --metrics).

image: influxdb:1.8: Menggunakan image InfluxDB versi 1.8.

container_name: influxdb: Nama kontainer.

volumes: - influxdb_data:/var/lib/influxdb: Memasang named volume influxdb_data ke direktori data InfluxDB. Ini memastikan data metrik tetap ada meskipun kontainer dihapus dan dibuat ulang.

environment: Mengatur variabel lingkungan untuk mengkonfigurasi InfluxDB saat pertama kali dijalankan:

INFLUXDB_DB: Nama database yang akan dibuat (dari env var).

INFLUXDB_ADMIN_USER, INFLUXDB_ADMIN_PASSWORD: Kredensial admin InfluxDB (dari env vars).

INFLUXDB_HTTP_AUTH_ENABLED: "true": Mengaktifkan autentikasi HTTP.

INFLUXDB_USER, INFLUXDB_USER_PASSWORD: Membuat pengguna non-admin dengan password (di sini sama dengan admin, dari env vars) yang akan digunakan oleh Geth dan Grafana untuk berinteraksi dengan database.

networks: - geth-network: Terhubung ke jaringan agar Geth dan Grafana bisa mengaksesnya.

restart: unless-stopped: Kebijakan restart.

7. grafana (Monitoring)

Tujuan: Alat visualisasi data. Digunakan untuk membuat dasbor yang menampilkan metrik dari InfluxDB dalam bentuk grafik dan bagan yang mudah dibaca.

image: grafana/grafana-oss:latest: Menggunakan image Grafana Open Source versi terbaru.

container_name: grafana: Nama kontainer.

depends_on: - influxdb: Memastikan InfluxDB dimulai terlebih dahulu, karena Grafana perlu terhubung ke sana sebagai sumber data.

volumes: - grafana_data:/var/lib/grafana: Memasang named volume grafana_data untuk menyimpan konfigurasi Grafana, dasbor yang dibuat, plugin, dll., secara persisten.

ports: - "${GRAFANA_PORT:-3000}:3000": Memetakan port web UI Grafana internal (3000) ke port di host (default 3000). Ini adalah port yang Anda akses di browser.

environment:

GF_SECURITY_ADMIN_USER: admin: Mengatur username admin Grafana.

GF_SECURITY_ADMIN_PASSWORD: "${GRAFANA_ADMIN_PASSWORD}": Mengatur password admin Grafana (diambil dari env var).

networks: - geth-network: Terhubung ke jaringan untuk mengakses InfluxDB.

restart: unless-stopped: Kebijakan restart.

Definisi Network dan Volume

networks: geth-network::

driver: bridge: Menggunakan driver jaringan bridge default Docker, yang menciptakan jaringan terisolasi untuk kontainer yang terhubung.

name: ${COMPOSE_PROJECT_NAME}_default_net: Memberikan nama spesifik pada jaringan Docker yang dibuat. ${COMPOSE_PROJECT_NAME} biasanya adalah nama direktori tempat file docker-compose.yml berada. Ini membantu mengidentifikasi jaringan jika Anda memiliki beberapa proyek Compose.

volumes::

grafana_data: {}: Mendeklarasikan named volume bernama grafana_data. Docker akan mengelola volume ini. {} berarti menggunakan konfigurasi default.

influxdb_data: {}: Mendeklarasikan named volume bernama influxdb_data.

Kesimpulan dan Cara Kerja

File docker-compose.yml ini mendefinisikan infrastruktur lengkap untuk jaringan Ethereum privat (Clique PoA) dengan:

Satu Bootnode (bootnode1) sebagai titik penemuan awal dan juga node non-signer.

Lima pasang node Signer (signerX dan clefX), di mana signerX adalah node Geth yang menjalankan PoA dan clefX adalah layanan penandatanganan eksternal yang aman.

Empat node Non-Signer tambahan (nonsigner2 hingga nonsigner5) yang merupakan node penuh biasa untuk interaksi jaringan.

Tumpukan pemantauan terintegrasi:

ethstats-server untuk visualisasi status node dasar.

influxdb untuk menyimpan metrik kinerja detail dari node Geth.

grafana untuk membuat dasbor visual dari data metrik di InfluxDB.

Semua service ini berjalan dalam jaringan Docker kustom (geth-network) yang memungkinkan komunikasi internal antar service menggunakan nama service mereka (misalnya, signer1 dapat menjangkau clef1 di http://clef1:8550). Volume digunakan untuk memastikan data penting (blockchain, kunci node, data Clef, metrik InfluxDB, konfigurasi Grafana) tetap ada meskipun kontainer dihentikan atau dibuat ulang. Penggunaan variabel lingkungan secara ekstensif (${...}) memungkinkan konfigurasi yang fleksibel melalui file .env tanpa mengubah file docker-compose.yml itu sendiri.

Untuk menjalankan setup ini, Anda biasanya memerlukan:

Docker dan Docker Compose terinstal.

File .env yang mendefinisikan semua variabel lingkungan yang direferensikan (seperti NETWORK_ID, BOOTNODE_ENODE, SIGNERX_PASSWORD, SIGNERX_ADDRESS, kredensial InfluxDB, ETHSTATS_WS_SECRET, dll.).

Struktur direktori ./config dan ./data yang sesuai, berisi genesis.json, file password (*.pass), dan direktori keystore untuk setiap akun.

File Dockerfile.clef untuk membangun image Clef kustom.

File rules.js untuk Clef.

Setelah semua prasyarat terpenuhi, Anda dapat menjalankan docker-compose up -d untuk memulai semua service di latar belakang.