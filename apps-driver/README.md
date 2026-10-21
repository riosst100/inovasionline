# apps-driver

Aplikasi ringan (Flutter) untuk driver: konfirmasi pesanan **dikirim** (paket diambil) dan **diterima**
(paket diserahkan ke pembeli), masing-masing dengan **scan QR paket + foto bukti**. Satu driver bisa
membawa banyak paket; setiap paket dikenali dari QR-nya, jadi scan bisa berulang tanpa keluar layar.

## Alur

1. Admin menandai pesanan **Siap** (`ready`). Detail pesanan di `apps-admin` menampilkan **QR Paket**.
2. Driver scan QR -> foto paket -> **Konfirmasi dikirim**. Pesanan menjadi `on_delivery`, terikat ke driver itu.
3. Di tujuan: driver scan QR yang sama (atau ketuk kartu di tab *Perlu Dikirim*) -> foto bukti ->
   **Konfirmasi diterima**. Pesanan menjadi `completed`; COD otomatis `paid`.

Format QR: `IO:<nomor pesanan>:<tanda tangan HMAC>`; server menolak QR yang tanda tangannya tidak cocok.

## API (`/api/admin/driver/*`, butuh permission `delivery.update`)

| Method | Path | Fungsi |
|--------|------|--------|
| GET  | `/orders?tab=active\|done` | paket milik driver |
| POST | `/scan` `{code}` | cari pesanan dari QR + `next_action` (`ship`/`deliver`/`none`) |
| POST | `/orders/{id}/ship` `code`, `photo` | ready -> on_delivery |
| POST | `/orders/{id}/deliver` `code`, `photo` | on_delivery -> completed |

Login memakai akun driver yang dibuat dari menu Driver di admin (`/api/admin/auth/login`, `X-Client: mobile`).

## Menjalankan

```bash
cp .env.example .env       # juga .env.dev dan .env.prod
flutter pub get
run-usb.bat                # perangkat USB, backend lokal
flutter build apk --release -t lib/main_prod.dart
```
