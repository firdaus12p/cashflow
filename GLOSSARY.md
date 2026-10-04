# Catatan Keuangan Pribadi (cashflow)

Aplikasi pencatatan dan pengelolaan keuangan pribadi berbasis offline tanpa integrasi perbankan langsung, yang memisahkan wadah penyimpanan fisik/digital, alokasi anggaran, dan catatan komitmen finansial.

## Language

### Dompet & Saldo

**Dompet**:
Wadah pencatatan akun uang fisik atau digital (seperti tunai, rekening bank, atau dompet digital) tempat keberadaan saldo pengguna dicatat.
_Avoid_: Akun, Rekening, Kasir

**Total Saldo**:
Jumlah akumulasi seluruh saldo uang dari seluruh dompet aktif sepanjang riwayat pencatatan aplikasi.
_Avoid_: Saldo berjalan, Kas bersih, Uang kas

**Mode Pos**:
Status sistem yang menentukan apakah pencatatan uang harus dialokasikan ke pos keuangan atau hanya menggunakan dompet langsung.
_Avoid_: Mode budgeting, Mode amplop, Sistem anggaran

### Pos Keuangan & Alokasi

**Pos Keuangan**:
Partisi peruntukan dana di dalam satu dompet tertentu dengan persentase alokasi yang ditentukan pengguna.
_Avoid_: Kategori, Budget, Amplop, Kantong

**Persentase Alokasi**:
Porsi bagian pemasukan untuk suatu pos keuangan aktif di mana total seluruh pos aktif lintas dompet harus berjumlah 100%.
_Avoid_: Bobot, Rasio bunga, Target alokasi

**Rekonsiliasi Pos**:
Sinkronisasi matematis per dompet untuk menyesuaikan saldo pos keuangan dengan saldo dompet riil saat Mode Pos diaktifkan.
_Avoid_: Reset pos, Audit saldo, Kliring

**Transfer Antarpos**:
Pemindahan sejumlah dana dari satu pos keuangan ke pos keuangan lain, baik dalam dompet yang sama maupun lintas dompet.
_Avoid_: Mutasi dompet, Transfer bank, Kirim uang

**Transfer Internal**:
Kategori transaksi khusus sistem yang mencatat pergerakan saldo lintas dompet akibat transfer pos dan dikecualikan dari statistik pengeluaran konsumsi.
_Avoid_: Biaya transfer, Pemasukan lain, Kliring

### Transaksi

**Transaksi**:
Catatan peristiwa perubahan saldo uang masuk atau keluar pada waktu tertentu.
_Avoid_: Mutasi, Jurnal, Pembelian

**Pemasukan**:
Transaksi penambahan uang ke dalam satu dompet serta pos keuangan terkait jika Mode Pos aktif.
_Avoid_: Uang masuk, Kredit, Penerimaan

**Pengeluaran**:
Transaksi pengurangan uang dari satu dompet dan satu pos keuangan tertentu untuk kebutuhan konsumsi.
_Avoid_: Belanja, Uang keluar, Beban, Debit

**Kategori Transaksi**:
Label klasifikasi jenis pengeluaran atau sumber pemasukan (seperti Makanan, Transport, Gaji, atau Bonus).
_Avoid_: Pos keuangan, Tag, Tipe

**Alokasi Pemasukan**:
Pembagian nominal suatu transaksi pemasukan ke satu atau beberapa pos keuangan terpilih menggunakan normalisasi persentase.
_Avoid_: Split bill, Bagi hasil, Multi-pos

### Hutang & Piutang

**Hutang**:
Kewajiban pengembalian sejumlah uang oleh pengguna kepada pihak lain (Saya Berhutang).
_Avoid_: Pinjaman diterima, Liabilitas, Kredit pengguna

**Piutang**:
Hak penerimaan sejumlah uang milik pengguna yang sedang dipinjam oleh pihak lain (Piutang Saya).
_Avoid_: Tagihan pinjaman, Aset luar, Kredit diberikan

**Pihak Terkait**:
Nama individu atau entitas pihak kedua yang terlibat dalam perjanjian hutang atau piutang.
_Avoid_: Kreditor, Debitur, Kontak, Peminjam

**Mode Pencatatan**:
Ketentuan apakah transaksi hutang, piutang, atau pembayarannya memengaruhi saldo uang atau hanya dicatat sebagai buku kewajiban.
_Avoid_: Status kas, Tipe transaksi

**Masuk ke Saldo**:
Mode pencatatan di mana penciptaan hutang/piutang atau cicilannya langsung memotong atau menambah saldo dompet dan pos keuangan.
_Avoid_: Mode tunai, Transaksi riil

**Catatan Saja**:
Mode pencatatan hutang/piutang atau cicilannya yang hanya mencatat nilai komitmen tanpa mengubah saldo dompet maupun pos keuangan.
_Avoid_: Memo, Draft, Non-tunai

**Cicilan**:
Pembayaran bertahap atau pelunasan penuh atas suatu catatan hutang atau piutang yang masih aktif.
_Avoid_: Angsuran, Refund, Pelunasan berkala

**Overdue**:
Status catatan hutang atau piutang aktif yang tanggal jatuh temponya telah melewati akhir hari kalender tanggal tersebut dan belum lunas.
_Avoid_: Macet, Gagal bayar, Kadaluarsa

### Rencana & Sasaran

**Target Tabungan**:
Sasaran jumlah uang yang ingin dikumpulkan pengguna untuk tujuan tertentu tanpa mengunci atau memotong saldo dompet.
_Avoid_: Pos tabungan, Rekening berjangka, Dana simpanan

**Top Up Target**:
Pencatatan penambahan progres angka terkumpul pada suatu target tabungan tanpa transaksi pengurangan saldo dompet.
_Avoid_: Setoran, Pengeluaran tabungan, Pindahan saldo

**Wishlist Belanja**:
Daftar rencana barang yang ingin dibeli pengguna beserta estimasi harga dan skala prioritas.
_Avoid_: Keranjang belanja, Target barang, Daftar impian

**Pembelian Wishlist**:
Tindakan pembelian item wishlist yang secara otomatis menerbitkan transaksi pengeluaran Belanja dan menghapus item dari daftar wishlist.
_Avoid_: Eksekusi wishlist, Checkout barang

### Fitur Pendukung

**Statistik**:
Laporan agregat visual tren pemasukan, pengeluaran konsumsi, dan distribusi kategori pada periode kalender tertentu.
_Avoid_: Laporan rugi laba, Analisis AI, Neraca

**Badge**:
Penghargaan pencapaian milestone aktivitas pencatatan yang diberikan secara otomatis oleh sistem kepada pengguna.
_Avoid_: Reward, Poin, Level

**Pengingat Malam**:
Jadwal notifikasi harian pukul 22:00 untuk mengingatkan pencatatan keuangan dan kewajiban hutang yang sudah overdue.
_Avoid_: Alarm, Push notif harian, Pengingat jatuh tempo
