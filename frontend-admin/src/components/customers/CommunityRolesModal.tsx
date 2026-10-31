'use client';

import React, { useEffect, useState } from 'react';
import { Loader2, Plus, Trash2 } from 'lucide-react';
import { adminApi } from '../../lib/api';
import { CommunityAbility, CommunityRoleList } from '../../types';

type Draft = { id?: string; name: string; abilities: CommunityAbility[]; appointments_count: number };

/**
 * Community roles (Admin, Moderator, ...) given to customers appointed to a region, and what each may do
 * there in the app: delete posts, comments or chat messages.
 */
export default function CommunityRolesModal({ onClose }: { onClose: () => void }) {
  const [catalog, setCatalog] = useState<CommunityRoleList['abilities']>([]);
  const [drafts, setDrafts] = useState<Draft[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState<number | null>(null);
  const [error, setError] = useState('');

  const load = async () => {
    try {
      setLoading(true);
      const res = await adminApi.getCommunityRoles();
      setCatalog(res.abilities);
      setDrafts(res.roles.map((r) => ({ ...r })));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal memuat peran.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const change = (index: number, patch: Partial<Draft>) =>
    setDrafts((prev) => prev.map((d, i) => (i === index ? { ...d, ...patch } : d)));

  const toggleAbility = (index: number, ability: CommunityAbility) => {
    const current = drafts[index].abilities;
    change(index, {
      abilities: current.includes(ability) ? current.filter((a) => a !== ability) : [...current, ability],
    });
  };

  const save = async (index: number) => {
    const d = drafts[index];
    try {
      setBusy(index);
      setError('');
      const saved = await adminApi.saveCommunityRole({ name: d.name, abilities: d.abilities }, d.id);
      change(index, saved);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal menyimpan peran.');
    } finally {
      setBusy(null);
    }
  };

  const remove = async (index: number) => {
    const d = drafts[index];
    if (d.id && !window.confirm(`Hapus peran ${d.name}?`)) return;
    try {
      setBusy(index);
      setError('');
      if (d.id) await adminApi.deleteCommunityRole(d.id);
      setDrafts((prev) => prev.filter((_, i) => i !== index));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal menghapus peran.');
    } finally {
      setBusy(null);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="flex max-h-[90vh] w-full max-w-lg flex-col rounded-2xl bg-white p-6 shadow-xl">
        <h3 className="text-lg font-extrabold text-slate-900">Peran Komunitas</h3>
        <p className="mt-1 text-xs text-slate-500">
          Peran untuk pengguna yang ditunjuk di suatu wilayah (lewat tombol Admin Wilayah). Centang yang boleh dilakukan
          di wilayah tersebut. Teks badge-nya diatur per penunjukan.
        </p>

        <div className="mt-4 flex-1 space-y-3 overflow-y-auto">
          {loading ? (
            <div className="flex justify-center py-8">
              <Loader2 className="h-5 w-5 animate-spin text-slate-400" />
            </div>
          ) : (
            drafts.map((d, index) => (
              <div key={d.id ?? `new-${index}`} className="rounded-xl border border-slate-200 p-3">
                <div className="flex items-center gap-2">
                  <input
                    value={d.name}
                    onChange={(e) => change(index, { name: e.target.value })}
                    placeholder="Nama peran, mis. Moderator"
                    className="flex-1 rounded-lg border border-slate-200 px-3 py-2 text-sm font-semibold outline-none focus:border-emerald-500"
                  />
                  <button
                    onClick={() => remove(index)}
                    disabled={busy === index}
                    title="Hapus peran"
                    className="rounded-lg p-2 text-red-600 hover:bg-red-50 disabled:opacity-50"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
                <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1">
                  {catalog.map((a) => (
                    <label key={a.key} className="flex items-center gap-1.5 text-xs text-slate-700">
                      <input
                        type="checkbox"
                        checked={d.abilities.includes(a.key)}
                        onChange={() => toggleAbility(index, a.key)}
                      />
                      {a.label}
                    </label>
                  ))}
                </div>
                <div className="mt-2 flex items-center justify-between">
                  <span className="text-[11px] text-slate-400">
                    {d.id ? `Dipakai ${d.appointments_count} penunjukan` : 'Belum disimpan'}
                  </span>
                  <button
                    onClick={() => save(index)}
                    disabled={busy === index || !d.name.trim()}
                    className="inline-flex items-center gap-1 rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
                  >
                    {busy === index && <Loader2 className="h-3.5 w-3.5 animate-spin" />} Simpan
                  </button>
                </div>
              </div>
            ))
          )}
        </div>

        {error && <p className="mt-3 text-xs font-semibold text-red-600">{error}</p>}

        <div className="mt-4 flex justify-between gap-2">
          <button
            onClick={() => setDrafts((prev) => [...prev, { name: '', abilities: [], appointments_count: 0 }])}
            className="inline-flex items-center gap-1 rounded-lg border border-emerald-200 px-4 py-2 text-xs font-semibold text-emerald-700 hover:bg-emerald-50"
          >
            <Plus className="h-3.5 w-3.5" /> Tambah Peran
          </button>
          <button
            onClick={onClose}
            className="rounded-lg border border-slate-200 px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-50"
          >
            Tutup
          </button>
        </div>
      </div>
    </div>
  );
}
