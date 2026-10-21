'use client';

import React, { useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { apiRequest, ApiError } from '../../../lib/api';
import { LABEL_COLORS, LabelItem, badgeClass, setLabelCache, useLabels } from '../../../lib/labels';
import { AlertCircle, CheckCircle2, ListChecks, Loader2, Save } from 'lucide-react';

const GROUPS = [
  { id: 'order_status', title: 'Status Pesanan', desc: 'Dipakai di tab, kartu, dan detail pesanan.' },
  { id: 'shipping_type', title: 'Jenis Metode Pengiriman', desc: 'Dipakai di daftar Metode Pengiriman dan detail pesanan.' },
];

export default function LabelConfigPage() {
  const { items, ready } = useLabels();
  const [form, setForm] = useState<LabelItem[]>([]);
  const [initial, setInitial] = useState('[]');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    if (ready) {
      setForm(items);
      setInitial(JSON.stringify(items));
    }
  }, [ready, items]);

  const dirty = JSON.stringify(form) !== initial;
  const valid = form.every((i) => i.label.trim().length > 0);

  const change = (g: string, key: string, patch: Partial<LabelItem>) =>
    setForm((f) => f.map((i) => (i.group === g && i.key === key ? { ...i, ...patch } : i)));

  const save = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const res = await apiRequest<LabelItem[]>('/admin/label-configs', {
        method: 'PUT',
        body: JSON.stringify({ items: form }),
      });
      setLabelCache(res);
      setSuccess('Label berhasil disimpan.');
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal menyimpan label.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminLayout>
      <div className="space-y-6 max-w-3xl">
        <div>
          <div className="flex items-center gap-2">
            <ListChecks className="h-6 w-6 text-emerald-600" />
            <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">Status Pesanan</h2>
          </div>
          <p className="mt-1 text-xs md:text-sm text-slate-500">
            Atur nama dan warna label. Perubahan berlaku di seluruh admin web.
          </p>
        </div>

        {error && (
          <div className="flex items-center gap-2 rounded-xl bg-red-50 p-3 text-sm text-red-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        )}
        {success && (
          <div className="flex items-center gap-2 rounded-xl bg-emerald-50 p-3 text-sm text-emerald-700">
            <CheckCircle2 className="h-4 w-4" /> {success}
          </div>
        )}

        {!ready ? (
          <div className="py-12 flex justify-center text-emerald-600">
            <Loader2 className="h-6 w-6 animate-spin" />
          </div>
        ) : (
          GROUPS.map((g) => (
            <div key={g.id} className="rounded-2xl border border-slate-200/80 bg-white shadow-xs">
              <div className="border-b border-slate-100 p-4">
                <h3 className="font-bold text-slate-900">{g.title}</h3>
                <p className="text-xs text-slate-500">{g.desc}</p>
              </div>
              <div className="divide-y divide-slate-100">
                {form
                  .filter((i) => i.group === g.id)
                  .map((i) => (
                    <div key={i.key} className="flex flex-wrap items-center gap-3 p-4">
                      <code className="w-36 shrink-0 text-xs text-slate-400">{i.key}</code>
                      <input
                        value={i.label}
                        maxLength={60}
                        onChange={(e) => change(i.group, i.key, { label: e.target.value })}
                        className="min-w-[160px] flex-1 rounded-xl border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500"
                      />
                      <select
                        value={i.color}
                        onChange={(e) => change(i.group, i.key, { color: e.target.value })}
                        className="rounded-xl border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500"
                      >
                        {Object.entries(LABEL_COLORS).map(([k, c]) => (
                          <option key={k} value={k}>
                            {c.name}
                          </option>
                        ))}
                      </select>
                      <span className={`rounded-full px-2.5 py-1 text-[11px] font-bold ${badgeClass(i.color)}`}>
                        {i.label || '-'}
                      </span>
                    </div>
                  ))}
              </div>
            </div>
          ))
        )}

        <button
          onClick={save}
          disabled={!dirty || !valid || saving}
          className="flex items-center gap-2 rounded-xl bg-emerald-600 px-5 py-2.5 text-sm font-bold text-white disabled:opacity-40"
        >
          {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />} Simpan
        </button>
      </div>
    </AdminLayout>
  );
}
