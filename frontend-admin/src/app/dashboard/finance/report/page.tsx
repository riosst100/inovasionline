'use client';

import React, { Suspense, use, useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { io } from 'next/cache';
import AdminLayout from '../../../../components/layout/AdminLayout';
import PeriodFilter, { Period, thisMonth } from '../../../../components/finance/PeriodFilter';
import Stat, { signedRupiah } from '../../../../components/finance/Stat';
import { apiRequest, ApiError } from '../../../../lib/api';
import { rupiah } from '../../../../lib/wallet';
import { FinanceReport } from '../../../../types';
import { AlertCircle, ArrowRight, Landmark, Loader2 } from 'lucide-react';

// The date presets read "today" during render, so keep it out of the prerendered shell.
export default function FinanceReportPage() {
  return (
    <Suspense>
      <FinanceReportContent />
    </Suspense>
  );
}

function FinanceReportContent() {
  use(io());
  const [period, setPeriod] = useState<Period>(thisMonth);
  const [report, setReport] = useState<FinanceReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ date_from: period.from, date_to: period.to });
      setReport(await apiRequest<FinanceReport>(`/admin/finance/report?${params}`));
    } catch (e) {
      setError(e instanceof ApiError ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message : 'Gagal memuat laporan keuangan.');
    } finally {
      setLoading(false);
    }
  }, [period]);

  useEffect(() => {
    const t = setTimeout(load, 300);
    return () => clearTimeout(t);
  }, [load]);

  const is = report?.income_statement;
  const s = report?.sales;
  const money = (n: number | undefined) => (n === undefined ? '—' : rupiah(n));

  return (
    <AdminLayout>
      <div className={`space-y-6 ${loading && report ? 'opacity-70' : ''}`}>
        <div>
          <div className="flex items-center gap-2">
            <Landmark className="h-6 w-6 text-emerald-600" />
            <h1 className="text-2xl font-bold text-slate-900">Laporan Keuangan</h1>
          </div>
          <p className="mt-1 text-sm text-slate-500">
            Ringkasan keuangan platform per periode, berdasarkan tanggal pesanan (WIB). Pesanan batal tidak dihitung.
          </p>
        </div>

        <PeriodFilter value={period} onChange={setPeriod} />

        {error && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        )}

        {!report && loading ? (
          <div className="flex justify-center p-10">
            <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
          </div>
        ) : (
          <>
            <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
              <Stat label="Omzet" value={money(s?.total)} hint={s ? `${s.orders.toLocaleString('id-ID')} pesanan` : ''} />
              <Stat label="Laba kotor produk" value={is ? signedRupiah(is.gross_profit) : '—'} tone={is && is.gross_profit < 0 ? 'out' : 'in'} hint={is ? `Margin ${is.margin}%` : ''} />
              <Stat label="Laba bersih" value={is ? signedRupiah(is.net_income) : '—'} tone={is && is.net_income < 0 ? 'out' : 'in'} hint="Setelah biaya operasional yang dicatat" />
              <Stat label="Belum dibayar customer" value={money(s?.unpaid)} tone={s && s.unpaid > 0 ? 'warn' : undefined} hint="Dari pesanan periode ini" />
            </div>

            <div className="grid gap-4 lg:grid-cols-2">
              <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                <h2 className="font-semibold text-slate-800">Laba Rugi Ringkas</h2>
                <p className="mb-3 text-xs text-slate-400">
                  Biaya operasional & pemasukan lain diambil dari catatan di Cashflow (berdasarkan tanggal transaksi).
                </p>
                <dl className="space-y-2 text-sm">
                  <Line label="Penjualan produk" value={is?.product_sales} />
                  <Line label="Diskon pesanan" value={is && -is.discount} />
                  <Line label="Penjualan bersih" value={is?.net_sales} strong />
                  <Line label="Harga pokok penjualan (HPP)" value={is && -is.cost} />
                  <Line label="Laba kotor produk" value={is?.gross_profit} strong />
                  <Line label="Pendapatan ongkir" value={is?.shipping} />
                  <Line label="Pendapatan biaya layanan" value={is?.service_fee} />
                  <Line label="Pendapatan kotor platform" value={is?.gross_income} strong total />
                  <Line label="Pemasukan lain" value={is?.other_income} />
                  <Line label="Biaya operasional" value={is && -is.operating_expenses} />
                  <Line label="Laba bersih" value={is?.net_income} strong total />
                </dl>
                <Link href="/dashboard/finance/cashflow" className="mt-3 inline-flex items-center gap-1 text-xs font-semibold text-emerald-700 hover:underline">
                  Catat biaya operasional / pemasukan lain <ArrowRight className="h-3.5 w-3.5" />
                </Link>
                {is && is.items_without_cost > 0 && (
                  <p className="mt-3 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
                    {is.items_without_cost.toLocaleString('id-ID')} unit terjual belum punya harga modal, jadi HPP & laba belum lengkap.
                    Isi harga modal di produk.
                  </p>
                )}
              </section>

              <section className="space-y-4">
                <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                  <h2 className="mb-3 font-semibold text-slate-800">Penagihan Pesanan</h2>
                  <dl className="space-y-2 text-sm">
                    <Line label="Sudah dibayar" value={s?.paid} />
                    <Line label="Belum dibayar" value={s?.unpaid} />
                    {s && s.refunded > 0 && <Line label="Dikembalikan (refund)" value={s.refunded} />}
                    {s && s.tax > 0 && <Line label="Termasuk pajak" value={s.tax} />}
                  </dl>
                  <p className="mb-2 mt-4 text-xs font-semibold uppercase tracking-wide text-slate-500">Per metode pembayaran</p>
                  {report && report.by_payment_method.length === 0 ? (
                    <p className="text-sm text-slate-400">Belum ada pesanan.</p>
                  ) : (
                    <div className="divide-y divide-slate-100 rounded-xl border border-slate-100">
                      {report?.by_payment_method.map((m) => (
                        <div key={m.method} className="flex items-center justify-between gap-3 px-3 py-2 text-sm">
                          <span className="text-slate-700">
                            {m.method} <span className="text-xs text-slate-400">· {m.orders} pesanan</span>
                          </span>
                          <span className="text-right">
                            <span className="font-semibold text-slate-900">{rupiah(m.total)}</span>
                            {m.paid < m.total && <span className="block text-xs text-amber-700">belum dibayar {rupiah(m.total - m.paid)}</span>}
                          </span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                  <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                    <h2 className="mb-3 font-semibold text-slate-800">Saldo Belanja</h2>
                    <dl className="space-y-2 text-sm">
                      <Line label="Top up masuk" value={report?.wallet.topup} />
                      <Line label="Bonus & refund" value={report?.wallet.other_credit} />
                      <Line label="Dipakai belanja" value={report && -report.wallet.spent} />
                      <Line label="Total saldo customer" value={report?.wallet.total_balance} strong />
                    </dl>
                    <p className="mt-2 text-xs text-slate-400">Total saldo adalah dana titipan customer saat ini (kewajiban), bukan pendapatan.</p>
                    <Link href="/dashboard/wallet-report" className="mt-2 inline-flex items-center gap-1 text-xs font-semibold text-emerald-700 hover:underline">
                      Laporan saldo <ArrowRight className="h-3.5 w-3.5" />
                    </Link>
                  </div>

                  <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                    <h2 className="mb-3 font-semibold text-slate-800">Pembelian Barang</h2>
                    <dl className="space-y-2 text-sm">
                      <Line label="Tagihan masuk" value={report?.supplier_bills.billed} />
                      <Line label="Dibayar" value={report && -report.supplier_bills.paid} />
                      <Line label="Belum lunas (saat ini)" value={report?.supplier_bills.outstanding} strong />
                    </dl>
                    {report && report.supplier_bills.overdue > 0 && (
                      <p className="mt-2 text-xs font-medium text-rose-700">Lewat jatuh tempo: {rupiah(report.supplier_bills.overdue)}</p>
                    )}
                    <Link href="/dashboard/finance/bills" className="mt-2 inline-flex items-center gap-1 text-xs font-semibold text-emerald-700 hover:underline">
                      Kelola tagihan <ArrowRight className="h-3.5 w-3.5" />
                    </Link>
                  </div>
                </div>
              </section>
            </div>
          </>
        )}
      </div>
    </AdminLayout>
  );
}

function Line({ label, value, strong, total }: { label: string; value: number | null | undefined; strong?: boolean; total?: boolean }) {
  const v = value ?? undefined;
  return (
    <div className={`flex items-center justify-between gap-3 ${strong ? 'font-semibold text-slate-900' : 'text-slate-600'} ${total ? 'border-t border-slate-200 pt-2 text-base' : ''}`}>
      <dt>{label}</dt>
      <dd className={v !== undefined && v < 0 ? 'text-rose-700' : ''}>{v === undefined ? '—' : signedRupiah(v)}</dd>
    </div>
  );
}
