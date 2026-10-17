'use client';

import React, { useEffect, useRef, useState } from 'react';
import { ChevronDown, Download, FileSpreadsheet, Loader2, Upload, X } from 'lucide-react';
import { DataTransfer, DataTransferFormat } from '../../types';
import { dataTransferApi, RESOURCE_LABELS } from '../../lib/dataTransfer';

type Props = {
  /** Resource key registered in the backend DataTransferRegistry, e.g. "categories" */
  resource: string;
  /** Called with the queued transfer, typically `track` from useDataTransfers */
  onStarted: (t: DataTransfer) => void;
  /** Extra filters sent with exports (e.g. current status filter) */
  exportFilters?: Record<string, unknown>;
  /** Explanation of the columns, shown in the import dialog */
  importHint?: React.ReactNode;
};

const FORMATS: { value: DataTransferFormat; label: string }[] = [
  { value: 'xlsx', label: 'Excel (.xlsx)' },
  { value: 'csv', label: 'CSV (.csv)' },
];

export default function ImportExportActions({ resource, onStarted, exportFilters, importHint }: Props) {
  const [exportOpen, setExportOpen] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState('');
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) setExportOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, []);

  const startExport = async (format: DataTransferFormat) => {
    setExportOpen(false);
    setExporting(true);
    setError('');
    try {
      onStarted(await dataTransferApi.startExport(resource, format, exportFilters));
    } catch (err: any) {
      setError(err?.message || 'Gagal memulai export.');
    } finally {
      setExporting(false);
    }
  };

  const btn =
    'inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-bold text-slate-700 hover:bg-slate-50 disabled:opacity-60';

  return (
    <div className="flex flex-col items-end gap-1">
      <div className="flex items-center gap-2">
        <button onClick={() => setImportOpen(true)} className={btn}>
          <Upload className="h-4 w-4" /> Import
        </button>

        <div ref={menuRef} className="relative">
          <button
            disabled={exporting}
            onClick={() => setExportOpen((v) => !v)}
            aria-haspopup="menu"
            aria-expanded={exportOpen}
            className={btn}
          >
            {exporting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Download className="h-4 w-4" />}
            Export
            <ChevronDown className="h-3.5 w-3.5 text-slate-400" />
          </button>
          {exportOpen && (
            <div
              role="menu"
              className="absolute right-0 z-20 mt-1 w-44 overflow-hidden rounded-xl border border-slate-200 bg-white p-1 shadow-lg"
            >
              {FORMATS.map((f) => (
                <button
                  key={f.value}
                  role="menuitem"
                  onClick={() => startExport(f.value)}
                  className="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-left text-xs font-medium text-slate-700 hover:bg-slate-100"
                >
                  <FileSpreadsheet className="h-4 w-4 text-emerald-600" />
                  {f.label}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
      {error && <p className="text-xs text-rose-600">{error}</p>}

      {importOpen && (
        <ImportDialog
          resource={resource}
          hint={importHint}
          onClose={() => setImportOpen(false)}
          onStarted={(t) => {
            setImportOpen(false);
            onStarted(t);
          }}
        />
      )}
    </div>
  );
}

function ImportDialog({
  resource,
  hint,
  onClose,
  onStarted,
}: {
  resource: string;
  hint?: React.ReactNode;
  onClose: () => void;
  onStarted: (t: DataTransfer) => void;
}) {
  const [file, setFile] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const label = RESOURCE_LABELS[resource] ?? resource;

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!file) return;
    setSaving(true);
    setError('');
    try {
      onStarted(await dataTransferApi.startImport(resource, file));
    } catch (err: any) {
      const details = err?.errors ? Object.values(err.errors).flat().join(' ') : '';
      setError(`${err?.message || 'Gagal mengunggah file.'} ${details}`.trim());
    } finally {
      setSaving(false);
    }
  };

  const template = async (format: DataTransferFormat) => {
    setError('');
    try {
      await dataTransferApi.downloadTemplate(resource, format);
    } catch (err: any) {
      setError(err?.message || 'Gagal mengunduh template.');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <form onSubmit={submit} className="w-full max-w-md space-y-4 rounded-2xl bg-white p-6 text-left shadow-xl">
        <div className="flex items-center justify-between">
          <h3 className="font-extrabold text-slate-900">Import {label}</h3>
          <button type="button" onClick={onClose} aria-label="Tutup">
            <X className="h-5 w-5 text-slate-400" />
          </button>
        </div>

        <label
          className={`flex cursor-pointer flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed px-4 py-6 text-center transition-colors ${
            file ? 'border-emerald-300 bg-emerald-50/50' : 'border-slate-200 hover:border-emerald-300'
          }`}
        >
          <FileSpreadsheet className="h-8 w-8 text-emerald-600" />
          <span className="text-sm font-semibold text-slate-700">{file ? file.name : 'Pilih file CSV atau XLSX'}</span>
          <span className="text-[11px] text-slate-400">
            {file ? `${(file.size / 1024).toFixed(1)} KB` : 'Maksimal 20 MB'}
          </span>
          <input
            type="file"
            accept=".csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            className="sr-only"
            onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          />
        </label>

        <div className="rounded-xl bg-slate-50 p-3 text-xs text-slate-600">
          {hint && <div className="mb-2">{hint}</div>}
          <p>
            Proses berjalan di latar belakang; progres tampil di halaman ini dan di menu Riwayat Import/Export. Unduh
            template:{' '}
            <button type="button" onClick={() => template('xlsx')} className="font-semibold text-emerald-700 hover:underline">
              XLSX
            </button>{' '}
            ·{' '}
            <button type="button" onClick={() => template('csv')} className="font-semibold text-emerald-700 hover:underline">
              CSV
            </button>
          </p>
        </div>

        {error && <p className="text-xs text-red-600">{error}</p>}

        <button
          disabled={!file || saving}
          className="w-full rounded-xl bg-emerald-600 py-2.5 text-sm font-bold text-white hover:bg-emerald-700 disabled:opacity-60"
        >
          {saving ? 'Mengunggah...' : 'Mulai Import'}
        </button>
      </form>
    </div>
  );
}
