#!/bin/bash

# ==============================================================================
# Script untuk menghubungkan setiap node geth ke semua peer lainnya secara manual.
#
# Usage:
#   ./connect-peers.sh
#
# Prasyarat:
#   - File '.env' harus ada dan berisi variabel ENODE_<N> untuk setiap node.
#     Contoh:
#     ENODE_1="enode://..."
#     ENODE_2="enode://..."
#   - File 'config.sh' harus ada dan berisi variabel NUM_NODES.
# ==============================================================================

# Muat logger helper
source ./scripts/logger.sh
source ./config.sh

# Muat konfigurasi
if [ ! -f "./config.sh" ]; then
    log_error "File config.sh tidak ditemukan. Harap buat terlebih dahulu."
    exit 1
fi

# Muat variabel environment dari .env
if [ ! -f ".env" ]; then
    log_error "File .env tidak ditemukan. Pastikan file tersebut ada dan berisi enode."
    exit 1
fi
export $(grep -v '^#' ".env" | xargs)

# Periksa apakah NUM_NODES sudah diatur
if [ -z "$NUM_NODES" ]; then
    log_error "Variabel NUM_NODES tidak diatur dalam config.sh."
    exit 1
fi

log_info "Memulai proses untuk menghubungkan peer secara manual untuk $NUM_NODES node..."

# Loop melalui setiap node (sebagai node yang akan menambahkan peer)
for i in $(seq 1 $NUM_NODES); do
    NODE_NAME="execution_node${i}" 
    
    # Loop melalui setiap node lagi (sebagai peer yang akan ditambahkan)
    for j in $(seq 1 $NUM_NODES); do
        # Lewati jika node sama (tidak perlu menambahkan diri sendiri)
        if [ "$i" -eq "$j" ]; then
            continue
        fi

        # Dapatkan enode dari peer (node j)
        enode_var="ENODE${j}"
        ENODE_PEER="${!enode_var}"

        if [ -z "$ENODE_PEER" ]; then
            log_warn "ENODE${j} tidak ditemukan di file .env. Melewati penambahan peer untuk ${NODE_NAME}."
            continue
        fi

        log_info "Menghubungkan ${NODE_NAME} ke node ${j}..."

        # Bangun dan jalankan perintah docker exec
        docker exec "${NODE_NAME}" geth --exec "admin.addPeer(\"${ENODE_PEER}\")" attach /data/geth.ipc
        
        # Periksa status perintah terakhir
        if [ $? -eq 0 ]; then
            log_success "Berhasil menghubungkan ${NODE_NAME} ke node ${j}."
        else
            log_error "Gagal menghubungkan ${NODE_NAME} ke node ${j}."
        fi
    done
done

log_success "Selesai menghubungkan semua peer."
