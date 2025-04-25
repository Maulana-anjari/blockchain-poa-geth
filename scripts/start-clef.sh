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