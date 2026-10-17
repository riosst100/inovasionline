'use client';

import React, { useState } from 'react';
import { AlertTriangle, Download, FileDown, FileUp, Loader2, Trash2, X } from 'lucide-react';
import { DataTransfer } from '../../types';
import { dataTransferApi, formatDateTime, isActiveTransfer, RESOURCE_LABELS, STATUS_META } from '../../lib/dataTransfer';

type Props = {
  transfer: DataTransfer;
  /** Show resource name & admin (history page) */
  detailed?: boolean;
  onDismiss?: (t: DataTransfer) => void;
  onDelete?: (t: DataTransfer) => void;
};

export default function DataTransferItem({ transfer: t, detailed, onDismiss, onDelete }: Props) {
  const [errors, setErrors] = useState<DataTransfer['row_errors'] | null>(null);
  const [loadingErrors, setLoadingErrors] = useState(false);
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState('');

  const active = isActiveTransfer(t);
  const status = STATUS_META[t.status];
  const Icon = t.type === 'import' ? FileUp : FileDown;
  const typeLabel = t.type === 'import' ? 'Import' : 'Export';

  const toggleErrors = async () => {
    if (errors) return setErrors(null);
    setLoadingErrors(true);
    try {
      setErrors((await dataTransferApi.get(t.id)).row_errors ?? []);
    } catch (err: any) {
      setActionError(err?.message || 'Gagal memuat detail error.');
    } finally {
      setLoadingErrors(false);
    }
  };

  const run = async (fn: () => Promise<void>) => {
    setBusy(true);
    setActionError('');
    try {
      await fn();
    } catch (err: any) {
      setActionError(err?.message || 'Terjadi kesalahan.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="rounded-xl border border-slate-200/80 bg-white p-3">
      <div className="flex items-start gap-3">
        <div
          className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-lg ${
            t.type === 'import' ? 'bg-violet-50 text-violet-600' : 'bg-emerald-50 text-emerald-600'
          }`}
        >
          {active ? <Loader2 className="h-4 w-4 animate-spin" /> : <Icon className="h-4 w-4" />}
        </div>

        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
            <span className="text-sm font-bold text-slate-800">
              {typeLabel} {detailed ? RESOURCE_LABELS[t.resource] ?? t.resource : ''}
            </span>
            <span className="rounded bg-slate-100 px-1.5 py-0.5 text-[10px] font-bold uppercase text-slate-500">{t.format}</span>
            <span className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${status.badge}`}>{status.label}</span>
          </div>
          <p className="mt-0.5 truncate text-xs text-slate-500" title={t.file_name ?? ''}>
            {t.file_name}
            {detailed && t.admin_user ? ` · ${t.admin_user.name}` : ''} · {formatDateTime(t.created_at)}
          </p>

          {t.status !== 'failed' && (
            <div className="mt-2 flex items-center gap-2">
              <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-slate-100">
                <div
                  className={`h-full rounded-full transition-all duration-500 ${status.bar} ${t.status === 'pending' ? 'animate-pulse' : ''}`}
                  style={{ width: `${t.status === 'pending' ? 100 : t.progress}%`, opacity: t.status === 'pending' ? 0.35 : 1 }}
                />
              </div>
              <span className="w-24 shrink-0 text-right text-[11px] tabular-nums text-slate-500">
                {t.status === 'pending' ? 'Antre…' : `${t.processed_rows}/${t.total_rows} · ${t.progress}%`}
              </span>
            </div>
          )}

          {t.status === 'completed' && t.type === 'import' && (
            <p className="mt-1.5 text-xs text-slate-600">
              <span className="font-semibold text-emerald-700">{t.created_rows} baru</span> ·{' '}
              <span className="font-semibold text-sky-700">{t.updated_rows} diperbarui</span>
              {t.failed_rows > 0 && (
                <>
                  {' '}·{' '}
                  <button onClick={toggleErrors} className="font-semibold text-rose-600 underline-offset-2 hover:underline">
                    {t.failed_rows} gagal {loadingErrors ? '…' : errors ? '(sembunyikan)' : '(lihat)'}
                  </button>
                </>
              )}
            </p>
          )}
          {t.status === 'failed' && (
            <p className="mt-1.5 flex items-start gap-1 text-xs text-rose-600">
              <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
              {t.error_message || 'Proses gagal.'}
            </p>
          )}
          {actionError && <p className="mt-1 text-xs text-rose-600">{actionError}</p>}
        </div>

        <div className="flex shrink-0 items-center gap-1">
          {t.status === 'completed' && t.type === 'export' && t.has_file && (
            <button
              disabled={busy}
              onClick={() => run(() => dataTransferApi.download(t))}
              className="inline-flex items-center gap-1 rounded-lg bg-emerald-600 px-2.5 py-1.5 text-xs font-bold text-white hover:bg-emerald-700 disabled:opacity-60"
            >
              {busy ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Download className="h-3.5 w-3.5" />}
              Unduh
            </button>
          )}
          {detailed && t.type === 'import' && t.has_file && (
            <button
              disabled={busy}
              title="Unduh file yang diimport"
              onClick={() => run(() => dataTransferApi.download(t))}
              className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700 disabled:opacity-60"
            >
              <Download className="h-4 w-4" />
            </button>
          )}
          {onDelete && !active && (
            <button
              disabled={busy}
              title="Hapus riwayat"
              onClick={() => onDelete(t)}
              className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-60"
            >
              <Trash2 className="h-4 w-4" />
            </button>
          )}
          {onDismiss && !active && (
            <button
              title="Tutup"
              onClick={() => onDismiss(t)}
              className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
            >
              <X className="h-4 w-4" />
            </button>
          )}
        </div>
      </div>

      {errors && (
        <div className="mt-3 max-h-48 overflow-y-auto rounded-lg border border-rose-100 bg-rose-50/60">
          <table className="w-full text-left text-xs">
            <thead className="sticky top-0 bg-rose-50 text-rose-700">
              <tr>
                <th className="w-16 px-3 py-1.5 font-semibold">Baris</th>
                <th className="px-3 py-1.5 font-semibold">Keterangan</th>
              </tr>
            </thead>
            <tbody>
              {errors.map((e, i) => (
                <tr key={i} className="border-t border-rose-100">
                  <td className="px-3 py-1.5 tabular-nums text-slate-600">{e.row}</td>
                  <td className="px-3 py-1.5 text-slate-700">{e.message}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {t.failed_rows > errors.length && (
            <p className="px-3 py-1.5 text-[11px] text-slate-500">
              Menampilkan {errors.length} dari {t.failed_rows} baris gagal.
            </p>
          )}
        </div>
      )}
    </div>
  );
}
