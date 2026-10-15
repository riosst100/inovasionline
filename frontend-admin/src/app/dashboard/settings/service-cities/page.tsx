'use client';

import React, { useEffect, useMemo, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { titleCase } from '../../../../lib/text';
import { ServiceCityOptions } from '../../../../types';
import { AlertCircle, CheckCircle2, Loader2, MapPinned, Save, Search } from 'lucide-react';

export default function ServiceCitiesPage() {
  const [data, setData] = useState<ServiceCityOptions | null>(null);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [initial, setInitial] = useState<string[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const res = await adminApi.getServiceCities();
        setData(res);
        setSelected(new Set(res.selected));
        setInitial(res.selected);
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'Gagal memuat data kota.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const toggle = (code: string) =>
    setSelected((cur) => {
      const next = new Set(cur);
      if (!next.delete(code)) next.add(code);
      return next;
    });

  const toggleProvince = (codes: string[]) =>
    setSelected((cur) => {
      const next = new Set(cur);
      const all = codes.every((c) => next.has(c));
      codes.forEach((c) => (all ? next.delete(c) : next.add(c)));
      return next;
    });

  const q = search.trim().toLowerCase();
  const groups = useMemo(
    () =>
      (data?.provinces ?? [])
        .map((p) => ({
          ...p,
          visible: q
            ? p.name.toLowerCase().includes(q)
              ? p.cities
              : p.cities.filter((c) => c.name.toLowerCase().includes(q))
            : p.cities,
        }))
        .filter((p) => p.visible.length > 0),
    [data, q]
  );

  const dirty = selected.size !== initial.length || initial.some((c) => !selected.has(c));

  const save = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const list = [...selected];
      await adminApi.saveServiceCities(list);
      setInitial(list);
      setSuccess('Cakupan kota berhasil disimpan.');
    } catch (e) {
      setError(
        e instanceof ApiError
          ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message
          : 'Gagal menyimpan cakupan kota.'
      );
    } finally {
      setSaving(false);
    }
  };

  return (
    <AdminLayout>
      <div className="mx-auto max-w-4xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Cakupan Kota</h1>
            <p className="text-sm text-slate-500">
              Kota yang dijangkau aplikasi secara keseluruhan. Hanya kota terpilih yang dapat dipilih pada alamat
              pengguna dan cakupan gudang.
            </p>
          </div>
          <button
            type="button"
            onClick={save}
            disabled={saving || loading || !dirty || selected.size === 0}
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
          <>
            <div className="flex flex-wrap items-center gap-3">
              <div className="relative min-w-[200px] flex-1">
                <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
                <input
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Cari provinsi atau kota..."
                  className="w-full rounded-lg border border-slate-200 bg-white py-2 pl-9 pr-3 text-sm outline-none focus:border-emerald-500"
                />
              </div>
              <span className="flex items-center gap-1.5 text-sm text-slate-600">
                <MapPinned className="h-4 w-4 text-emerald-600" />
                {selected.size} kota terpilih
              </span>
            </div>

            <div className="space-y-4">
              {groups.length === 0 && (
                <p className="rounded-2xl border border-slate-200 bg-white p-8 text-center text-sm text-slate-500">
                  Kota tidak ditemukan.
                </p>
              )}
              {groups.map((p) => {
                const codes = p.cities.map((c) => c.code);
                const count = codes.filter((c) => selected.has(c)).length;
                return (
                  <section key={p.code} className="rounded-2xl border border-slate-200 bg-white shadow-sm">
                    <label className="flex cursor-pointer items-center gap-3 border-b border-slate-100 px-4 py-3">
                      <input
                        type="checkbox"
                        checked={count === codes.length}
                        ref={(el) => {
                          if (el) el.indeterminate = count > 0 && count < codes.length;
                        }}
                        onChange={() => toggleProvince(codes)}
                      />
                      <span className="flex-1 text-sm font-semibold text-slate-800">{titleCase(p.name)}</span>
                      <span className="text-xs text-slate-400">
                        {count}/{codes.length} kota
                      </span>
                    </label>
                    <div className="grid gap-1 p-2 sm:grid-cols-2 lg:grid-cols-3">
                      {p.visible.map((c) => {
                        const checked = selected.has(c.code);
                        return (
                          <label
                            key={c.code}
                            className={`flex cursor-pointer items-center gap-2 rounded-lg px-2 py-1.5 text-sm ${
                              checked ? 'bg-emerald-50 text-emerald-800' : 'text-slate-700 hover:bg-slate-50'
                            }`}
                          >
                            <input type="checkbox" checked={checked} onChange={() => toggle(c.code)} />
                            {titleCase(c.name)}
                          </label>
                        );
                      })}
                    </div>
                  </section>
                );
              })}
            </div>
          </>
        )}
      </div>
    </AdminLayout>
  );
}
