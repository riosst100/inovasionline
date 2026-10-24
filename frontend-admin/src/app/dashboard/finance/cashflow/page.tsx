'use client';

import React, { Suspense, use, useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { io } from 'next/cache';
import AdminLayout from '../../../../components/layout/AdminLayout';
import PeriodFilter, { Period, thisMonth } from '../../../../components/finance/PeriodFilter';
import Stat, { signedRupiah } from '../../../../components/finance/Stat';
import SearchableSelect from '../../../../components/ui/SearchableSelect';
import { apiRequest, apiRequestFull, ApiError } from '../../../../lib/api';
import { rupiah, todayWib } from '../../../../lib/wallet';
import { CashBook, CashEntry, CashSource, CashType, Employee, EmployeeList, PaginationMeta } from '../../../../types';
import {
  AlertCircle,
  ArrowDownLeft,
  ArrowUpRight,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Loader2,
  Pencil,
  Plus,
  Scale,
  Trash2,
  X,
} from 'lucide-react';

const SOURCE_LABEL: Record<CashSource, string> = {
  order: 'Penjualan',
  supplier_bill: 'Tagihan supplier',
  manual: 'Dicatat manual',
};

const formatDate = (d: string) =>
  new Date(`${d.slice(0, 10)}T00:00:00`).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });

const firstError = (err: unknown, fallback: string) =>
  (err instanceof ApiError && err.errors && Object.values(err.errors)[0]?.[0]) || (err instanceof ApiError ? err.message : fallback);

// The date presets read "today" during render, so keep it out of the prerendered shell.
export default function CashflowPage() {
  return (
    <Suspense>
      <CashflowContent />
    </Suspense>
  );
}

function CashflowContent() {
  use(io());
  const [period, setPeriod] = useState<Period>(thisMonth);
  const [type, setType] = useState<CashType | ''>('');
  const [source, setSource] = useState<CashSource | ''>('');
  const [page, setPage] = useState(1);
  const [book, setBook] = useState<CashBook | null>(null);
  const [meta, setMeta] = useState<PaginationMeta | null>(null);
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [editing, setEditing] = useState<{ type: CashType; entry: CashEntry | null } | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ date_from: period.from, date_to: period.to, per_page: '25', page: String(page) });
      if (type) params.set('type', type);
      if (source) params.set('source', source);
      const res = await apiRequestFull<CashBook>(`/admin/company-transactions?${params}`);
      setBook(res.data);
      setMeta(res.meta ?? null);
    } catch (e) {
      setError(firstError(e, 'Gagal memuat cashflow.'));
    } finally {
      setLoading(false);
    }
  }, [period, type, source, page]);

  useEffect(() => {
    const t = setTimeout(load, 300);
    return () => clearTimeout(t);
  }, [load]);

  useEffect(() => {
    apiRequest<EmployeeList>('/admin/employees')
      .then((d) => setEmployees(d.items))
      .catch(() => {});
  }, []);

  const filter = (next: () => void) => {
    next();
    setPage(1);
  };

  const remove = async (e: CashEntry) => {
    if (!confirm(`Hapus ${e.type === 'income' ? 'pemasukan' : 'pengeluaran'} "${e.category}" ${rupiah(e.amount)}?`)) return;
    setBusyId(e.id);
    setError(null);
    setSuccess(null);
    try {
      await apiRequest(`/admin/company-transactions/${e.id}`, { method: 'DELETE' });
      setSuccess('Transaksi berhasil dihapus.');
      await load();
    } catch (err) {
      setError(firstError(err, 'Gagal menghapus transaksi.'));
    } finally {
      setBusyId(null);
    }
  };

  const s = book?.summary;
  const income = book?.by_category.filter((c) => c.type === 'income') ?? [];
  const expense = book?.by_category.filter((c) => c.type === 'expense') ?? [];
  const input = 'rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500';

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <div className="flex items-center gap-2">
              <Scale className="h-6 w-6 text-emerald-600" />
              <h1 className="text-2xl font-bold text-slate-900">Cashflow</h1>
            </div>
            <p className="mt-1 text-sm text-slate-500">
              Buku kas perusahaan: penjualan yang dibayar dan tagihan supplier yang dilunasi tercatat otomatis; biaya operasional
              dan pemasukan lain dicatat manual.
            </p>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => {
                setSuccess(null);
                setEditing({ type: 'income', entry: null });
              }}
              className="inline-flex items-center gap-2 rounded-xl border border-emerald-200 bg-white px-4 py-2 text-sm font-semibold text-emerald-700 hover:bg-emerald-50"
            >
              <Plus className="h-4 w-4" /> Pemasukan
            </button>
            <button
              onClick={() => {
                setSuccess(null);
                setEditing({ type: 'expense', entry: null });
              }}
              className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
            >
              <Plus className="h-4 w-4" /> Pengeluaran
            </button>
          </div>
        </div>

        <PeriodFilter value={period} onChange={(p) => filter(() => setPeriod(p))} />

        {error && !editing && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        )}
        {success && (
          <div className="flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-700">
            <CheckCircle2 className="h-4 w-4" /> {success}
          </div>
        )}

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <Stat label="Pemasukan" value={s ? '+' + rupiah(s.income) : '—'} tone="in" />
          <Stat label="Pengeluaran" value={s ? '−' + rupiah(s.expense) : '—'} tone="out" />
          <Stat label="Selisih (bersih)" value={s ? signedRupiah(s.net) : '—'} tone={s && s.net < 0 ? 'out' : 'in'} />
        </div>

        <div className="grid gap-4 lg:grid-cols-2">
          <CategoryPanel title="Pemasukan per kategori" icon={<ArrowDownLeft className="h-4 w-4 text-emerald-600" />} rows={income} total={s?.income ?? 0} bar="bg-emerald-500" />
          <CategoryPanel title="Pengeluaran per kategori" icon={<ArrowUpRight className="h-4 w-4 text-rose-600" />} rows={expense} total={s?.expense ?? 0} bar="bg-rose-500" />
        </div>

        <section className="space-y-3">
          <div className="flex flex-wrap items-center gap-3">
            <div className="flex rounded-lg border border-slate-200 bg-white p-0.5 text-sm">
              {([['', 'Semua'], ['income', 'Pemasukan'], ['expense', 'Pengeluaran']] as [CashType | '', string][]).map(([v, label]) => (
                <button
                  key={v}
                  type="button"
                  onClick={() => filter(() => setType(v))}
                  className={`rounded-md px-3 py-1.5 font-medium ${type === v ? 'bg-emerald-600 text-white' : 'text-slate-600 hover:bg-slate-50'}`}
                >
                  {label}
                </button>
              ))}
            </div>
            <select className={input} value={source} onChange={(e) => filter(() => setSource(e.target.value as CashSource | ''))}>
              <option value="">Semua sumber</option>
              {Object.entries(SOURCE_LABEL).map(([v, label]) => (
                <option key={v} value={v}>
                  {label}
                </option>
              ))}
            </select>
          </div>

          <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
            {loading && !book ? (
              <div className="flex justify-center p-10">
                <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
              </div>
            ) : !book || book.entries.length === 0 ? (
              <p className="p-10 text-center text-sm text-slate-400">Tidak ada transaksi pada periode ini.</p>
            ) : (
              <table className={`w-full text-sm ${loading ? 'opacity-60' : ''}`}>
                <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                  <tr>
                    <th className="px-4 py-3">Tanggal</th>
                    <th className="px-4 py-3">Kategori</th>
                    <th className="px-4 py-3">Keterangan</th>
                    <th className="px-4 py-3">Sumber</th>
                    <th className="px-4 py-3 text-right">Nominal</th>
                    <th className="px-4 py-3" />
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {book.entries.map((e) => (
                    <tr key={`${e.source}-${e.id}`} className="align-top">
                      <td className="whitespace-nowrap px-4 py-3 text-slate-500">{formatDate(e.date)}</td>
                      <td className="px-4 py-3 font-medium text-slate-800">{e.category}</td>
                      <td className="px-4 py-3 text-slate-600">
                        <EntryDescription entry={e} />
                      </td>
                      <td className="px-4 py-3 text-xs text-slate-500">{SOURCE_LABEL[e.source]}</td>
                      <td className={`whitespace-nowrap px-4 py-3 text-right font-semibold ${e.type === 'income' ? 'text-emerald-600' : 'text-rose-600'}`}>
                        {e.type === 'income' ? '+' : '−'}
                        {rupiah(e.amount)}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-right">
                        {e.source === 'manual' && (
                          <>
                            <button
                              onClick={() => {
                                setSuccess(null);
                                setEditing({ type: e.type, entry: e });
                              }}
                              title="Ubah"
                              className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
                            >
                              <Pencil className="h-4 w-4" />
                            </button>
                            <button
                              onClick={() => remove(e)}
                              disabled={busyId !== null}
                              title="Hapus"
                              className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-50"
                            >
                              {busyId === e.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
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
                Halaman {meta.current_page} dari {meta.last_page} · {meta.total} transaksi
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
        </section>
      </div>

      {editing && book && (
        <EntryForm
          type={editing.type}
          entry={editing.entry}
          categories={book.categories[editing.type]}
          employees={employees}
          onClose={() => setEditing(null)}
          onSaved={async (message) => {
            setEditing(null);
            setSuccess(message);
            await load();
          }}
        />
      )}
    </AdminLayout>
  );
}

function EntryDescription({ entry: e }: { entry: CashEntry }) {
  if (e.source === 'order') {
    return (
      <>
        <span className="font-medium text-slate-800">{e.reference}</span>
        {e.description && <p className="text-xs text-slate-400">{e.description}</p>}
      </>
    );
  }
  if (e.source === 'supplier_bill') {
    return (
      <>
        <Link href="/dashboard/finance/bills" className="font-medium text-slate-800 hover:text-emerald-700">
          {e.reference}
        </Link>
        {e.description && <p className="text-xs text-slate-400">{e.description}</p>}
      </>
    );
  }
  return (
    <>
      {e.description ?? (e.employee_name ? null : '—')}
      {e.employee_name && <p className="text-xs text-slate-500">Karyawan: {e.employee_name}</p>}
    </>
  );
}

function CategoryPanel({
  title,
  icon,
  rows,
  total,
  bar,
}: {
  title: string;
  icon: React.ReactNode;
  rows: { category: string; total: number; count: number }[];
  total: number;
  bar: string;
}) {
  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
      <p className="mb-3 flex items-center gap-2 font-semibold text-slate-800">
        {icon} {title}
      </p>
      {rows.length === 0 ? (
        <p className="text-sm text-slate-400">Tidak ada data.</p>
      ) : (
        <div className="space-y-2.5">
          {rows.map((r) => (
            <div key={r.category}>
              <div className="flex items-center justify-between text-sm">
                <span className="text-slate-700">
                  {r.category} <span className="text-xs text-slate-400">· {r.count}x</span>
                </span>
                <span className="font-semibold text-slate-900">{rupiah(r.total)}</span>
              </div>
              <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-slate-100">
                <div className={`h-full rounded-full ${bar}`} style={{ width: `${total > 0 ? (r.total / total) * 100 : 0}%` }} />
              </div>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}

function EntryForm({
  type,
  entry,
  categories,
  employees,
  onClose,
  onSaved,
}: {
  type: CashType;
  entry: CashEntry | null;
  categories: string[];
  employees: Employee[];
  onClose: () => void;
  onSaved: (message: string) => void;
}) {
  const [category, setCategory] = useState(entry?.category ?? '');
  const [amount, setAmount] = useState(entry ? String(Math.round(entry.amount)) : '');
  const [date, setDate] = useState(entry?.date.slice(0, 10) ?? todayWib());
  const [description, setDescription] = useState(entry?.description ?? '');
  const [employeeId, setEmployeeId] = useState(entry?.employee_id ?? '');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const label = type === 'income' ? 'Pemasukan' : 'Pengeluaran';

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      await apiRequest(entry ? `/admin/company-transactions/${entry.id}` : '/admin/company-transactions', {
        method: entry ? 'PUT' : 'POST',
        body: JSON.stringify({
          type,
          category: category.trim(),
          amount: Number(amount),
          transaction_date: date,
          description: description.trim() || null,
          employee_id: type === 'expense' && employeeId ? employeeId : null,
        }),
      });
      onSaved(entry ? 'Transaksi berhasil diperbarui.' : `${label} berhasil dicatat.`);
    } catch (err) {
      setError(firstError(err, 'Gagal menyimpan transaksi.'));
    } finally {
      setSaving(false);
    }
  };

  const inputCls = 'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/50 p-4">
      <form onSubmit={submit} className="max-h-[90vh] w-full max-w-md space-y-4 overflow-y-auto rounded-2xl bg-white p-6 shadow-xl">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-bold text-slate-900">
            {entry ? 'Ubah' : 'Catat'} {label}
          </h2>
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
          <label className="mb-1 block text-xs font-medium text-slate-600">Kategori</label>
          <input
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            required
            maxLength={60}
            list="cash-categories"
            placeholder={type === 'income' ? 'mis. Pemasukan Lain' : 'mis. Gaji Karyawan, Sewa'}
            className={inputCls}
          />
          <datalist id="cash-categories">
            {categories.map((c) => (
              <option key={c} value={c} />
            ))}
          </datalist>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Nominal</label>
            <div className="relative">
              <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-sm text-slate-400">Rp</span>
              <input
                inputMode="numeric"
                required
                value={amount ? Number(amount).toLocaleString('id-ID') : ''}
                onChange={(e) => setAmount(e.target.value.replace(/\D/g, ''))}
                className={`${inputCls} pl-9`}
              />
            </div>
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Tanggal</label>
            <input type="date" value={date} onChange={(e) => setDate(e.target.value)} required className={inputCls} />
          </div>
        </div>

        {type === 'expense' && (
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Karyawan (opsional, mis. untuk gaji)</label>
            <SearchableSelect
              value={employeeId}
              onChange={setEmployeeId}
              options={employees
                .filter((em) => em.is_active || em.id === entry?.employee_id)
                .map((em) => ({ value: em.id, label: `${em.name} · ${em.position}` }))}
              emptyLabel="- Tidak terkait karyawan -"
            />
          </div>
        )}

        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">Keterangan (opsional)</label>
          <input value={description} onChange={(e) => setDescription(e.target.value)} maxLength={255} className={inputCls} />
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
