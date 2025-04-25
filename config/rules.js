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