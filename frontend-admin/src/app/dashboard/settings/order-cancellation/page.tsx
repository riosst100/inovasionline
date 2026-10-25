'use client';

import React, { useEffect, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { OrderSettings } from '../../../../types';
import { AlertCircle, CheckCircle2, Loader2, Save } from 'lucide-react';

const DEFAULTS: OrderSettings = {
  buyer_cancel_window_seconds: 60,
  paylater_min_transactions: 3,
  paylater_due_days: 7,
  instant_dispatch_minutes: 30,
};

/** e.g. 90 -> "1 menit 30 detik" */
function describe(seconds: number): string {
  if (seconds <= 0) return 'Pembeli tidak bisa membatalkan setelah pesanan mulai disiapkan';
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  const parts = [m > 0 ? `${m} menit` : '', s > 0 ? `${s} detik` : ''].filter(Boolean);
  return `Pembeli bisa membatalkan dalam ${parts.join(' ')} setelah pesanan mulai disiapkan`;
}

export default function OrderCancellationPage() {
  const [form, setForm] = useState<OrderSettings>(DEFAULTS);
  const [initial, setInitial] = useState<string>(JSON.stringify(DEFAULTS));
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const load = (res: OrderSettings) => {
    setForm(res);
    setInitial(JSON.stringify(res));
  };

  useEffect(() => {
    (async () => {
      try {
        load(await adminApi.getOrderSettings());
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'Gagal memuat pengaturan pembatalan.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const seconds = form.buyer_cancel_window_seconds;
  const minTx = form.paylater_min_transactions;
  const dueDays = form.paylater_due_days;
  const validTx = Number.isInteger(minTx) && minTx >= 0 && minTx <= 1000;
  const validDue = Number.isInteger(dueDays) && dueDays >= 1 && dueDays <= 90;
  const dispatch = form.instant_dispatch_minutes;
  const validDispatch = Number.isInteger(dispatch) && dispatch >= 5 && dispatch <= 1440;
  const valid = Number.isInteger(seconds) && seconds >= 0 && seconds <= 86400 && validTx && validDue && validDispatch;
  const dirty = JSON.stringify(form) !== initial;

  const save = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      load(await adminApi.saveOrderSettings(form));
      setSuccess('Pengaturan pembatalan pesanan berhasil disimpan.');
    } catch (e) {
      setError(
        e instanceof ApiError
          ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message
          : 'Gagal menyimpan pengaturan pembatalan.'
      );
    } finally {
      setSaving(false);
    }
  };

  const input =
    'w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500';

  return (
    <AdminLayout>
      <div className="mx-auto max-w-3xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Pembatalan Pesanan</h1>
            <p className="text-sm text-slate-500">
              Batas waktu pembeli masih boleh membatalkan pesanan saat pesanan sedang disiapkan / dikemas.
            </p>
          </div>
          <button
            type="button"
            onClick={save}
            disabled={saving || loading || !dirty || !valid}
            className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
          >
            {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
            Simpan
          </button>
        </div>

        {error && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        )}
        {success && (
          <div className="flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-700">
            <CheckCircle2 className="h-4 w-4" /> {success}
          </div>
        )}

        {loading ? (
          <div className="flex justify-center p-10">
            <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
          </div>
        ) : (
          <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <div>
              <label className="mb-1 block text-sm font-medium text-slate-700">Batas waktu pembatalan (detik)</label>
              <input
                type="number"
                min={0}
                max={86400}
                step={1}
                className={input}
                value={Number.isNaN(seconds) ? '' : seconds}
                onChange={(e) => {
                  setSuccess(null);
                  setForm({ ...form, buyer_cancel_window_seconds: e.target.value === '' ? NaN : Number(e.target.value) });
                }}
              />
              <p className={`mt-1 text-xs ${valid ? 'text-slate-500' : 'text-rose-600'}`}>
                {Number.isInteger(seconds) && seconds >= 0 && seconds <= 86400 ? describe(seconds) + '.' : 'Isi angka bulat 0 – 86400 detik.'}
              </p>
            </div>
            <ul className="list-disc space-y-1 pl-5 text-xs text-slate-500">
              <li>Hitungan dimulai saat status pesanan menjadi &quot;Pesanan sedang disiapkan&quot;.</li>
              <li>
                Saat pembeli menekan &quot;Batalkan Pesanan&quot;, waktu berhenti selama ia membaca konfirmasi (maks. 2
                menit). Jika ia memilih &quot;Jangan Batalkan&quot; atau menutup aplikasi, pesanan lanjut dikemas dan
                tidak bisa dibatalkan lagi.
              </li>
              <li>Pesanan yang belum dibayar / menunggu pembayaran tetap bisa dibatalkan kapan saja.</li>
              <li>Pesanan yang sudah dibayar dikembalikan penuh ke Saldo Belanja pembeli sesuai total yang dibayar.</li>
              <li>Isi 0 untuk menutup pembatalan oleh pembeli begitu pesanan mulai disiapkan.</li>
            </ul>
          </section>
        )}

        {!loading && (
          <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <div>
              <h2 className="text-base font-semibold text-slate-900">Pesanan Instant</h2>
              <p className="text-xs text-slate-500">
                Pesanan tanpa jadwal pengiriman harus dikirim dalam batas waktu ini sejak pesanan dibuat. Panel admin
                menghitung mundur, memberi peringatan saat waktunya hampir habis, dan berbunyi bila terlambat.
              </p>
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium text-slate-700">Batas waktu kirim (menit)</label>
              <input
                type="number"
                min={5}
                max={1440}
                step={1}
                className={input}
                value={Number.isNaN(dispatch) ? '' : dispatch}
                onChange={(e) => {
                  setSuccess(null);
                  setForm({ ...form, instant_dispatch_minutes: e.target.value === '' ? NaN : Number(e.target.value) });
                }}
              />
              <p className={`mt-1 text-xs ${validDispatch ? 'text-slate-500' : 'text-rose-600'}`}>
                {validDispatch
                  ? `Pesanan instan harus dikirim maksimal ${dispatch} menit setelah dibuat.`
                  : 'Isi angka bulat 5 – 1440 menit.'}
              </p>
            </div>
          </section>
        )}

        {!loading && (
          <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <div>
              <h2 className="text-base font-semibold text-slate-900">Paylater</h2>
              <p className="text-xs text-slate-500">
                Metode bayar nanti hanya bisa dipakai pelanggan yang sudah menyelesaikan sejumlah transaksi. Pelanggan
                yang belum memenuhi melihat keterangan dan tidak bisa memilihnya. Pemakaian pertama wajib verifikasi
                wajah.
              </p>
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium text-slate-700">Minimal transaksi selesai</label>
              <input
                type="number"
                min={0}
                max={1000}
                step={1}
                className={input}
                value={Number.isNaN(minTx) ? '' : minTx}
                onChange={(e) => {
                  setSuccess(null);
                  setForm({ ...form, paylater_min_transactions: e.target.value === '' ? NaN : Number(e.target.value) });
                }}
              />
              <p className={`mt-1 text-xs ${validTx ? 'text-slate-500' : 'text-rose-600'}`}>
                {validTx
                  ? minTx === 0
                    ? 'Semua pelanggan langsung bisa memakai Paylater (tetap perlu verifikasi pertama kali).'
                    : `Pelanggan perlu ${minTx} pesanan berstatus selesai.`
                  : 'Isi angka bulat 0 – 1000.'}
              </p>
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium text-slate-700">Jatuh tempo tagihan (hari)</label>
              <input
                type="number"
                min={1}
                max={90}
                step={1}
                className={input}
                value={Number.isNaN(dueDays) ? '' : dueDays}
                onChange={(e) => {
                  setSuccess(null);
                  setForm({ ...form, paylater_due_days: e.target.value === '' ? NaN : Number(e.target.value) });
                }}
              />
              <p className={`mt-1 text-xs ${validDue ? 'text-slate-500' : 'text-rose-600'}`}>
                {validDue ? `Tagihan Paylater jatuh tempo ${dueDays} hari setelah pesanan dibuat.` : 'Isi angka bulat 1 – 90.'}
              </p>
            </div>
          </section>
        )}
      </div>
    </AdminLayout>
  );
}
