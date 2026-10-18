# apps-admin

Aplikasi admin mobile (Flutter) — versi ringkas dari `frontend-admin`, fokus ke:

- **Pesanan**: daftar + filter status + pencarian (nomor pesanan / nama pembeli), detail, ubah status
  (terima → siapkan → siap → selesai, atau batalkan dengan pengembalian stok & refund ke saldo).
- **Produk**: daftar + filter status + pencarian, aktif/nonaktif cepat, tambah/edit (harga, kategori,
  stok per gudang, deskripsi), unggah/hapus/jadikan foto utama, hapus produk.
- **Kategori**: daftar (induk & sub), tambah/edit (nama, induk, deskripsi, gambar), aktif/nonaktif, hapus.

Menggunakan API admin khusus `/api/admin/*` (sama dengan `frontend-admin`). Login mengirim header
`X-Client: mobile` sehingga backend mengembalikan token Bearer di body (web tetap memakai cookie HttpOnly).

## Menjalankan

```bash
cp .env.example .env       # juga .env.dev dan .env.prod
flutter pub get

# Perangkat via USB, backend lokal di port 8000 (adb reverse)
dev-run.bat                # = flutter run -t lib/main_dev.dart

# Emulator Android (10.0.2.2 = host)
flutter run                # memakai .env

# Rilis (API produksi)
flutter build apk --release -t lib/main_prod.dart
```

| File        | `API_BASE_URL`                      |
|-------------|-------------------------------------|
| `.env`      | `http://10.0.2.2:8000/api`          |
| `.env.dev`  | `http://127.0.0.1:8000/api`         |
| `.env.prod` | `https://api.inovasionline.com/api` |

HTTP tanpa TLS hanya diizinkan di build debug (Android `src/debug/AndroidManifest.xml`).

## Logo & ikon

Logo sama dengan app pelanggan, dengan latar abu gelap bergradasi hijau tipis dan badge "Admin". Setelah splash ada animasi intro yang sama seperti app pelanggan (`lib/features/shell/intro.dart`). Gambar di `assets/images/` dibuat oleh
`scripts/gen_logos.js` (lihat komentar di atas file), lalu `dart run flutter_launcher_icons` dan
`dart run flutter_native_splash:create`.
