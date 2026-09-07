# 💰 Cashflow - Flutter Catatan Keuangan

Aplikasi **Cashflow** adalah aplikasi pencatat pemasukan dan pengeluaran harian yang sederhana namun fungsional. Cocok digunakan untuk mengelola keuangan pribadi secara efisien dan modern langsung dari perangkat mobile.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green)
![License](https://img.shields.io/github/license/firdaus12p/cashflow)

---

## ✨ Fitur Utama

- 📥 Tambah pemasukan
- 📤 Tambah pengeluaran
- 📊 Rekap ringkas bulanan
- 📅 Filter transaksi berdasarkan tanggal
- 🔎 Pencarian transaksi
- 🎨 UI sederhana dan mudah digunakan
- 📱 Support Android (dan iOS jika dikonfigurasi)

---

## 📸 Screenshot

| Home                                 | Tambah Transaksi                         | Grafik Bulanan                         | Histori Transaksi                      | Wishlist Barang                         | Target Tabungan                       | Statistik Keuangan                       | Pie Chart Pengeluaran                 |
| ------------------------------------ | ---------------------------------------- | -------------------------------------- | -------------------------------------- | --------------------------------------- | ------------------------------------- | ---------------------------------------- | ------------------------------------- |
| ![home](assets/screenshots/home.jpg) | ![add](assets/screenshots/transaksi.jpg) | ![chart](assets/screenshots/chart.jpg) | ![add](assets/screenshots/history.jpg) | ![add](assets/screenshots/wishlist.jpg) | ![add](assets/screenshots/target.jpg) | ![add](assets/screenshots/statistik.jpg) | ![add](assets/screenshots/grafik.jpg) |

---

## 🚀 Instalasi & Menjalankan Aplikasi

1. **Clone repositori ini**

   ```bash
   git clone https://github.com/firdaus12p/cashflow.git
   cd cashflow
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Jalankan di emulator atau device**
   ```bash
   flutter run
   ```

---

## 🛠️ Stack & Teknologi

- **Flutter** – UI toolkit dari Google
- **Dart** – Bahasa pemrograman utama
- **SQLite** – Untuk penyimpanan data lokal
- **charts_flutter** – Untuk grafik keuangan

---

## 📦 Build APK

Build release wajib memakai signing production dari `android/key.properties`; tidak ada fallback ke signing debug. File lokal tersebut harus berisi `keyAlias`, `keyPassword`, `storeFile`, dan `storePassword` yang tidak kosong, dengan `storeFile` menunjuk ke file keystore yang tersedia. Gunakan path absolut untuk menghindari ambiguitas; path relatif pada konfigurasi ini dihitung dari `android/app`.

Task Gradle `validateProductionSigning` dijalankan sebelum `preReleaseBuild` dan menolak konfigurasi yang tidak lengkap atau file keystore yang tidak ada. Jangan commit `key.properties`, keystore (`*.jks` / `*.keystore`), atau password; pola file tersebut sudah diabaikan oleh `android/.gitignore`. Build debug tetap dapat digunakan tanpa konfigurasi signing release.

Setelah konfigurasi signing production tersedia, build APK:

```bash
flutter build apk --release
```

---

## 🤝 Kontribusi

Kontribusi sangat terbuka! Jika kamu ingin membantu mengembangkan fitur atau memperbaiki bug:

1. Fork repo ini di [github.com/firdaus12p/cashflow](https://github.com/firdaus12p/cashflow)
2. Buat branch fitur (`git checkout -b fitur-baru`)
3. Commit perubahan (`git commit -m 'Tambah fitur'`)
4. Push ke branch (`git push origin fitur-baru`)
5. Buat pull request

---

## 📄 Lisensi

Project ini menggunakan lisensi [MIT](LICENSE).
