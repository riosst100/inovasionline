'use client';

import React, { useEffect, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { MidtransMode, MidtransSettings, MidtransSettingsPayload } from '../../../../types';
import { AlertCircle, AlertTriangle, CheckCircle2, Copy, Loader2, Save } from 'lucide-react';

const MODES: { value: MidtransMode; label: string; hint: string }[] = [
  { value: 'sandbox', label: 'Sandbox', hint: 'Untuk uji coba. Pembayaran tidak memakai uang sungguhan.' },
  { value: 'production', label: 'Production', hint: 'Pembayaran sungguhan dari pembeli.' },
];

function toForm(s: MidtransSettings): MidtransSettingsPayload {
  return {
    mode: s.mode,
    sandbox: { client_key: s.sandbox.client_key ?? '', server_key: '' },
    production: { client_key: s.production.client_key ?? '', server_key: '' },
  };
}

export default function PaymentGatewayPage() {
  const [settings, setSettings] = useState<MidtransSettings | null>(null);
  const [form, setForm] = useState<MidtransSettingsPayload | null>(null);
  const [initial, setInitial] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const apply = (res: MidtransSettings) => {
    const f = toForm(res);
    setSettings(res);
    setForm(f);
    setInitial(JSON.stringify(f));
  };

  useEffect(() => {
    (async () => {
      try {
        apply(await adminApi.getMidtransSettings());
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'Gagal memuat pengaturan Midtrans.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const setKey = (mode: MidtransMode, field: 'client_key' | 'server_key', value: string) => {
    setSuccess(null);
    setForm((f) => (f ? { ...f, [mode]: { ...f[mode], [field]: value } } : f));
  };

  const dirty = form !== null && JSON.stringify(form) !== initial;

  const save = async () => {
    if (!form) return;
    if (form.mode !== settings?.mode && form.mode === 'production'
      && !confirm('Pindah ke mode Production? Pembayaran baru akan memakai uang sungguhan.')) {
      return;
    }
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      apply(await adminApi.saveMidtransSettings(form));
      setSuccess('Pengaturan Midtrans berhasil disimpan.');
    } catch (e) {
      setError(
        e instanceof ApiError
          ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message
          : 'Gagal menyimpan pengaturan Midtrans.'
      );
    } finally {
      setSaving(false);
    }
  };

  const copyUrl = async () => {
    if (!settings) return;
    try {
      await navigator.clipboard.writeText(settings.notification_url);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // Clipboard blocked (non-HTTPS); the URL is still selectable.
    }
  };

  const input =
    'w-full rounded-lg border border-slate-200 bg-white px-3 py-2 font-mono text-sm outline-none focus:border-emerald-500';

  return (
    <AdminLayout>
      <div className="mx-auto max-w-3xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Payment Gateway (Midtrans)</h1>
            <p className="text-sm text-slate-500">
              Key dan mode Midtrans untuk pembayaran pesanan dan top up saldo. Perubahan berlaku untuk transaksi baru.
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

        {loading || !form || !settings ? (
          <div className="flex justify-center p-10">
            <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
          </div>
        ) : (
          <>
            {settings.from_env && (
              <div className="flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
                <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
                Belum pernah disimpan di sini, jadi nilai di bawah diambil dari file .env server. Setelah disimpan,
                pengaturan di halaman ini yang dipakai.
              </div>
            )}

            <section className="space-y-3 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <h2 className="text-sm font-semibold text-slate-800">Mode aktif</h2>
              <div className="grid gap-3 sm:grid-cols-2">
                {MODES.map((m) => (
                  <label
                    key={m.value}
                    className={`flex cursor-pointer items-start gap-3 rounded-xl border p-3 ${
                      form.mode === m.value
                        ? m.value === 'production'
                          ? 'border-emerald-500 bg-emerald-50'
                          : 'border-amber-400 bg-amber-50'
                        : 'border-slate-200'
                    }`}
                  >
                    <input
                      type="radio"
                      name="mode"
                      className="mt-1"
                      checked={form.mode === m.value}
                      onChange={() => {
                        setSuccess(null);
                        setForm({ ...form, mode: m.value });
                      }}
                    />
                    <div>
                      <p className="text-sm font-semibold text-slate-800">{m.label}</p>
                      <p className="text-xs text-slate-500">{m.hint}</p>
                    </div>
                  </label>
                ))}
              </div>
            </section>

            {MODES.map((m) => {
              const keys = settings[m.value];
              return (
                <section key={m.value} className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                  <div className="flex items-center justify-between gap-2">
                    <h2 className="text-sm font-semibold text-slate-800">Key {m.label}</h2>
                    {form.mode === m.value && (
                      <span className="rounded-full bg-slate-900 px-2 py-0.5 text-[11px] font-semibold text-white">Aktif</span>
                    )}
                  </div>
                  <div>
                    <label className="mb-1 block text-sm font-medium text-slate-700">
                      Server Key {form.mode === m.value && <span className="text-rose-500">*</span>}
                    </label>
                    <input
                      type="password"
                      autoComplete="new-password"
                      className={input}
                      placeholder={
                        keys.server_key_set
                          ? `Tersimpan (${keys.server_key_hint}). Kosongkan untuk tetap memakai key ini.`
                          : m.value === 'sandbox' ? 'SB-Mid-server-...' : 'Mid-server-...'
                      }
                      value={form[m.value].server_key}
                      onChange={(e) => setKey(m.value, 'server_key', e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="mb-1 block text-sm font-medium text-slate-700">Client Key</label>
                    <input
                      className={input}
                      placeholder={m.value === 'sandbox' ? 'SB-Mid-client-...' : 'Mid-client-...'}
                      value={form[m.value].client_key}
                      onChange={(e) => setKey(m.value, 'client_key', e.target.value)}
                    />
                  </div>
                  <p className="text-xs text-slate-500">
                    Ambil dari dashboard Midtrans mode {m.label}: Settings → Access Keys.
                  </p>
                </section>
              );
            })}

            <section className="space-y-2 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
              <h2 className="text-sm font-semibold text-slate-800">Payment Notification URL</h2>
              <p className="text-xs text-slate-500">
                Isi di dashboard Midtrans (Settings → Payment → Notification URL) untuk mode Sandbox dan Production,
                supaya status pembayaran terupdate otomatis.
              </p>
              <div className="flex gap-2">
                <input readOnly className={input} value={settings.notification_url} onFocus={(e) => e.target.select()} />
                <button
                  type="button"
                  onClick={copyUrl}
                  className="inline-flex shrink-0 items-center gap-1 rounded-lg border border-slate-200 px-3 text-sm text-slate-700 hover:bg-slate-50"
                >
                  {copied ? <CheckCircle2 className="h-4 w-4 text-emerald-600" /> : <Copy className="h-4 w-4" />}
                  {copied ? 'Tersalin' : 'Salin'}
                </button>
              </div>
            </section>
          </>
        )}
      </div>
    </AdminLayout>
  );
}
