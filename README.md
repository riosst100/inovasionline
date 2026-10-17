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
├── frontend/           # Website publik inovasionline.com (Next.js)
├── docker-compose.yml  # Docker Compose stack (backend, db, redis, reverb, queue, admin, frontend)
├── deploy-local.sh     # Script deploy/start lokal cepat
└── README.md
```

---

## 1. Menjalankan Stack dengan Docker

Seluruh stack lokal berjalan di Docker: backend (PHP 8.3 CLI, PostgreSQL 16, Redis, Reverb, Queue Worker), `frontend-admin`, dan `frontend`. Kedua frontend berjalan dalam mode dev (hot reload); `node_modules` & `.next` disimpan di volume Docker, dan `npm ci` otomatis dijalankan ulang saat `package-lock.json` berubah.

### Jalankan Stack (Windows → WSL, direkomendasikan):
Kode diedit di Windows, lalu `backend/`, `frontend/`, `frontend-admin/` (+ `docker/`, `docker-compose.yml`) disinkronkan ke `~/projects/inovasionline` di WSL (`Ubuntu-24.04`) dan Docker dijalankan dari sana: lebih cepat dan hot reload jalan. `apps/` (Flutter) tidak ikut, tetap di-build dari Windows.
```bash
bash scripts/wsl-sync.sh up      # sync + docker compose up -d --build
bash scripts/wsl-sync.sh watch   # biarkan jalan: sync otomatis tiap file disimpan
bash scripts/wsl-sync.sh logs backend   # juga: ps, down, sync
```
`.env` root & `backend/.env` hanya disalin sekali ke WSL; setelah itu ubah langsung di `~/projects/inovasionline` (WSL).

### Jalankan Stack (langsung dari folder ini):
```bash
./deploy-local.sh
# atau secara manual:
docker compose up -d --build
```

### Layanan & Port:
- **Backend API**: `http://localhost:8000` *(juga diteruskan ke `8001` untuk kompatibilitas)*
- **Web Admin (`frontend-admin`)**: `http://localhost:3000`
- **Website (`frontend`)**: `http://localhost:3001`
- **Reverb Websocket**: `http://localhost:8080`
- **PostgreSQL**: `localhost:5432` (Database: `inovasionline_marketplace`, User: `postgres`, Pass: `postgres`)
- **Redis**: `localhost:6379`

> Port & kredensial bisa di-override lewat file `.env` di root project (lihat `.env.example`), mis. `BACKEND_PORT`, `BACKEND_ALT_PORT`, `REVERB_PORT`, `DB_PORT`, `REDIS_PORT`, `ADMIN_PORT`, `FRONTEND_PORT`.

### Perintah Berguna:
- **Lihat log backend / admin / frontend**:
  ```bash
  docker compose logs -f backend
  docker compose logs -f admin frontend
  ```
- **Install paket npm baru** (mis. di admin):
  ```bash
  docker compose exec admin npm install <paket>
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
Otomatis jalan lewat `docker compose up -d` (lihat bagian 1). Tanpa Docker:
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

