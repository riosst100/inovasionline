'use client';

import React, { useEffect, useState } from 'react';
import { formatDate } from '../../../lib/date';
import AdminLayout from '../../../components/layout/AdminLayout';
import { useAuth } from '../../../context/AuthContext';
import { adminApi } from '../../../lib/api';
import { AdminUser, Role } from '../../../types';
import {
  UserCog,
  Plus,
  Pencil,
  Trash2,
  Check,
  AlertCircle,
  Loader2,
  X,
  Search,
  Filter,
  ShieldCheck,
  UserPlus
} from 'lucide-react';

export default function AdminUsersPage() {
  const { user: currentUser } = useAuth();
  const [staffUsers, setStaffUsers] = useState<AdminUser[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Filter & Search
  const [search, setSearch] = useState('');
  const [selectedRoleFilter, setSelectedRoleFilter] = useState('');

  // Modal State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingUser, setEditingUser] = useState<AdminUser | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    username: '',
    email: '',
    phone: '',
    password: '',
    role_id: '',
  });
  const [submitting, setSubmitting] = useState(false);

  // Delete State
  const [deletingUser, setDeletingUser] = useState<AdminUser | null>(null);

  const fetchStaff = async () => {
    try {
      setLoading(true);
      const [staffRes, rolesRes] = await Promise.all([
        adminApi.getStaffUsers({
          search: search || undefined,
          role_id: selectedRoleFilter || undefined,
        }),
        adminApi.getRoles(),
      ]);
      setStaffUsers(staffRes || []);
      setRoles(rolesRes || []);
    } catch (err: any) {
      setError(err?.message || 'Gagal memuat daftar staff admin.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStaff();
  }, [selectedRoleFilter]);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    fetchStaff();
  };

  const openCreateModal = () => {
    setEditingUser(null);
    setFormData({
      name: '',
      username: '',
      email: '',
      phone: '',
      password: '',
      role_id: roles[0]?.id || '',
    });
    setIsModalOpen(true);
  };

  const openEditModal = (u: AdminUser) => {
    setEditingUser(u);
    setFormData({
      name: u.name,
      username: u.username,
      email: u.email,
      phone: u.phone || '',
      password: '',
      role_id: u.role_id || (u.role?.id || ''),
    });
    setIsModalOpen(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);

    try {
      if (editingUser) {
        await adminApi.updateStaffUser(editingUser.id, {
          name: formData.name,
          username: formData.username,
          email: formData.email,
          phone: formData.phone || undefined,
          password: formData.password || undefined,
          role_id: formData.role_id || undefined,
        });
        setSuccessMsg(`Personil "${formData.name}" berhasil diperbarui.`);
      } else {
        await adminApi.createStaffUser({
          name: formData.name,
          username: formData.username,
          email: formData.email,
          phone: formData.phone || undefined,
          password: formData.password,
          role_id: formData.role_id,
        });
        setSuccessMsg(`Personil admin "${formData.name}" berhasil dibuat.`);
      }
      setIsModalOpen(false);
      fetchStaff();
    } catch (err: any) {
      setError(err?.message || 'Gagal menyimpan user admin.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async () => {
    if (!deletingUser) return;
    setSubmitting(true);
    try {
      await adminApi.deleteStaffUser(deletingUser.id);
      setSuccessMsg(`User "${deletingUser.name}" berhasil dihapus.`);
      setDeletingUser(null);
      fetchStaff();
    } catch (err: any) {
      setError(err?.message || 'Gagal menghapus user.');
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
              <UserCog className="h-6 w-6 text-emerald-600" />
              <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">
                User Admin & Personil Staff
              </h2>
            </div>
            <p className="mt-1 text-xs md:text-sm text-slate-500">
              Kelola daftar akun personil internal (Super Admin, Driver, Sales, dll) yang berhak login ke portal admin.
            </p>
          </div>

          <button
            onClick={openCreateModal}
            className="flex items-center justify-center gap-2 rounded-xl bg-emerald-600 px-4 py-2.5 text-xs font-bold text-white shadow-md shadow-emerald-600/25 hover:bg-emerald-500 transition-colors"
          >
            <UserPlus className="h-4 w-4" />
            <span>Tambah User Admin / Staff</span>
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

        {/* Filters & Search */}
        <div className="flex flex-col sm:flex-row items-center justify-between gap-3 rounded-2xl border border-slate-200/80 bg-white p-4 shadow-xs">
          <form onSubmit={handleSearchSubmit} className="relative w-full sm:w-80">
            <Search className="pointer-events-none absolute inset-y-0 left-0 my-auto ml-3 h-4 w-4 text-slate-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Cari nama, username, atau email..."
              className="w-full rounded-xl border border-slate-200 bg-slate-50 py-2 pl-9 pr-3 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:bg-white focus:ring-1 focus:ring-emerald-500"
            />
          </form>

          <div className="flex items-center gap-2.5 w-full sm:w-auto">
            <Filter className="h-4 w-4 text-slate-400 shrink-0" />
            <select
              value={selectedRoleFilter}
              onChange={(e) => setSelectedRoleFilter(e.target.value)}
              className="w-full sm:w-auto rounded-xl border border-slate-200 bg-slate-50 py-2 px-3 text-xs md:text-sm font-medium text-slate-700 outline-none focus:border-emerald-500 focus:bg-white"
            >
              <option value="">Semua Role</option>
              {roles.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.name}
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* Users Table */}
        <div className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-xs">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs md:text-sm">
              <thead className="border-b border-slate-200 bg-slate-50/80 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                <tr>
                  <th className="py-3.5 px-5">Nama & Profil</th>
                  <th className="py-3.5 px-5">Kontak</th>
                  <th className="py-3.5 px-5">Role Ditugaskan</th>
                  <th className="py-3.5 px-5">Terdaftar Sejak</th>
                  <th className="py-3.5 px-5 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 font-medium">
                {loading ? (
                  <tr>
                    <td colSpan={5} className="py-12 text-center text-slate-400">
                      <div className="flex flex-col items-center gap-2">
                        <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />
                        <span>Memuat daftar staff...</span>
                      </div>
                    </td>
                  </tr>
                ) : staffUsers.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="py-12 text-center text-slate-400">
                      Tidak ditemukan personil staff dengan kriteria pencarian ini.
                    </td>
                  </tr>
                ) : (
                  staffUsers.map((u) => {
                    const isSelf = currentUser?.id === u.id;
                    const roleLabel = u.role?.name || (u.is_super_admin ? 'Super Admin' : 'Staff');

                    return (
                      <tr key={u.id} className="hover:bg-slate-50/60 transition-colors">
                        <td className="py-4 px-5">
                          <div className="flex items-center gap-3">
                            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-slate-800 font-bold text-xs text-white shrink-0 shadow-xs">
                              {u.name.slice(0, 2).toUpperCase()}
                            </div>
                            <div>
                              <div className="flex items-center gap-2">
                                <span className="font-bold text-slate-900">{u.name}</span>
                                {isSelf && (
                                  <span className="rounded-md bg-emerald-100 px-1.5 py-0.2 text-[10px] font-bold text-emerald-700">
                                    Anda
                                  </span>
                                )}
                              </div>
                              <span className="text-xs text-slate-400">@{u.username} · {u.email}</span>
                            </div>
                          </div>
                        </td>
                        <td className="py-4 px-5">
                          <div className="flex flex-col text-xs text-slate-600">
                            <span>{u.phone || '-'}</span>
                          </div>
                        </td>
                        <td className="py-4 px-5">
                          <span className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-bold ${
                            roleLabel === 'Super Admin'
                              ? 'bg-purple-100 text-purple-700 border border-purple-200'
                              : roleLabel === 'Admin'
                              ? 'bg-blue-100 text-blue-700 border border-blue-200'
                              : roleLabel === 'Driver'
                              ? 'bg-amber-100 text-amber-800 border border-amber-200'
                              : roleLabel === 'Sales'
                              ? 'bg-emerald-100 text-emerald-700 border border-emerald-200'
                              : 'bg-slate-100 text-slate-700 border border-slate-200'
                          }`}>
                            <ShieldCheck className="h-3.5 w-3.5" />
                            <span>{roleLabel}</span>
                          </span>
                        </td>
                        <td className="py-4 px-5 text-xs text-slate-500">
                          {formatDate(u.created_at)}
                        </td>
                        <td className="py-4 px-5 text-right">
                          <div className="flex items-center justify-end gap-1.5">
                            <button
                              onClick={() => openEditModal(u)}
                              className="rounded-lg p-1.5 text-slate-500 hover:bg-slate-100 hover:text-slate-800 transition-colors"
                              title="Edit User"
                            >
                              <Pencil className="h-4 w-4" />
                            </button>
                            {!isSelf && (
                              <button
                                onClick={() => setDeletingUser(u)}
                                className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 transition-colors"
                                title="Hapus User"
                              >
                                <Trash2 className="h-4 w-4" />
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Modal Tambah/Edit User */}
        {isModalOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
            <div className="w-full max-w-lg rounded-3xl bg-white shadow-2xl border border-slate-200 overflow-hidden animate-in fade-in zoom-in-95 duration-200">
              {/* Header */}
              <div className="flex items-center justify-between border-b border-slate-100 px-6 py-4 bg-slate-50/50">
                <div className="flex items-center gap-2">
                  <UserPlus className="h-5 w-5 text-emerald-600" />
                  <h3 className="font-bold text-slate-900 text-base">
                    {editingUser ? `Edit Personil: ${editingUser.name}` : 'Tambah Personil Admin / Staff'}
                  </h3>
                </div>
                <button
                  onClick={() => setIsModalOpen(false)}
                  className="rounded-xl p-1.5 text-slate-400 hover:bg-slate-200 hover:text-slate-700 transition-colors"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>

              {/* Form */}
              <form onSubmit={handleSubmit} className="p-6 space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Nama Lengkap <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    placeholder="Contoh: Budi Santoso (Driver 01)"
                    required
                    className="w-full rounded-xl border border-slate-300 py-2.5 px-3.5 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Username <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={formData.username}
                    onChange={(e) => setFormData({ ...formData, username: e.target.value.toLowerCase().replace(/[^a-z0-9._]/g, '') })}
                    placeholder="budi.driver"
                    required
                    minLength={3}
                    maxLength={50}
                    autoCapitalize="none"
                    className="w-full rounded-xl border border-slate-300 py-2.5 px-3.5 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                  />
                  <p className="mt-1 text-[11px] text-slate-400">Dipakai untuk login. Huruf kecil, angka, titik, atau garis bawah.</p>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Alamat Email <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="email"
                    value={formData.email}
                    onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    placeholder="budi.driver@inovasionline.com"
                    required
                    className="w-full rounded-xl border border-slate-300 py-2.5 px-3.5 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Nomor Telepon / WhatsApp
                  </label>
                  <input
                    type="text"
                    value={formData.phone}
                    onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    placeholder="081234567890"
                    className="w-full rounded-xl border border-slate-300 py-2.5 px-3.5 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Pilih Role / Hak Akses <span className="text-rose-500">*</span>
                  </label>
                  <select
                    value={formData.role_id}
                    onChange={(e) => setFormData({ ...formData, role_id: e.target.value })}
                    required
                    className="w-full rounded-xl border border-slate-300 py-2.5 px-3.5 text-xs md:text-sm font-semibold text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 bg-white"
                  >
                    <option value="" disabled>-- Pilih Role --</option>
                    {roles.map((r) => (
                      <option key={r.id} value={r.id}>
                        {r.name} ({r.slug})
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Kata Sandi {editingUser ? '(Kosongkan jika tidak ingin mengubah)' : <span className="text-rose-500">*</span>}
                  </label>
                  <input
                    type="password"
                    value={formData.password}
                    onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                    placeholder={editingUser ? '••••••••' : 'Minimal 6 karakter'}
                    required={!editingUser}
                    className="w-full rounded-xl border border-slate-300 py-2.5 px-3.5 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                  />
                </div>

                {/* Footer */}
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
                    <span>{editingUser ? 'Simpan Perubahan' : 'Buat User'}</span>
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal Konfirmasi Hapus */}
        {deletingUser && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
            <div className="w-full max-w-sm rounded-3xl bg-white p-6 shadow-2xl border border-slate-200">
              <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-rose-100 text-rose-600 mx-auto">
                <Trash2 className="h-6 w-6" />
              </div>
              <h3 className="mt-4 text-center font-bold text-slate-900 text-base">
                Hapus Personil "{deletingUser.name}"?
              </h3>
              <p className="mt-1 text-center text-xs text-slate-500 leading-relaxed">
                Akun ini tidak akan dapat login lagi ke portal admin.
              </p>

              <div className="mt-6 flex items-center justify-center gap-3">
                <button
                  type="button"
                  onClick={() => setDeletingUser(null)}
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
