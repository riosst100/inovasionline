'use client';

import React, { useEffect, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { AlertCircle, CheckCircle2, Loader2, Plus, Save, Trash2 } from 'lucide-react';

const MAX_TEXTS = 10;

export default function PromoTextsPage() {
  const [texts, setTexts] = useState<string[]>([]);
  const [initial, setInitial] = useState('[]');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const list = await adminApi.getPromoTexts();
        setTexts(list);
        setInitial(JSON.stringify(list));
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'Gagal memuat tulisan promosi.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const change = (next: string[]) => {
    setSuccess(null);
    setTexts(next);
  };

  const dirty = JSON.stringify(texts) !== initial;

  const save = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const saved = await adminApi.savePromoTexts(texts);
      setTexts(saved);
      setInitial(JSON.stringify(saved));
      setSuccess('Tulisan promosi berhasil disimpan.');
    } catch (e) {
      setError(
        e instanceof ApiError
          ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message
          : 'Gagal menyimpan tulisan promosi.'
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
            <h1 className="text-2xl font-bold text-slate-900">Tulisan Promosi</h1>
            <p className="text-sm text-slate-500">
              Teks yang tampil sebagai slider di beranda aplikasi. Jika lebih dari satu, teks berganti otomatis.
              Kosongkan semua untuk menyembunyikan strip ini.
            </p>
          </div>
          <button
            type="button"
            onClick={save}
            disabled={saving || loading || !dirty}
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
          <section className="space-y-3 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            {texts.length === 0 && <p className="text-sm text-slate-400">Belum ada teks.</p>}
            {texts.map((text, i) => (
              <div key={i} className="flex items-center gap-2">
                <input
                  type="text"
                  maxLength={120}
                  className={input}
                  placeholder="Contoh: Gratis Ongkir untuk pembayaran pakai Saldo Belanja"
                  value={text}
                  onChange={(e) => change(texts.map((t, j) => (j === i ? e.target.value : t)))}
                />
                <button
                  type="button"
                  aria-label="Hapus teks"
                  onClick={() => change(texts.filter((_, j) => j !== i))}
                  className="rounded-lg p-2 text-rose-600 hover:bg-rose-50"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            ))}
            {texts.length < MAX_TEXTS && (
              <button
                type="button"
                onClick={() => change([...texts, ''])}
                className="inline-flex items-center gap-1.5 rounded-lg border border-slate-200 px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-50"
              >
                <Plus className="h-4 w-4" /> Tambah teks
              </button>
            )}
          </section>
        )}
      </div>
    </AdminLayout>
  );
}
