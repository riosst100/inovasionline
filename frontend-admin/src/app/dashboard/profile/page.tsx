'use client';

import React, { useRef, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { useAuth } from '../../../context/AuthContext';
import { adminApi, ApiError } from '../../../lib/api';
import { AdminUser } from '../../../types';
import { AlertCircle, Camera, CheckCircle2, Loader2, Trash2 } from 'lucide-react';

const MAX_BYTES = 5 * 1024 * 1024;

export default function AdminProfilePage() {
  const { user, isSuperAdmin, updateUser } = useAuth();
  const fileRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState<'upload' | 'delete' | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const roleName = user?.role?.name || (isSuperAdmin ? 'Super Admin' : 'Staff');

  const run = async (key: 'upload' | 'delete', action: () => Promise<AdminUser>, okMsg: string) => {
    setBusy(key);
    setError(null);
    setSuccess(null);
    try {
      updateUser(await action());
      setSuccess(okMsg);
    } catch (e) {
      setError(e instanceof ApiError ? (e.errors?.avatar?.[0] ?? e.message) : 'Terjadi kesalahan.');
    } finally {
      setBusy(null);
    }
  };

  const onFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      setError('File harus berupa gambar (JPG, PNG, atau WebP).');
      return;
    }
    if (file.size > MAX_BYTES) {
      setError('Ukuran foto maksimal 5 MB.');
      return;
    }
    run('upload', () => adminApi.updateAvatar(file), 'Foto profil berhasil diperbarui.');
  };

  const remove = () => {
    if (!confirm('Hapus foto profil?')) return;
    run('delete', () => adminApi.deleteAvatar(), 'Foto profil berhasil dihapus.');
  };

  return (
    <AdminLayout>
      <div className="mx-auto max-w-2xl space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Profil Saya</h1>
          <p className="text-sm text-slate-500">Atur foto profil yang tampil di panel admin.</p>
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

        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="flex flex-col items-center gap-5 sm:flex-row sm:items-center">
            <button
              type="button"
              onClick={() => fileRef.current?.click()}
              disabled={busy !== null}
              aria-label="Ganti foto profil"
              className="group relative h-24 w-24 shrink-0 overflow-hidden rounded-full disabled:cursor-wait"
            >
              {user?.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={user.avatar_url} alt="" className="h-full w-full object-cover" />
              ) : (
                <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-emerald-600 to-teal-500 text-2xl font-bold text-white">
                  {user?.name?.slice(0, 2).toUpperCase() || 'SA'}
                </div>
              )}
              <span
                className={`absolute inset-0 flex items-center justify-center bg-slate-900/45 text-white transition-opacity ${
                  busy ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'
                }`}
              >
                {busy ? <Loader2 className="h-6 w-6 animate-spin" /> : <Camera className="h-6 w-6" />}
              </span>
            </button>

            <div className="min-w-0 flex-1 text-center sm:text-left">
              <p className="truncate text-lg font-semibold text-slate-900">{user?.name}</p>
              <p className="truncate text-sm text-slate-500">{user?.email}</p>
              <p className="mt-1 text-xs font-semibold text-emerald-700">{roleName}</p>

              <div className="mt-4 flex flex-wrap justify-center gap-2 sm:justify-start">
                <button
                  type="button"
                  onClick={() => fileRef.current?.click()}
                  disabled={busy !== null}
                  className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
                >
                  {busy === 'upload' ? <Loader2 className="h-4 w-4 animate-spin" /> : <Camera className="h-4 w-4" />}
                  {user?.avatar_url ? 'Ganti Foto' : 'Unggah Foto'}
                </button>
                {user?.avatar_url && (
                  <button
                    type="button"
                    onClick={remove}
                    disabled={busy !== null}
                    className="inline-flex items-center gap-2 rounded-xl border border-slate-200 px-4 py-2 text-sm font-medium text-rose-600 hover:bg-rose-50 disabled:opacity-50"
                  >
                    {busy === 'delete' ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
                    Hapus
                  </button>
                )}
              </div>
              <p className="mt-3 text-xs text-slate-400">JPG, PNG, atau WebP. Maksimal 5 MB.</p>
            </div>
          </div>

          <input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp" className="hidden" onChange={onFile} />
        </div>
      </div>
    </AdminLayout>
  );
}
