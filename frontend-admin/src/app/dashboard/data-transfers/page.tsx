'use client';

import React, { Suspense, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { ArrowDownUp, ChevronLeft, ChevronRight, Loader2, RefreshCw } from 'lucide-react';
import AdminLayout from '../../../components/layout/AdminLayout';
import DataTransferItem from '../../../components/data-transfer/DataTransferItem';
import { dataTransferApi, RESOURCE_LABELS, STATUS_META, useDataTransfers } from '../../../lib/dataTransfer';
import { DataTransfer, DataTransferStatus, DataTransferType } from '../../../types';

export default function DataTransfersPage() {
  return (
    <AdminLayout>
      <Suspense>
        <DataTransferHistory />
      </Suspense>
    </AdminLayout>
  );
}

const selectCls = 'rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-medium text-slate-700';

function DataTransferHistory() {
  const params = useSearchParams();
  const [resource, setResource] = useState(params.get('resource') ?? '');
  const [type, setType] = useState<DataTransferType | ''>('');
  const [status, setStatus] = useState<DataTransferStatus | 'active' | ''>('');
  const [page, setPage] = useState(1);
  const [error, setError] = useState('');

  const { items, meta, loading, error: loadError, refresh } = useDataTransfers({ resource, type, status, page, perPage: 20 });

  const filter = <T,>(setter: (v: T) => void) => (v: T) => {
    setter(v);
    setPage(1);
  };

  const remove = async (t: DataTransfer) => {
    if (!window.confirm(`Hapus riwayat "${t.file_name}"? File terkait juga akan dihapus.`)) return;
    setError('');
    try {
      await dataTransferApi.remove(t.id);
      refresh();
    } catch (err: any) {
      setError(err?.message || 'Gagal menghapus riwayat.');
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <ArrowDownUp className="h-6 w-6 text-emerald-600" />
            <h2 className="text-xl font-extrabold text-slate-900 md:text-2xl">Riwayat Import / Export</h2>
          </div>
          <p className="mt-1 text-xs text-slate-500 md:text-sm">
            Semua proses import & export data (CSV/XLSX). Proses berjalan di latar belakang dan diperbarui otomatis.
          </p>
          {(error || loadError) && <p className="mt-1 text-xs text-red-600">{error || loadError}</p>}
        </div>
        <button
          onClick={refresh}
          className="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-bold text-slate-700 hover:bg-slate-50"
        >
          <RefreshCw className="h-4 w-4" /> Muat ulang
        </button>
      </div>

      <div className="flex flex-wrap gap-2">
        <select value={resource} onChange={(e) => filter(setResource)(e.target.value)} className={selectCls}>
          <option value="">Semua data</option>
          {Object.entries(RESOURCE_LABELS).map(([key, label]) => (
            <option key={key} value={key}>
              {label}
            </option>
          ))}
        </select>
        <select value={type} onChange={(e) => filter(setType)(e.target.value as DataTransferType | '')} className={selectCls}>
          <option value="">Import & Export</option>
          <option value="import">Import</option>
          <option value="export">Export</option>
        </select>
        <select
          value={status}
          onChange={(e) => filter(setStatus)(e.target.value as DataTransferStatus | 'active' | '')}
          className={selectCls}
        >
          <option value="">Semua status</option>
          <option value="active">Sedang berjalan</option>
          {Object.entries(STATUS_META).map(([key, s]) => (
            <option key={key} value={key}>
              {s.label}
            </option>
          ))}
        </select>
      </div>

      <div className="rounded-2xl border border-slate-200/80 bg-white p-4 shadow-xs sm:p-6">
        {loading ? (
          <div className="flex justify-center py-12 text-emerald-600">
            <Loader2 className="h-6 w-6 animate-spin" />
          </div>
        ) : items.length === 0 ? (
          <div className="py-12 text-center text-sm text-slate-400">Belum ada riwayat import/export.</div>
        ) : (
          <div className="space-y-2">
            {items.map((t) => (
              <DataTransferItem key={t.id} transfer={t} detailed onDelete={remove} />
            ))}
          </div>
        )}

        {meta && meta.last_page > 1 && (
          <div className="mt-4 flex items-center justify-between text-xs text-slate-500">
            <span>
              Halaman {meta.current_page} dari {meta.last_page} · {meta.total} proses
            </span>
            <div className="flex gap-1">
              <button
                disabled={page <= 1}
                onClick={() => setPage(page - 1)}
                className="rounded-lg border border-slate-200 p-1.5 hover:bg-slate-50 disabled:opacity-40"
                aria-label="Sebelumnya"
              >
                <ChevronLeft className="h-4 w-4" />
              </button>
              <button
                disabled={page >= meta.last_page}
                onClick={() => setPage(page + 1)}
                className="rounded-lg border border-slate-200 p-1.5 hover:bg-slate-50 disabled:opacity-40"
                aria-label="Berikutnya"
              >
                <ChevronRight className="h-4 w-4" />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
