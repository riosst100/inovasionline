'use client';

import React, { useEffect, useState } from 'react';
import { adminApi } from '../../lib/api';
import { LaunchPopupMode, LaunchPopupSettings } from '../../types';
import { CalendarClock, CheckCircle2, AlertCircle, Loader2, Save } from 'lucide-react';

const MODES: { value: LaunchPopupMode; label: string; hint: string }[] = [
  { value: 'off', label: 'Nonaktif', hint: 'Tidak ada popup saat aplikasi dibuka.' },
  { value: 'admob', label: 'Iklan AdMob', hint: 'Selalu menampilkan iklan native AdMob (butuh Ad Unit Native di menu Iklan).' },
  {
    value: 'image',
    label: 'Gambar Sendiri',
    hint: 'Menampilkan gambar di bawah sesuai jadwal masing-masing. Pada hari tanpa gambar terjadwal, otomatis menampilkan iklan AdMob.',
  },
];

const EMPTY: LaunchPopupSettings = { mode: 'off', max_per_day: 1 };

/** What the launch popup shows (AdMob or own images) and how often. Days / dates are set per image. */
export default function LaunchPopupSettingsCard() {
  const [settings, setSettings] = useState<LaunchPopupSettings>(EMPTY);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ type: 'ok' | 'error'; text: string } | null>(null);

  useEffect(() => {
    adminApi
      .getLaunchPopup()
      .then(setSettings)
      .catch((err: any) => setMessage({ type: 'error', text: err?.message || 'Gagal memuat pengaturan popup.' }))
      .finally(() => setLoading(false));
  }, []);

  const save = async () => {
    try {
      setSaving(true);
      setMessage(null);
      setSettings(await adminApi.updateLaunchPopup(settings));
      setMessage({ type: 'ok', text: 'Pengaturan popup berhasil disimpan.' });
    } catch (err: any) {
      setMessage({ type: 'error', text: err?.message || 'Gagal menyimpan pengaturan popup.' });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-xs space-y-5">
      <div className="flex items-center gap-2.5">
        <div className="h-9 w-9 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
          <CalendarClock className="h-5 w-5" />
        </div>
        <div>
          <h3 className="text-sm font-extrabold text-slate-900">Pengaturan Popup Saat Aplikasi Dibuka</h3>
          <p className="text-xs text-slate-500">Pilih isi popup. Hari dan tanggal tayang diatur di tiap gambar (waktu WIB).</p>
        </div>
      </div>

      {loading ? (
        <div className="py-8 flex justify-center text-emerald-600">
          <Loader2 className="h-6 w-6 animate-spin" />
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            {MODES.map((m) => (
              <label
                key={m.value}
                className={`cursor-pointer rounded-xl border p-3 transition ${
                  settings.mode === m.value ? 'border-emerald-500 bg-emerald-50/60' : 'border-slate-200 hover:bg-slate-50'
                }`}
              >
                <div className="flex items-center gap-2">
                  <input
                    type="radio"
                    name="launch-popup-mode"
                    checked={settings.mode === m.value}
                    onChange={() => setSettings({ ...settings, mode: m.value })}
                    className="text-emerald-600 focus:ring-emerald-500"
                  />
                  <span className="text-sm font-bold text-slate-800">{m.label}</span>
                </div>
                <p className="text-[11px] text-slate-500 mt-1 ml-6">{m.hint}</p>
              </label>
            ))}
          </div>

          {settings.mode !== 'off' && (
            <div className="space-y-2">
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider">
                Maksimal Tampil per Hari
              </label>
              <div className="flex items-center gap-2">
                <input
                  type="number"
                  min={1}
                  max={20}
                  value={settings.max_per_day}
                  onChange={(e) =>
                    setSettings({ ...settings, max_per_day: Math.min(20, Math.max(1, Number(e.target.value) || 1)) })
                  }
                  className="w-24 rounded-xl border border-slate-200 px-3 py-2 text-sm text-slate-900 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition"
                />
                <span className="text-xs text-slate-500">kali per perangkat (tiap aplikasi dibuka)</span>
              </div>
            </div>
          )}

          {message && (
            <div
              className={`flex items-center gap-2 rounded-xl border p-3 text-xs ${
                message.type === 'ok'
                  ? 'border-emerald-200 bg-emerald-50 text-emerald-700'
                  : 'border-rose-200 bg-rose-50 text-rose-700'
              }`}
            >
              {message.type === 'ok' ? <CheckCircle2 className="h-4 w-4" /> : <AlertCircle className="h-4 w-4" />}
              <span>{message.text}</span>
            </div>
          )}

          <div className="flex justify-end">
            <button
              type="button"
              onClick={save}
              disabled={saving}
              className="inline-flex items-center gap-2 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 px-4 py-2.5 text-sm font-bold text-white shadow-sm disabled:opacity-50"
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
              Simpan Pengaturan
            </button>
          </div>
        </>
      )}
    </div>
  );
}
