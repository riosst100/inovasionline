'use client';

import React, { Suspense, use, useCallback, useEffect, useState } from 'react';
import { io } from 'next/cache';
import AdminLayout from '../../../../components/layout/AdminLayout';
import PeriodFilter, { Period, thisMonth } from '../../../../components/finance/PeriodFilter';
import Stat, { signedRupiah } from '../../../../components/finance/Stat';
import { apiRequest, ApiError } from '../../../../lib/api';
import { rupiah } from '../../../../lib/wallet';
import { ProfitGroup, ProfitReport } from '../../../../types';
import { AlertCircle, Loader2, TrendingUp } from 'lucide-react';

const GROUPS: { value: ProfitGroup; label: string; column: string }[] = [
  { value: 'product', label: 'Produk', column: 'Produk' },
  { value: 'category', label: 'Kategori', column: 'Kategori' },
  { value: 'supplier', label: 'Supplier', column: 'Supplier' },
  { value: 'brand', label: 'Brand', column: 'Brand' },
];

// The date presets read "today" during render, so keep it out of the prerendered shell.
export default function ProfitPage() {
  return (
    <Suspense>
      <ProfitContent />
    </Suspense>
  );
}

function ProfitContent() {
  use(io());
  const [period, setPeriod] = useState<Period>(thisMonth);
  const [group, setGroup] = useState<ProfitGroup>('product');
  const [report, setReport] = useState<ProfitReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ date_from: period.from, date_to: period.to, group });
      setReport(await apiRequest<ProfitReport>(`/admin/finance/profit?${params}`));
    } catch (e) {
      setError(e instanceof ApiError ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message : 'Gagal memuat laporan keuntungan.');
    } finally {
      setLoading(false);
    }
  }, [period, group]);

  useEffect(() => {
    const t = setTimeout(load, 300);
    return () => clearTimeout(t);
  }, [load]);

  const t = report?.totals;
  const column = GROUPS.find((g) => g.value === group)?.column ?? '';

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div>
          <div className="flex items-center gap-2">
            <TrendingUp className="h-6 w-6 text-emerald-600" />
            <h1 className="text-2xl font-bold text-slate-900">Keuntungan</h1>
          </div>
          <p className="mt-1 text-sm text-slate-500">
            Laba kotor = penjualan produk − diskon − HPP. HPP memakai harga modal saat checkout, atau harga modal produk saat ini
            untuk pesanan lama.
          </p>
        </div>

        <PeriodFilter value={period} onChange={setPeriod} />

        {error && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        )}

        <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          <Stat label="Penjualan bersih" value={t ? rupiah(t.net_sales) : '—'} hint={t ? `Diskon ${rupiah(t.discount)}` : ''} />
          <Stat label="HPP" value={t ? rupiah(t.cost) : '—'} hint={t ? `${t.items_sold.toLocaleString('id-ID')} unit terjual` : ''} />
          <Stat label="Laba kotor" value={t ? signedRupiah(t.gross_profit) : '—'} tone={t && t.gross_profit < 0 ? 'out' : 'in'} />
          <Stat label="Margin" value={t ? `${t.margin}%` : '—'} hint="Dari penjualan bersih" />
        </div>

        {t && t.items_without_cost > 0 && (
          <p className="rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
            {t.items_without_cost.toLocaleString('id-ID')} unit terjual belum punya harga modal. Laba baris yang terdampak ditampilkan
            &quot;—&quot; dan totalnya belum lengkap.
          </p>
        )}

        <section className="space-y-3">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex rounded-lg border border-slate-200 bg-white p-0.5 text-sm">
              {GROUPS.map((g) => (
                <button
                  key={g.value}
                  type="button"
                  onClick={() => setGroup(g.value)}
                  className={`rounded-md px-3 py-1.5 font-medium ${group === g.value ? 'bg-emerald-600 text-white' : 'text-slate-600 hover:bg-slate-50'}`}
                >
                  Per {g.label}
                </button>
              ))}
            </div>
            <p className="text-xs text-slate-400">
              Diskon pesanan tidak dibagi per baris{group !== 'product' ? '; pengelompokan memakai data produk saat ini' : ''}.
            </p>
          </div>

          <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
            {!report && loading ? (
              <div className="flex justify-center p-10">
                <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
              </div>
            ) : !report || report.rows.length === 0 ? (
              <p className="p-10 text-center text-sm text-slate-400">Tidak ada penjualan pada periode ini.</p>
            ) : (
              <table className={`w-full text-sm ${loading ? 'opacity-60' : ''}`}>
                <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                  <tr>
                    <th className="px-4 py-3">{column}</th>
                    <th className="px-4 py-3 text-right">Terjual</th>
                    <th className="px-4 py-3 text-right">Penjualan</th>
                    <th className="px-4 py-3 text-right">HPP</th>
                    <th className="px-4 py-3 text-right">Laba kotor</th>
                    <th className="px-4 py-3 text-right">Margin</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {report.rows.map((r) => (
                    <tr key={`${r.id ?? 'none'}-${r.name}`}>
                      <td className="px-4 py-3 font-medium text-slate-800">{r.name}</td>
                      <td className="px-4 py-3 text-right text-slate-600">{r.quantity.toLocaleString('id-ID')}</td>
                      <td className="px-4 py-3 text-right text-slate-800">{rupiah(r.revenue)}</td>
                      <td className="px-4 py-3 text-right text-slate-600">{r.cost === null ? '—' : rupiah(r.cost)}</td>
                      <td className={`px-4 py-3 text-right font-semibold ${r.profit !== null && r.profit < 0 ? 'text-rose-700' : 'text-emerald-700'}`}>
                        {r.profit === null ? <span title="Ada unit tanpa harga modal" className="text-slate-400">—</span> : signedRupiah(r.profit)}
                      </td>
                      <td className="px-4 py-3 text-right text-slate-600">{r.margin === null ? '—' : `${r.margin}%`}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
          {report && report.rows.length >= report.row_limit && (
            <p className="text-xs text-slate-400">Menampilkan {report.row_limit} baris dengan penjualan terbesar.</p>
          )}
        </section>
      </div>
    </AdminLayout>
  );
}
