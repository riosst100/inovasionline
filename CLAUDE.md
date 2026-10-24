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
page's `IMPORT_HINT` too.
