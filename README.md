# Inovasi Online (Monorepo)

Monorepo terpadu untuk platform **Inovasi Online**, menggabungkan backend REST API (Laravel) dan aplikasi mobile klien (Flutter).

## Struktur Repositori

```text
inovasionline/
├── backend/            # Backend Laravel (REST API & Websocket Reverb)
│   ├── app/
│   ├── config/
│   ├── database/
│   ├── routes/
│   └── ...
├── apps/               # Mobile App Flutter (Android & iOS)
│   ├── lib/
│   ├── android/
│   ├── assets/
│   ├── dev-run.bat
│   └── ...
├── frontend-admin/     # Web Admin Portal (Next.js App Router, Tailwind)
│   ├── src/
│   ├── package.json
│   └── ...
├── docker/             # Docker configuration
│   └── backend/        # Dockerfile & entrypoint untuk Laravel
├── docker-compose.yml  # Docker Compose stack (backend, db, redis, reverb, queue)
├── deploy-local.sh     # Script deploy/start lokal cepat
└── README.md
```

---

## 1. Menjalankan Backend dengan Docker

Backend berjalan di dalam container Docker yang sudah mencakup PHP 8.3 CLI, PostgreSQL 16, Redis, Reverb, dan Queue Worker.

### Jalankan Stack:
```bash
./deploy-local.sh
# atau secara manual:
docker compose up -d --build
```

### Layanan & Port:
- **Backend API**: `http://localhost:8000` *(juga diteruskan ke `8001` untuk kompatibilitas)*
- **Reverb Websocket**: `http://localhost:8080`
- **PostgreSQL**: `localhost:5432` (Database: `inovasionline_marketplace`, User: `postgres`, Pass: `postgres`)
- **Redis**: `localhost:6379`

> Port & kredensial bisa di-override lewat file `.env` di root project (lihat `.env.example`), mis. `BACKEND_PORT`, `BACKEND_ALT_PORT`, `REVERB_PORT`, `DB_PORT`, `REDIS_PORT`.

### Perintah Berguna:
- **Lihat log backend**:
  ```bash
  docker compose logs -f backend
  ```
- **Jalankan Artisan**:
  ```bash
  docker compose exec backend php artisan <perintah>
  ```
- **Jalankan Migrasi Manual**:
  ```bash
  docker compose exec backend php artisan migrate
  ```
- **Jalankan Seeder**:
  ```bash
  docker compose exec backend php artisan db:seed
  ```
- **Hentikan Container**:
  ```bash
  docker compose down
  ```

---

## 2. Setup & Menjalankan Flutter Apps

Aplikasi Flutter berada di folder `apps/`.

### Setup Dependency:
Jalankan di Windows terminal / PowerShell atau IDE:
```bash
cd apps
flutter pub get
```

### Environment Files:
File environment sudah disiapkan:
- `apps/.env` (default / staging)
- `apps/.env.dev` (local development: mengarah ke `http://127.0.0.1:8001/api/v1` atau `http://10.0.2.2:8000/api/v1` untuk emulator)
- `apps/.env.prod` (production)

### Menjalankan Aplikasi:
- **Menggunakan script dev (Android via USB + Port Reverse)**:
  ```cmd
  cd apps
  dev-run.bat
  ```
- **Menggunakan Flutter CLI langsung**:
  ```bash
  flutter run --flavor dev -t lib/main_dev.dart
  ```
- **Build Release APK**:
  ```cmd
  release-apk.bat
  ```

---

## 3. Web Admin Portal (Next.js)

Web Admin Portal berada di folder `frontend-admin/`. Digunakan oleh **Super Admin** untuk mengelola hak akses role (Driver, Admin, Sales, dll), menambah user staff/admin, dan memonitor operasional marketplace.

### Menjalankan Frontend Admin:
```bash
cd frontend-admin
npm install
npm run dev
```

- **URL Web Portal**: `http://localhost:3000`
- **Kredensial Default Super Admin**:
  - Email: `admin@inovasionline.com`
  - Password: `password`
- **Fitur Utama**:
  - **Login Admin**: Autentikasi token Sanctum via REST API backend.
  - **Manajemen Role**: Super Admin dapat membuat role baru (Driver, Admin, Sales, Kurir, dll) serta mengatur matriks hak akses per modul.
  - **Manajemen User Admin & Staff**: Super Admin dapat mendaftarkan akun personil baru dan menetapkan role hak akses.

