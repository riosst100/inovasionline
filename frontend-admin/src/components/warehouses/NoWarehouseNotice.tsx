import Link from 'next/link';

/** Stock is stored per warehouse, so products cannot hold stock until a warehouse exists. */
export default function NoWarehouseNotice() {
  return (
    <p className="rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
      Stok disimpan per gudang dan belum ada gudang aktif.{' '}
      <Link href="/dashboard/warehouses/new" className="font-semibold underline">
        Tambah gudang
      </Link>{' '}
      terlebih dahulu untuk mengatur stok produk ini.
    </p>
  );
}
