'use client';

import React, { useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { useAuth } from '../../../context/AuthContext';
import { adminApi } from '../../../lib/api';
import { Role, PermissionGroups } from '../../../types';
import {
  ShieldCheck,
  Plus,
  Pencil,
  Trash2,
  Check,
  AlertCircle,
  Loader2,
  X,
  Lock,
  Layers,
  Sparkles,
  Info
} from 'lucide-react';

export default function RolesManagementPage() {
  const { isSuperAdmin } = useAuth();
  const [roles, setRoles] = useState<Role[]>([]);
  const [permissionGroups, setPermissionGroups] = useState<PermissionGroups>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Modal State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingRole, setEditingRole] = useState<Role | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    slug: '',
    description: '',
    permissions: [] as string[],
  });
  const [submitting, setSubmitting] = useState(false);

  // Delete State
  const [deletingRole, setDeletingRole] = useState<Role | null>(null);

  const fetchData = async () => {
    try {
      setLoading(true);
      const [rolesRes, permsRes] = await Promise.all([
        adminApi.getRoles(),
        adminApi.getAvailablePermissions(),
      ]);
      setRoles(rolesRes);
      setPermissionGroups(permsRes);
    } catch (err: any) {
      setError(err?.message || 'Gagal memuat data role.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const openCreateModal = () => {
    setEditingRole(null);
    setFormData({
      name: '',
      slug: '',
      description: '',
      permissions: ['dashboard.view'],
    });
    setIsModalOpen(true);
  };

  const openEditModal = (role: Role) => {
    setEditingRole(role);
    setFormData({
      name: role.name,
      slug: role.slug,
      description: role.description || '',
      permissions: role.permissions || [],
    });
    setIsModalOpen(true);
  };

  const handleTogglePermission = (permKey: string) => {
    setFormData((prev) => {
      const exists = prev.permissions.includes(permKey);
      const updated = exists
        ? prev.permissions.filter((k) => k !== permKey && k !== '*')
        : [...prev.permissions.filter((k) => k !== '*'), permKey];
      return { ...prev, permissions: updated };
    });
  };

  const handleToggleGroup = (groupKeys: string[]) => {
    setFormData((prev) => {
      const allSelected = groupKeys.every((k) => prev.permissions.includes(k) || prev.permissions.includes('*'));
      let updated: string[];
      if (allSelected) {
        updated = prev.permissions.filter((k) => !groupKeys.includes(k) && k !== '*');
      } else {
        const set = new Set([...prev.permissions.filter((k) => k !== '*'), ...groupKeys]);
        updated = Array.from(set);
      }
      return { ...prev, permissions: updated };
    });
  };

  const handleSelectAllPermissions = () => {
    if (formData.permissions.includes('*')) {
      setFormData((prev) => ({ ...prev, permissions: [] }));
    } else {
      setFormData((prev) => ({ ...prev, permissions: ['*'] }));
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);

    try {
      if (editingRole) {
        await adminApi.updateRole(editingRole.id, {
          name: formData.name,
          description: formData.description,
          permissions: formData.permissions,
        });
        setSuccessMsg(`Role "${formData.name}" berhasil diperbarui.`);
      } else {
        await adminApi.createRole({
          name: formData.name,
          slug: formData.slug || undefined,
          description: formData.description,
          permissions: formData.permissions,
        });
        setSuccessMsg(`Role "${formData.name}" berhasil dibuat.`);
      }
      setIsModalOpen(false);
      fetchData();
    } catch (err: any) {
      setError(err?.message || 'Gagal menyimpan role.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async () => {
    if (!deletingRole) return;
    setSubmitting(true);
    try {
      await adminApi.deleteRole(deletingRole.id);
      setSuccessMsg(`Role "${deletingRole.name}" berhasil dihapus.`);
      setDeletingRole(null);
      fetchData();
    } catch (err: any) {
      setError(err?.message || 'Gagal menghapus role.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AdminLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <div className="flex items-center gap-2">
              <ShieldCheck className="h-6 w-6 text-emerald-600" />
              <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">
                Manajemen Hak Akses & Role
              </h2>
            </div>
            <p className="mt-1 text-xs md:text-sm text-slate-500">
              Buat dan sesuaikan hak akses untuk Kurir, Admin, Sales, atau tim operasional lainnya.
            </p>
          </div>

          <button
            onClick={openCreateModal}
            className="flex items-center justify-center gap-2 rounded-xl bg-emerald-600 px-4 py-2.5 text-xs font-bold text-white shadow-md shadow-emerald-600/25 hover:bg-emerald-500 transition-colors"
          >
            <Plus className="h-4 w-4" />
            <span>Tambah Role Baru</span>
          </button>
        </div>

        {/* Alerts */}
        {error && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-4 text-xs font-medium text-rose-700">
            <AlertCircle className="h-4 w-4 shrink-0" />
            <span>{error}</span>
          </div>
        )}
        {successMsg && (
          <div className="flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-xs font-medium text-emerald-700">
            <Check className="h-4 w-4 shrink-0" />
            <span>{successMsg}</span>
          </div>
        )}

        {/* Roles Table */}
        <div className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-xs">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs md:text-sm">
              <thead className="border-b border-slate-200 bg-slate-50/80 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                <tr>
                  <th className="py-3.5 px-5">Nama Role</th>
                  <th className="py-3.5 px-5">Slug Kode</th>
                  <th className="py-3.5 px-5">Deskripsi</th>
                  <th className="py-3.5 px-5">Cakupan Izin</th>
                  <th className="py-3.5 px-5">Pengguna</th>
                  <th className="py-3.5 px-5">Tipe</th>
                  <th className="py-3.5 px-5 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 font-medium">
                {loading ? (
                  <tr>
                    <td colSpan={7} className="py-12 text-center text-slate-400">
                      <div className="flex flex-col items-center gap-2">
                        <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />
                        <span>Memuat daftar role...</span>
                      </div>
                    </td>
                  </tr>
                ) : roles.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-12 text-center text-slate-400">
                      Belum ada role yang terdaftar.
                    </td>
                  </tr>
                ) : (
                  roles.map((role) => (
                    <tr key={role.id} className="hover:bg-slate-50/60 transition-colors">
                      <td className="py-4 px-5">
                        <div className="flex items-center gap-2.5">
                          <div className={`flex h-8 w-8 items-center justify-center rounded-lg font-bold text-xs ${
                            role.slug === 'super_admin'
                              ? 'bg-purple-100 text-purple-700'
                              : role.slug === 'admin'
                              ? 'bg-blue-100 text-blue-700'
                              : role.slug === 'driver'
                              ? 'bg-amber-100 text-amber-700'
                              : role.slug === 'sales'
                              ? 'bg-emerald-100 text-emerald-700'
                              : 'bg-slate-100 text-slate-700'
                          }`}>
                            {role.name.slice(0, 2).toUpperCase()}
                          </div>
                          <div>
                            <span className="font-bold text-slate-900">{role.name}</span>
                          </div>
                        </div>
                      </td>
                      <td className="py-4 px-5 font-mono text-xs text-slate-600">
                        {role.slug}
                      </td>
                      <td className="py-4 px-5 text-xs text-slate-500 max-w-xs truncate">
                        {role.description || '-'}
                      </td>
                      <td className="py-4 px-5">
                        {role.permissions?.includes('*') ? (
                          <span className="inline-flex items-center gap-1 rounded-md bg-purple-50 px-2 py-0.5 text-[11px] font-bold text-purple-700 border border-purple-200">
                            <Sparkles className="h-3 w-3" /> Semua Akses (*)
                          </span>
                        ) : (
                          <span className="rounded-md bg-slate-100 px-2 py-0.5 text-xs font-semibold text-slate-700">
                            {role.permissions?.length || 0} hak akses
                          </span>
                        )}
                      </td>
                      <td className="py-4 px-5 font-semibold text-slate-800">
                        {role.users_count || 0} orang
                      </td>
                      <td className="py-4 px-5">
                        {role.is_system ? (
                          <span className="inline-flex items-center gap-1 rounded-md bg-slate-100 px-2 py-0.5 text-[11px] font-semibold text-slate-700">
                            <Lock className="h-3 w-3" /> Sistem
                          </span>
                        ) : (
                          <span className="rounded-md bg-emerald-50 px-2 py-0.5 text-[11px] font-semibold text-emerald-700 border border-emerald-200">
                            Kustom
                          </span>
                        )}
                      </td>
                      <td className="py-4 px-5 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => openEditModal(role)}
                            className="rounded-lg p-1.5 text-slate-500 hover:bg-slate-100 hover:text-slate-800 transition-colors"
                            title="Edit Role"
                          >
                            <Pencil className="h-4 w-4" />
                          </button>
                          {!role.is_system && (
                            <button
                              onClick={() => setDeletingRole(role)}
                              disabled={(role.users_count || 0) > 0}
                              className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-30 transition-colors"
                              title={(role.users_count || 0) > 0 ? 'Role sedang digunakan oleh user' : 'Hapus Role'}
                            >
                              <Trash2 className="h-4 w-4" />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Modal Tambah/Edit Role */}
        {isModalOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
            <div className="w-full max-w-2xl max-h-[90vh] flex flex-col rounded-3xl bg-white shadow-2xl border border-slate-200 overflow-hidden animate-in fade-in zoom-in-95 duration-200">
              {/* Modal Header */}
              <div className="flex items-center justify-between border-b border-slate-100 px-6 py-4 bg-slate-50/50">
                <div className="flex items-center gap-2">
                  <ShieldCheck className="h-5 w-5 text-emerald-600" />
                  <h3 className="font-bold text-slate-900 text-base">
                    {editingRole ? `Edit Role: ${editingRole.name}` : 'Buat Role Baru'}
                  </h3>
                </div>
                <button
                  onClick={() => setIsModalOpen(false)}
                  className="rounded-xl p-1.5 text-slate-400 hover:bg-slate-200 hover:text-slate-700 transition-colors"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>

              {/* Modal Body */}
              <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-6 space-y-5">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                      Nama Role <span className="text-rose-500">*</span>
                    </label>
                    <input
                      type="text"
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                      placeholder="Contoh: Driver, Sales, Kurir"
                      required
                      className="w-full rounded-xl border border-slate-300 py-2 px-3 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                      Slug Kode
                    </label>
                    <input
                      type="text"
                      value={formData.slug}
                      onChange={(e) => setFormData({ ...formData, slug: e.target.value })}
                      disabled={!!editingRole?.is_system}
                      placeholder="driver, sales, admin_gudang"
                      className="w-full rounded-xl border border-slate-300 py-2 px-3 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 disabled:bg-slate-100 font-mono"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Deskripsi Role
                  </label>
                  <textarea
                    value={formData.description}
                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                    rows={2}
                    placeholder="Jelaskan tanggung jawab & fungsi role ini..."
                    className="w-full rounded-xl border border-slate-300 py-2 px-3 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                  />
                </div>

                {/* Permissions Matrix */}
                <div className="space-y-3 pt-2 border-t border-slate-200">
                  <div className="flex items-center justify-between">
                    <div>
                      <h4 className="text-sm font-bold text-slate-900">
                        Matriks Hak Akses (Permissions)
                      </h4>
                      <p className="text-xs text-slate-500">
                        Centang fitur yang boleh diakses oleh pengguna dengan role ini
                      </p>
                    </div>

                    <button
                      type="button"
                      onClick={handleSelectAllPermissions}
                      className="rounded-lg bg-slate-100 px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-200 transition-colors"
                    >
                      {formData.permissions.includes('*') ? 'Lepas Semua Akses' : 'Beri Akses Penuh (*)'}
                    </button>
                  </div>

                  {formData.permissions.includes('*') && (
                    <div className="rounded-xl border border-purple-200 bg-purple-50 p-3 text-xs text-purple-700 flex items-center gap-2">
                      <Sparkles className="h-4 w-4 shrink-0 text-purple-600" />
                      <span>Role ini memiliki <b>Akses Penuh Tanpa Batas (*)</b> ke seluruh sistem.</span>
                    </div>
                  )}

                  <div className="space-y-4 max-h-72 overflow-y-auto pr-2 divide-y divide-slate-100">
                    {Object.entries(permissionGroups).map(([moduleKey, group]) => {
                      const groupKeys = group.items.map((i) => i.key);
                      const isGroupAllSelected = groupKeys.every(
                        (k) => formData.permissions.includes(k) || formData.permissions.includes('*')
                      );

                      return (
                        <div key={moduleKey} className="pt-3 first:pt-0 space-y-2">
                          <div className="flex items-center justify-between">
                            <span className="text-xs font-bold text-slate-800">
                              {group.title}
                            </span>
                            <button
                              type="button"
                              onClick={() => handleToggleGroup(groupKeys)}
                              className="text-[11px] font-semibold text-emerald-600 hover:text-emerald-700"
                            >
                              {isGroupAllSelected ? 'Batal Semua' : 'Pilih Grup Ini'}
                            </button>
                          </div>

                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                            {group.items.map((item) => {
                              const checked =
                                formData.permissions.includes(item.key) ||
                                formData.permissions.includes('*');

                              return (
                                <label
                                  key={item.key}
                                  className={`flex items-start gap-2.5 rounded-xl border p-2.5 text-xs cursor-pointer transition-all ${
                                    checked
                                      ? 'border-emerald-300 bg-emerald-50/40 text-emerald-950 font-medium'
                                      : 'border-slate-200 bg-slate-50/50 text-slate-600 hover:border-slate-300'
                                  }`}
                                >
                                  <input
                                    type="checkbox"
                                    checked={checked}
                                    onChange={() => handleTogglePermission(item.key)}
                                    className="mt-0.5 rounded text-emerald-600 focus:ring-emerald-500"
                                  />
                                  <div className="flex flex-col">
                                    <span>{item.label}</span>
                                    <span className="font-mono text-[10px] text-slate-400">
                                      {item.key}
                                    </span>
                                  </div>
                                </label>
                              );
                            })}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* Modal Footer */}
                <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-100">
                  <button
                    type="button"
                    onClick={() => setIsModalOpen(false)}
                    className="rounded-xl px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 transition-colors"
                  >
                    Batal
                  </button>
                  <button
                    type="submit"
                    disabled={submitting}
                    className="flex items-center gap-2 rounded-xl bg-emerald-600 px-5 py-2 text-xs font-bold text-white shadow-md shadow-emerald-600/30 hover:bg-emerald-500 transition-colors disabled:opacity-50"
                  >
                    {submitting && <Loader2 className="h-3.5 w-3.5 animate-spin" />}
                    <span>{editingRole ? 'Simpan Perubahan' : 'Buat Role'}</span>
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal Konfirmasi Hapus */}
        {deletingRole && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
            <div className="w-full max-w-sm rounded-3xl bg-white p-6 shadow-2xl border border-slate-200">
              <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-rose-100 text-rose-600 mx-auto">
                <Trash2 className="h-6 w-6" />
              </div>
              <h3 className="mt-4 text-center font-bold text-slate-900 text-base">
                Hapus Role "{deletingRole.name}"?
              </h3>
              <p className="mt-1 text-center text-xs text-slate-500 leading-relaxed">
                Tindakan ini tidak dapat dibatalkan. Pastikan tidak ada user yang sedang menggunakan role ini.
              </p>

              <div className="mt-6 flex items-center justify-center gap-3">
                <button
                  type="button"
                  onClick={() => setDeletingRole(null)}
                  className="rounded-xl px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100"
                >
                  Batal
                </button>
                <button
                  type="button"
                  onClick={handleDelete}
                  disabled={submitting}
                  className="flex items-center gap-2 rounded-xl bg-rose-600 px-5 py-2 text-xs font-bold text-white shadow-md shadow-rose-600/30 hover:bg-rose-500 disabled:opacity-50"
                >
                  {submitting && <Loader2 className="h-3.5 w-3.5 animate-spin" />}
                  <span>Ya, Hapus</span>
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </AdminLayout>
  );
}
