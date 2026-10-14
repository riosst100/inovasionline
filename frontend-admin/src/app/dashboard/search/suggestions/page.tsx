'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { SearchSuggestion } from '../../../../types';
import { AlertCircle, CheckCircle2, Loader2, Plus, Trash2 } from 'lucide-react';

export default function SearchSuggestionsPage() {
  const [items, setItems] = useState<SearchSuggestion[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [keyword, setKeyword] = useState('');
  const [count, setCount] = useState('10');
  const [search, setSearch] = useState('');
  const [source, setSource] = useState('');

  const load = useCallback(async () => {
    try {
      setItems(await adminApi.getSearchSuggestions(search, source));
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat saran pencarian.');
    } finally {
      setLoading(false);
    }
  }, [search, source]);

  useEffect(() => {
    const t = setTimeout(load, 300);
    return () => clearTimeout(t);
  }, [load]);

  const add = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      await adminApi.createSearchSuggestion(keyword.trim(), Number(count) || 0);
      setKeyword('');
      setSuccess('Query berhasil ditambahkan.');
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Gagal menambahkan query.');
    } finally {
      setSaving(false);
    }
  };

  const remove = async (item: SearchSuggestion) => {
    if (!confirm(`Hapus query "${item.keyword}"?`)) return;
    setDeletingId(item.id);
    setError(null);
    setSuccess(null);
    try {
      await adminApi.deleteSearchSuggestion(item.id);
      setSuccess('Query berhasil dihapus.');
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Gagal menghapus query.');
    } finally {
      setDeletingId(null);
    }
  };

  return (
    <AdminLayout>
      <div className="mx-auto max-w-4xl space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Saran Pencarian</h1>
          <p className="text-sm text-slate-500">
            Query yang dicari pengguna beserta jumlahnya. Admin dapat menambah query manual untuk awal.
          </p>
        </div>

        <form onSubmit={add} className="flex flex-wrap items-end gap-3 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
          <div className="min-w-[200px] flex-1">
            <label className="mb-1 block text-xs font-medium text-slate-600">Query</label>
            <input
              value={keyword}
              onChange={(e) => setKeyword(e.target.value)}
              required
              maxLength={100}
              placeholder="mis. sepatu olahraga"
              className="w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500"
            />
          </div>
          <div className="w-40">
            <label className="mb-1 block text-xs font-medium text-slate-600">Jumlah pencarian</label>
            <input
              type="number"
              min={0}
              value={count}
              onChange={(e) => setCount(e.target.value)}
              required
              className="w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500"
            />
          </div>
          <button
            type="submit"
            disabled={saving}
            className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
          >
            {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
            Tambah
          </button>
        </form>

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

        <div className="flex flex-wrap gap-3">
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari query..."
            className="min-w-[200px] flex-1 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500"
          />
          <select
            value={source}
            onChange={(e) => setSource(e.target.value)}
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm"
          >
            <option value="">Semua sumber</option>
            <option value="user">Dari user</option>
            <option value="admin">Dari admin</option>
          </select>
        </div>

        <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : items.length === 0 ? (
            <p className="p-8 text-center text-sm text-slate-500">Belum ada query.</p>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">Query</th>
                  <th className="px-4 py-3">Sumber</th>
                  <th className="px-4 py-3 text-right">Jumlah</th>
                  <th className="px-4 py-3">Terakhir dicari</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {items.map((item) => (
                  <tr key={item.id}>
                    <td className="px-4 py-3 font-medium text-slate-900">{item.keyword}</td>
                    <td className="px-4 py-3">
                      <span
                        className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                          item.source === 'admin' ? 'bg-amber-100 text-amber-700' : 'bg-sky-100 text-sky-700'
                        }`}
                      >
                        {item.source === 'admin' ? 'Admin' : 'User'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right tabular-nums">{item.search_count.toLocaleString('id-ID')}</td>
                    <td className="px-4 py-3 text-slate-500">
                      {item.last_searched_at ? new Date(item.last_searched_at).toLocaleString('id-ID') : '-'}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button
                        onClick={() => remove(item)}
                        disabled={deletingId !== null}
                        title="Hapus"
                        className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-50"
                      >
                        {deletingId === item.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </AdminLayout>
  );
}
