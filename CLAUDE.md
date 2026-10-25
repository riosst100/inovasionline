# Notes for AI agents

## Import / Export data (CSV / XLSX)

Every admin list page that offers import/export (Produk, Kategori, Gudang, Stok Produk, Supplier, Brand, ...)
uses **one shared, queued system**. Do not build a custom upload form, CSV parser, or download endpoint for a new
resource — plug into this one so every page looks and behaves the same.

**Backend** (`backend/app/Support/DataTransfer/`)
1. Write a handler in `Handlers/` implementing `TransferHandler`: `label`, `headers`, `sampleRow` (template row,
   use an obviously fake value so importing the untouched template never overwrites real data), `exportQuery`,
   `exportRow`, `prepareImport`, `importRow`. In `importRow`, throw `RowSkippedException` with an Indonesian
   message for invalid rows and return `ImportResult::CREATED` / `UPDATED`. Document the row-matching key
   (id / code / slug / name) in the class docblock. Existing handlers are the reference.
2. Register it in `DataTransferRegistry::HANDLERS` under a resource key (e.g. `'brands'`). The generic
   `/api/admin/data-transfers` endpoints (export, import, template, history, download) then work with no new routes.

**Frontend** (`frontend-admin/src/`)
1. Add the resource key + label to `RESOURCE_LABELS` in `lib/dataTransfer.ts` (also feeds the Riwayat
   Import/Export filter).
2. On the list page, use the shared components (see `app/dashboard/master-data/brands/page.tsx`):
   ```tsx
   const transfers = useDataTransfers({ resource: 'brands', perPage: 5 }, onTransferFinished); // reload list after import
   <ImportExportActions resource="brands" onStarted={transfers.track} importHint={IMPORT_HINT} />
   <DataTransferProgress items={transfers.items} resource="brands" />
   ```
   `IMPORT_HINT` lists the columns (required ones in bold) and how existing rows are matched/updated.

When you add a column to a model that has a handler, add it to the handler's headers/export/import and to the
page's `IMPORT_HINT` too. A handler's resource key (dashes → underscores) must be an `AdminMenu` key: export needs
view and import needs manage on that menu.

## Dates in the admin panel (WIB)

Format and parse every date through `frontend-admin/src/lib/date.ts` (`formatDate`, `formatDateTime`, `formatTime`,
`todayWib`, `wibParts` / `fromWib` for date/time inputs). They always use Asia/Jakarta (UTC+7), whatever the viewer's
device timezone. Don't call `toLocaleDateString` / `toLocaleString` / `getHours` etc. on a Date directly.

## Admin role access (per menu)

Roles grant `{menu}.view` (menu shows, page opens, GET works) and `{menu}.manage` (writes; implies view) per
sidebar menu. When you add an admin page:
1. Backend: add the menu to `app/Support/Permissions/AdminMenu.php` and guard its routes with
   `->middleware('menu:<key>')`. Add other menus that read it as a lookup after the owner
   (`menu:suppliers,products,purchases`: Produk and Pembelian may GET suppliers, only Supplier may write).
2. Frontend: give the sidebar link `perm: '<key>'` in `components/layout/AdminSidebar.tsx`; that also guards the
   page URL (`menuForPath` in `AdminLayout`).

## Realtime admin panel (Reverb)

The dashboard, instant-order alerts and the Pesanan menu badge update over WebSocket. Model saves call
`AdminDataChanged::signal()` (listeners in `AppServiceProvider::boot`), which broadcasts only a topic on the private
channels `admin.dashboard` / `admin.orders`; the frontend (`lib/realtime.ts` → `onAdminChange`) refetches through the
normal permission-checked endpoints. When the dashboard shows data from a new model, add that model to the list in
`AppServiceProvider`. Broadcasts are queued, so the `queue` and `reverb` containers must be running.
