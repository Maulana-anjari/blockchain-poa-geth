#!/usr/bin/expect -f
# File: scripts/start-clef.sh
# Versi final yang menggabungkan keunggulan skrip asli dengan perbaikan kecil.

# Ambil password dari environment variable yang akan kita set di docker-compose.
# Ini adalah praktik terbaik untuk Docker.
set clef_master_password $env(CLEF_MASTER_PASSWORD)

# Ambil variabel lain yang diperlukan dari environment.
set chain_id $env(NETWORK_ID)
set keystore_path "/root/.ethereum/keystore"
set config_dir "/root/.clef"
set rules_path "/root/rules.js"

# Set timeout tak terbatas agar skrip tidak keluar jika Clef butuh waktu untuk startup.
set timeout -1

# Jalankan (spawn) proses Clef.
# - Menggunakan parameter yang sudah benar dari skrip asli Anda.
# - Menambahkan --suppress-bootwarn dari skrip Dchain untuk log yang lebih bersih.
spawn clef \
    --keystore $keystore_path \
    --configdir $config_dir \
    --chainid $chain_id \
    --rules $rules_path \
    --nousb \
    --advanced \
    --http --http.addr 0.0.0.0 --http.port 8550 --http.vhosts "*" \
    --suppress-bootwarn

# Harapkan prompt password master seed.
expect "Please enter the password to decrypt the master seed"
# Kirim password dari environment variable diikuti newline.
send "$clef_master_password\n"

# Harapkan (expect) prompt "Enter 'ok' to proceed:" yang muncul karena flag --advanced.
# Ini adalah penanganan prompt yang robust.
expect "Enter 'ok' to proceed:"
# Kirim (send) "ok" diikuti newline (\r).
send "ok\n"

# Harapkan prompt persetujuan akun (jika muncul).
expect "Approve? \[y/N\]:"
# Kirim 'y' untuk menyetujui, diikuti newline.
send "y\n"

# Tunggu hingga proses Clef selesai atau menutup output-nya (end of file).
# Ini penting agar kontainer Docker tidak langsung keluar setelah skrip selesai.
# Proses Clef akan tetap berjalan sebagai proses utama.
expect eof
