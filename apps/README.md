# Inovasi Online — Flutter App

Native Android/iOS client for the Inovasi Online marketplace, backed by the same
`inovasionline-backend-laravel` REST API used by the Next.js frontend.

## Scope (Phase 1)

Customer marketplace only, mirroring the Next.js customer-facing experience:

- Auth: register, login, logout, forgot password, profile
- Browse categories and category products
- Product detail
- Flash sale (by slot/schedule)
- Best sellers
- Store listing
- Search (products + stores)

Seller Center and Admin are not included in this phase.

## Auth strategy

The backend's Sanctum auth is cookie/session-based (`statefulApi()`), built for the
Next.js SPA. Native mobile apps can't share that cookie jar, so this app authenticates
via **Sanctum personal access tokens (Bearer)** instead:

- Every request from this app sends `X-Client: mobile`.
- `AuthController@login` / `@register` detect that header and return a `token` field
  (via `$user->createToken(...)`) instead of starting a cookie session.
- The Next.js cookie-based flow is untouched — this was an additive change to
  `AuthController.php` only.
- The token is stored via `flutter_secure_storage` and sent as
  `Authorization: Bearer <token>` on every request (see `lib/core/api/api_client.dart`).

## Setup

```bash
cd inovasionline-apps-flutter
flutter pub get
copy .env.example .env   # Windows; use `cp` on macOS/Linux
```

### `.env`

```env
API_BASE_URL=http://localhost:8000/api/v1
APP_BASE_URL=http://localhost:8000
```

- Windows desktop / web / iOS simulator: use `http://localhost:8000/api/v1` (the default).
- Android emulator: use `http://10.0.2.2:8000/api/v1` — `10.0.2.2` is the emulator's
  alias for the host machine's `localhost`.
- Physical device: use your machine's LAN IP (e.g. `http://192.168.1.10:8000/api/v1`)
  and make sure `php artisan serve --host=0.0.0.0` is running.

## Running

Start the backend first (see root `README.md`):

```bash
cd ../inovasionline-backend-laravel
php artisan serve
```

Then run the app:

```bash
cd inovasionline-apps-flutter
flutter run
```

## Architecture

```text
lib/
├── config/         env, theme, go_router routes
├── core/           api client (dio), secure token storage, formatters
├── models/         plain Dart models matching backend JsonResource shapes
├── services/       one service per API resource (auth, catalog, search, store, banner)
├── providers/      Riverpod providers wiring services + auth state
├── features/       one folder per screen/flow (auth, home, categories, products,
│                   flash_sale, search, stores, account, shell)
└── widgets/        shared widgets (product card/grid)
```

State management: Riverpod. Routing: go_router with a `StatefulShellRoute` bottom nav
(Beranda / Flash Sale / Toko / Akun).
