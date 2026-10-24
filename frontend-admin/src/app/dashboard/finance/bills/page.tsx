'use client';

import React, { Suspense, use, useCallback, useEffect, useState } from 'react';
import { io } from 'next/cache';
import AdminLayout from '../../../../components/layout/AdminLayout';
import SearchableSelect from '../../../../components/ui/SearchableSelect';
import Stat from '../../../../components/finance/Stat';
import { adminApi, apiRequest, apiRequestFull, ApiError } from '../../../../lib/api';
import { rupiah, todayWib } from '../../../../lib/wallet';
import { PaginationMeta, Supplier, SupplierBill, SupplierBillStatus, SupplierBillSummary } from '../../../../types';
import {
  AlertCircle,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Loader2,
  Pencil,
  Plus,
  ReceiptText,
  RotateCcw,
  Search,
  Trash2,
  Wallet,
  X,
} from 'lucide-react';

const STATUS: Record<SupplierBillStatus, { label: string; badge: string }> = {
  unpaid: { label: 'Belum lunas', badge: 'bg-amber-50 text-amber-700 ring-amber-200' },
  overdue: { label: 'Lewat jatuh tempo', badge: 'bg-rose-50 text-rose-700 ring-rose-200' },
  paid: { label: 'Lunas', badge: 'bg-emerald-50 text-emerald-700 ring-emerald-200' },
};

const formatDate = (d: string | null) =>
  d ? new Date(`${d.slice(0, 10)}T00:00:00`).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' }) : '—';

type FormState = { supplier_id: string; bill_number: string; bill_date: string; due_date: string; amount: string; notes: string };

const toDigits = (v: string) => v.replace(/\D/g, '');

const firstError = (err: unknown, fallback: string) =>
  (err instanceof ApiError && err.errors && Object.values(err.errors)[0]?.[0]) || (err instanceof ApiError ? err.message : fallback);

// The form defaults read "today" during render, so keep it out of the prerendered shell.
export default function SupplierBillsPage() {
  return (
    <Suspense>
      <SupplierBillsContent />
    </Suspense>
  );
}

function SupplierBillsContent() {
  use(io());
  const [bills, setBills] = useState<SupplierBill[]>([]);
  const [meta, setMeta] = useState<PaginationMeta | null>(null);
  const [summary, setSummary] = useState<SupplierBillSummary | null>(null);
  const [suppliers, setSuppliers] = useState<Supplier[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [status, setStatus] = useState<SupplierBillStatus | ''>('');
  const [supplierId, setSupplierId] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [editing, setEditing] = useState<SupplierBill | 'new' | null>(null);
  const [paying, setPaying] = useState<SupplierBill | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ per_page: '20', page: String(page) });
      if (status) params.set('status', status);
      if (supplierId) params.set('supplier_id', supplierId);
      if (search.trim()) params.set('search', search.trim());
      const res = await apiRequestFull<SupplierBill[]>(`/admin/supplier-bills?${params}`);
      setBills(res.data ?? []);
      setMeta(res.meta ?? null);
      setSummary((res.meta?.summary as SupplierBillSummary | undefined) ?? null);
    } catch (e) {
      setError(firstError(e, 'Gagal memuat tagihan.'));
    } finally {
      setLoading(false);
    }
  }, [status, supplierId, search, page]);

  useEffect(() => {
    const t = setTimeout(load, 300);
    return () => clearTimeout(t);
  }, [load]);

  useEffect(() => {
    adminApi.getSuppliers().then(setSuppliers).catch(() => {});
  }, []);

  const filter = (next: () => void) => {
    next();
    setPage(1);
  };

  const done = async (message: string) => {
    setSuccess(message);
    await load();
  };

  const unpay = async (b: SupplierBill) => {
    if (!confirm(`Batalkan status lunas tagihan ${b.bill_number}?`)) return;
    setBusyId(b.id);
    setError(null);
    setSuccess(null);
    try {
      await apiRequest(`/admin/supplier-bills/${b.id}/unpay`, { method: 'POST' });
      await done('Status lunas dibatalkan.');
    } catch (e) {
      setError(firstError(e, 'Gagal membatalkan status lunas.'));
    } finally {
      setBusyId(null);
    }
  };

  const remove = async (b: SupplierBill) => {
    if (!confirm(`Hapus tagihan ${b.bill_number} dari ${b.supplier_name}?`)) return;
    setBusyId(b.id);
    setError(null);
    setSuccess(null);
    try {
      await apiRequest(`/admin/supplier-bills/${b.id}`, { method: 'DELETE' });
      await done('Tagihan berhasil dihapus.');
    } catch (e) {
      setError(firstError(e, 'Gagal menghapus tagihan.'));
    } finally {
      setBusyId(null);
    }
  };

  const input = 'rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500';

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <div className="flex items-center gap-2">
              <ReceiptText className="h-6 w-6 text-emerald-600" />
              <h1 className="text-2xl font-bold text-slate-900">Pembelian Barang</h1>
            </div>
            <p className="mt-1 text-sm text-slate-500">Hutang platform ke supplier: catat tagihan, pantau jatuh tempo, dan tandai lunas.</p>
          </div>
          <button
            onClick={() => {
              setSuccess(null);
              setEditing('new');
            }}
            className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
          >
            <Plus className="h-4 w-4" /> Tambah Tagihan
          </button>
        </div>

        <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          <Stat label="Belum lunas" value={summary ? rupiah(summary.outstanding) : '—'} hint={summary ? `${summary.outstanding_count} tagihan` : ''} />
          <Stat
            label="Lewat jatuh tempo"
            value={summary ? rupiah(summary.overdue) : '—'}
            tone={summary && summary.overdue > 0 ? 'out' : undefined}
            hint={summary ? `${summary.overdue_count} tagihan` : ''}
          />
          <Stat
            label={summary ? `Jatuh tempo ≤ ${summary.due_soon_days} hari` : 'Segera jatuh tempo'}
            value={summary ? rupiah(summary.due_soon) : '—'}
            tone={summary && summary.due_soon > 0 ? 'warn' : undefined}
            hint={summary ? `${summary.due_soon_count} tagihan` : ''}
          />
          <Stat label="Dibayar bulan ini" value={summary ? rupiah(summary.paid_this_month) : '—'} tone="in" />
        </div>

        {error && !editing && !paying && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        )}
        {success && (
          <div className="flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-700">
            <CheckCircle2 className="h-4 w-4" /> {success}
          </div>
        )}

        <div className="flex flex-wrap items-center gap-3">
          <div className="flex rounded-lg border border-slate-200 bg-white p-0.5 text-sm">
            {([['', 'Semua'], ['overdue', 'Lewat tempo'], ['unpaid', 'Belum lunas'], ['paid', 'Lunas']] as [SupplierBillStatus | '', string][]).map(([v, label]) => (
              <button
                key={v}
                type="button"
                onClick={() => filter(() => setStatus(v))}
                className={`rounded-md px-3 py-1.5 font-medium ${status === v ? 'bg-emerald-600 text-white' : 'text-slate-600 hover:bg-slate-50'}`}
              >
                {label}
              </button>
            ))}
          </div>
          <div className="w-56">
            <SearchableSelect
              value={supplierId}
              onChange={(v) => filter(() => setSupplierId(v))}
              options={suppliers.map((s) => ({ value: s.id, label: s.name }))}
              emptyLabel="Semua supplier"
            />
          </div>
          <div className="relative min-w-[220px] flex-1">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <input
              className={`${input} w-full pl-9`}
              placeholder="Cari nomor tagihan atau supplier"
              value={search}
              onChange={(e) => filter(() => setSearch(e.target.value))}
            />
          </div>
        </div>

        <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading && bills.length === 0 ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : bills.length === 0 ? (
            <p className="p-10 text-center text-sm text-slate-400">Belum ada tagihan.</p>
          ) : (
            <table className={`w-full text-sm ${loading ? 'opacity-60' : ''}`}>
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">Tagihan</th>
                  <th className="px-4 py-3">Supplier</th>
                  <th className="px-4 py-3">Tanggal</th>
                  <th className="px-4 py-3">Jatuh tempo</th>
                  <th className="px-4 py-3 text-right">Nominal</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {bills.map((b) => (
                  <tr key={b.id} className="align-top">
                    <td className="px-4 py-3">
                      <p className="font-medium text-slate-900">{b.bill_number}</p>
                      {b.notes && <p className="text-xs text-slate-400">{b.notes}</p>}
                    </td>
                    <td className="px-4 py-3 text-slate-700">{b.supplier_name ?? '—'}</td>
                    <td className="whitespace-nowrap px-4 py-3 text-slate-600">{formatDate(b.bill_date)}</td>
                    <td className={`whitespace-nowrap px-4 py-3 ${b.status === 'overdue' ? 'font-semibold text-rose-700' : 'text-slate-600'}`}>
                      {formatDate(b.due_date)}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right font-semibold text-slate-900">{rupiah(b.amount)}</td>
                    <td className="px-4 py-3">
                      <span className={`inline-flex rounded-full px-2 py-0.5 text-xs font-semibold ring-1 ${STATUS[b.status].badge}`}>
                        {STATUS[b.status].label}
                      </span>
                      {b.paid_at && (
                        <p className="mt-1 text-xs text-slate-500">
                          {formatDate(b.paid_at)}
                          {b.payment_notes && ` · ${b.payment_notes}`}
                        </p>
                      )}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right">
                      {b.status === 'paid' ? (
                        <button
                          onClick={() => unpay(b)}
                          disabled={busyId !== null}
                          title="Batalkan lunas"
                          className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700 disabled:opacity-50"
                        >
                          {busyId === b.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <RotateCcw className="h-4 w-4" />}
                        </button>
                      ) : (
                        <>
                          <button
                            onClick={() => {
                              setSuccess(null);
                              setPaying(b);
                            }}
                            className="mr-1 inline-flex items-center gap-1 rounded-lg border border-emerald-200 px-2.5 py-1 text-xs font-semibold text-emerald-700 hover:bg-emerald-50"
                          >
                            <Wallet className="h-3.5 w-3.5" /> Bayar
                          </button>
                          <button
                            onClick={() => {
                              setSuccess(null);
                              setEditing(b);
                            }}
                            title="Ubah"
                            className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
                          >
                            <Pencil className="h-4 w-4" />
                          </button>
                          <button
                            onClick={() => remove(b)}
                            disabled={busyId !== null}
                            title="Hapus"
                            className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-50"
                          >
                            {busyId === b.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
                          </button>
                        </>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {meta && meta.last_page > 1 && (
          <div className="flex items-center justify-between text-xs text-slate-500">
            <span>
              Halaman {meta.current_page} dari {meta.last_page} · {meta.total} tagihan
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

      {editing && (
        <BillForm
          bill={editing === 'new' ? null : editing}
          suppliers={suppliers}
          onClose={() => setEditing(null)}
          onSaved={async (message) => {
            setEditing(null);
            await done(message);
          }}
        />
      )}

      {paying && (
        <PayDialog
          bill={paying}
          onClose={() => setPaying(null)}
          onPaid={async () => {
            setPaying(null);
            await done('Tagihan ditandai lunas.');
          }}
        />
      )}
    </AdminLayout>
  );
}

function BillForm({
  bill,
  suppliers,
  onClose,
  onSaved,
}: {
  bill: SupplierBill | null;
  suppliers: Supplier[];
  onClose: () => void;
  onSaved: (message: string) => void;
}) {
  const [form, setForm] = useState<FormState>(() => ({
    supplier_id: bill?.supplier_id ?? '',
    bill_number: bill?.bill_number ?? '',
    bill_date: bill?.bill_date ?? todayWib(),
    due_date: bill?.due_date ?? '',
    amount: bill ? String(Math.round(bill.amount)) : '',
    notes: bill?.notes ?? '',
  }));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Inactive suppliers stay selectable only for the bill that already uses one.
  const options = suppliers
    .filter((s) => s.is_active || s.id === bill?.supplier_id)
    .map((s) => ({ value: s.id, label: s.name }));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.supplier_id) {
      setError('Pilih supplier.');
      return;
    }
    setSaving(true);
    setError(null);
    try {
      await apiRequest(bill ? `/admin/supplier-bills/${bill.id}` : '/admin/supplier-bills', {
        method: bill ? 'PUT' : 'POST',
        body: JSON.stringify({
          supplier_id: form.supplier_id,
          bill_number: form.bill_number.trim(),
          bill_date: form.bill_date,
          due_date: form.due_date || null,
          amount: Number(form.amount),
          notes: form.notes.trim() || null,
        }),
      });
      onSaved(bill ? 'Tagihan berhasil diperbarui.' : 'Tagihan berhasil ditambahkan.');
    } catch (err) {
      setError(firstError(err, 'Gagal menyimpan tagihan.'));
    } finally {
      setSaving(false);
    }
  };

  const inputCls = 'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/50 p-4">
      <form onSubmit={submit} className="max-h-[90vh] w-full max-w-lg space-y-4 overflow-y-auto rounded-2xl bg-white p-6 shadow-xl">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-bold text-slate-900">{bill ? 'Ubah Tagihan' : 'Tambah Tagihan'}</h2>
          <button type="button" onClick={onClose} className="rounded-lg p-1 text-slate-400 hover:bg-slate-100">
            <X className="h-5 w-5" />
          </button>
        </div>

        {error && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4 shrink-0" /> {error}
          </div>
        )}

        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">Supplier</label>
          <SearchableSelect
            value={form.supplier_id}
            onChange={(v) => setForm({ ...form, supplier_id: v })}
            options={options}
            placeholder="Pilih supplier"
          />
          {suppliers.length === 0 && <p className="mt-1 text-[11px] text-slate-400">Belum ada supplier. Tambahkan di Master Data → Supplier.</p>}
        </div>

        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">Nomor Tagihan / Invoice</label>
          <input
            value={form.bill_number}
            onChange={(e) => setForm({ ...form, bill_number: e.target.value })}
            required
            maxLength={60}
            placeholder="mis. INV/2026/10/001"
            className={inputCls}
          />
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Tanggal Tagihan</label>
            <input type="date" value={form.bill_date} onChange={(e) => setForm({ ...form, bill_date: e.target.value })} required className={inputCls} />
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Jatuh Tempo (opsional)</label>
            <input
              type="date"
              value={form.due_date}
              min={form.bill_date}
              onChange={(e) => setForm({ ...form, due_date: e.target.value })}
              className={inputCls}
            />
          </div>
        </div>

        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">Nominal</label>
          <div className="relative">
            <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-sm text-slate-400">Rp</span>
            <input
              inputMode="numeric"
              required
              value={form.amount ? Number(form.amount).toLocaleString('id-ID') : ''}
              onChange={(e) => setForm({ ...form, amount: toDigits(e.target.value) })}
              className={`${inputCls} pl-9`}
            />
          </div>
        </div>

        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">Catatan (opsional)</label>
          <input value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} maxLength={255} className={inputCls} />
        </div>

        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={onClose} className="rounded-xl border border-slate-200 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50">
            Batal
          </button>
          <button
            type="submit"
            disabled={saving}
            className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
          >
            {saving && <Loader2 className="h-4 w-4 animate-spin" />}
            Simpan
          </button>
        </div>
      </form>
    </div>
  );
}

function PayDialog({ bill, onClose, onPaid }: { bill: SupplierBill; onClose: () => void; onPaid: () => void }) {
  const [paidDate, setPaidDate] = useState(todayWib);
  const [notes, setNotes] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      await apiRequest(`/admin/supplier-bills/${bill.id}/pay`, {
        method: 'POST',
        body: JSON.stringify({ paid_date: paidDate, payment_notes: notes.trim() || null }),
      });
      onPaid();
    } catch (err) {
      setError(firstError(err, 'Gagal menandai lunas.'));
    } finally {
      setSaving(false);
    }
  };

  const inputCls = 'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/50 p-4">
      <form onSubmit={submit} className="w-full max-w-md space-y-4 rounded-2xl bg-white p-6 shadow-xl">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-bold text-slate-900">Tandai Lunas</h2>
          <button type="button" onClick={onClose} className="rounded-lg p-1 text-slate-400 hover:bg-slate-100">
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="rounded-xl bg-slate-50 p-3 text-sm">
          <p className="font-semibold text-slate-900">
            {bill.bill_number} · {bill.supplier_name}
          </p>
          <p className="mt-0.5 text-lg font-bold text-slate-900">{rupiah(bill.amount)}</p>
        </div>

        {error && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4 shrink-0" /> {error}
          </div>
        )}

        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">Tanggal Bayar</label>
          <input type="date" value={paidDate} max={todayWib()} onChange={(e) => setPaidDate(e.target.value)} required className={inputCls} />
        </div>
        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">Keterangan (opsional)</label>
          <input
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            maxLength={255}
            placeholder="mis. Transfer BCA, ref 12345"
            className={inputCls}
          />
        </div>

        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={onClose} className="rounded-xl border border-slate-200 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50">
            Batal
          </button>
          <button
            type="submit"
            disabled={saving}
            className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
          >
            {saving && <Loader2 className="h-4 w-4 animate-spin" />}
            Tandai Lunas
          </button>
        </div>
      </form>
    </div>
  );
}
