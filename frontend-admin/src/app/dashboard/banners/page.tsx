'use client';

import React, { useEffect, useState, useMemo } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../lib/api';
import { Banner } from '../../../types';
import {
  Image as ImageIcon,
  Plus,
  Pencil,
  Trash2,
  Check,
  AlertCircle,
  Loader2,
  X,
  Search,
  CheckCircle2,
  ExternalLink,
  Sparkles,
  ArrowUp,
  ArrowDown,
  UploadCloud,
  Eye,
  EyeOff,
  Link as LinkIcon,
  Smartphone,
  Info
} from 'lucide-react';

export default function AdminBannersPage() {
  const [banners, setBanners] = useState<Banner[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Filter & Search
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'inactive'>('all');

  // Modal State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingBanner, setEditingBanner] = useState<Banner | null>(null);
  const [imageMode, setImageMode] = useState<'upload' | 'url'>('upload');
  const [formData, setFormData] = useState({
    name: '',
    image_url: '',
    link_url: '',
    is_active: true,
  });
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [filePreview, setFilePreview] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  // Status Toggle & Reorder Loading
  const [togglingId, setTogglingId] = useState<string | null>(null);
  const [reordering, setReordering] = useState(false);

  // Delete State
  const [deletingBanner, setDeletingBanner] = useState<Banner | null>(null);
  const [deleting, setDeleting] = useState(false);

  const fetchBanners = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await adminApi.getBanners();
      setBanners(data || []);
    } catch (err: any) {
      setError(err?.message || 'Gagal memuat data banner.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchBanners();
  }, []);

  // Filtered banners
  const filteredBanners = useMemo(() => {
    return banners.filter((b) => {
      const matchSearch =
        b.name.toLowerCase().includes(search.toLowerCase()) ||
        (b.link_url && b.link_url.toLowerCase().includes(search.toLowerCase()));

      const matchStatus =
        statusFilter === 'all'
          ? true
          : statusFilter === 'active'
          ? b.is_active
          : !b.is_active;

      return matchSearch && matchStatus;
    });
  }, [banners, search, statusFilter]);

  const activeCount = useMemo(() => banners.filter((b) => b.is_active).length, [banners]);
  const inactiveCount = useMemo(() => banners.filter((b) => !b.is_active).length, [banners]);

  // Handle open modal
  const handleOpenAddModal = () => {
    setEditingBanner(null);
    setImageMode('upload');
    setFormData({
      name: '',
      image_url: '',
      link_url: '',
      is_active: true,
    });
    setSelectedFile(null);
    setFilePreview(null);
    setIsModalOpen(true);
  };

  const handleOpenEditModal = (banner: Banner) => {
    setEditingBanner(banner);
    setImageMode(banner.image_url.startsWith('http') ? 'url' : 'upload');
    setFormData({
      name: banner.name,
      image_url: banner.image_url,
      link_url: banner.link_url || '',
      is_active: banner.is_active,
    });
    setSelectedFile(null);
    setFilePreview(banner.image_url);
    setIsModalOpen(true);
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setSelectedFile(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setFilePreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.name.trim()) {
      setError('Judul banner wajib diisi.');
      return;
    }

    if (!editingBanner && imageMode === 'upload' && !selectedFile) {
      setError('Silakan pilih file gambar banner untuk diunggah.');
      return;
    }

    if (!editingBanner && imageMode === 'url' && !formData.image_url.trim()) {
      setError('Silakan masukkan tautan (URL) gambar banner.');
      return;
    }

    try {
      setSubmitting(true);
      setError(null);

      const form = new FormData();
      form.append('name', formData.name.trim());
      form.append('link_url', formData.link_url.trim());
      form.append('is_active', formData.is_active ? '1' : '0');

      if (imageMode === 'upload' && selectedFile) {
        form.append('image', selectedFile);
      } else if (imageMode === 'url' && formData.image_url.trim()) {
        form.append('image_url', formData.image_url.trim());
      }

      if (editingBanner) {
        await adminApi.updateBanner(editingBanner.id, form);
        setSuccessMsg(`Banner "${formData.name}" berhasil diperbarui.`);
      } else {
        await adminApi.createBanner(form);
        setSuccessMsg(`Banner baru "${formData.name}" berhasil ditambahkan.`);
      }

      setIsModalOpen(false);
      await fetchBanners();
    } catch (err: any) {
      setError(err?.message || 'Gagal menyimpan konfigurasi banner.');
    } finally {
      setSubmitting(false);
    }
  };

  // Toggle active status
  const handleToggleActive = async (banner: Banner) => {
    try {
      setTogglingId(banner.id);
      await adminApi.toggleBannerStatus(banner.id);
      setBanners((prev) =>
        prev.map((b) => (b.id === banner.id ? { ...b, is_active: !b.is_active } : b))
      );
      setSuccessMsg(
        `Banner "${banner.name}" sekarang ${!banner.is_active ? 'Aktif (Tampil di App)' : 'Dinonaktifkan'}.`
      );
    } catch (err: any) {
      setError(err?.message || 'Gagal mengubah status banner.');
    } finally {
      setTogglingId(null);
    }
  };

  // Reorder banner
  const handleMove = async (index: number, direction: 'up' | 'down') => {
    const targetIndex = direction === 'up' ? index - 1 : index + 1;
    if (targetIndex < 0 || targetIndex >= banners.length) return;

    const newBanners = [...banners];
    const [moved] = newBanners.splice(index, 1);
    newBanners.splice(targetIndex, 0, moved);

    setBanners(newBanners);

    try {
      setReordering(true);
      await adminApi.reorderBanners(newBanners.map((b) => b.id));
      setSuccessMsg('Urutan banner berhasil diperbarui.');
    } catch (err: any) {
      setError(err?.message || 'Gagal memperbarui urutan banner.');
      fetchBanners();
    } finally {
      setReordering(false);
    }
  };

  // Delete banner
  const handleDelete = async () => {
    if (!deletingBanner) return;
    try {
      setDeleting(true);
      await adminApi.deleteBanner(deletingBanner.id);
      setSuccessMsg(`Banner "${deletingBanner.name}" berhasil dihapus.`);
      setDeletingBanner(null);
      await fetchBanners();
    } catch (err: any) {
      setError(err?.message || 'Gagal menghapus banner.');
    } finally {
      setDeleting(false);
    }
  };

  return (
    <AdminLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <div className="flex items-center gap-2">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50 text-emerald-600">
                <ImageIcon className="h-5 w-5" />
              </div>
              <div>
                <h1 className="text-xl md:text-2xl font-extrabold text-slate-900 tracking-tight">
                  Manajemen Banner Promo Aplikasi
                </h1>
                <p className="text-xs md:text-sm text-slate-500 mt-0.5">
                  Konfigurasikan carousel banner promosi yang tampil di beranda aplikasi mobile pelanggan.
                </p>
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={handleOpenAddModal}
              className="inline-flex items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:from-emerald-500 hover:to-teal-500 transition-all focus:ring-2 focus:ring-emerald-500/20 active:scale-95"
            >
              <Plus className="h-4 w-4" />
              <span>Tambah Banner</span>
            </button>
          </div>
        </div>

        {/* Sync Info Notification */}
        <div className="rounded-2xl border border-emerald-200/80 bg-emerald-50/60 p-4 flex items-start gap-3">
          <Smartphone className="h-5 w-5 text-emerald-600 shrink-0 mt-0.5" />
          <div className="text-xs md:text-sm text-slate-700 space-y-1">
            <p className="font-semibold text-emerald-950">
              Sinkronisasi Langsung ke Aplikasi Mobile
            </p>
            <p className="text-slate-600">
              Hanya banner berstatus <span className="font-semibold text-emerald-700">Aktif</span> yang akan muncul di hero slider aplikasi. Pengguna dapat me-refresh beranda aplikasi untuk langsung melihat urutan dan materi banner terbaru.
            </p>
          </div>
        </div>

        {/* Feedback Alerts */}
        {error && (
          <div className="flex items-center justify-between rounded-xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-700 shadow-xs">
            <div className="flex items-center gap-2">
              <AlertCircle className="h-5 w-5 shrink-0" />
              <span>{error}</span>
            </div>
            <button onClick={() => setError(null)} className="text-rose-500 hover:text-rose-700">
              <X className="h-4 w-4" />
            </button>
          </div>
        )}

        {successMsg && (
          <div className="flex items-center justify-between rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-700 shadow-xs">
            <div className="flex items-center gap-2">
              <CheckCircle2 className="h-5 w-5 shrink-0" />
              <span>{successMsg}</span>
            </div>
            <button onClick={() => setSuccessMsg(null)} className="text-emerald-500 hover:text-emerald-700">
              <X className="h-4 w-4" />
            </button>
          </div>
        )}

        {/* Stats Summary Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div className="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-xs flex items-center justify-between">
            <div>
              <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Total Banner</p>
              <h3 className="text-2xl font-black text-slate-900 mt-1">{banners.length}</h3>
              <p className="text-xs text-slate-400 mt-1">Materi terdaftar di sistem</p>
            </div>
            <div className="h-12 w-12 rounded-xl bg-slate-100 flex items-center justify-center text-slate-600">
              <ImageIcon className="h-6 w-6" />
            </div>
          </div>

          <div className="rounded-2xl border border-emerald-200/80 bg-emerald-50/40 p-5 shadow-xs flex items-center justify-between">
            <div>
              <p className="text-xs font-semibold text-emerald-700 uppercase tracking-wider">Banner Aktif (Tampil)</p>
              <div className="flex items-center gap-2 mt-1">
                <h3 className="text-2xl font-black text-emerald-900">{activeCount}</h3>
                <span className="flex h-2.5 w-2.5 rounded-full bg-emerald-500 animate-pulse" />
              </div>
              <p className="text-xs text-emerald-600/80 mt-1">Muncul di carousel pelanggan</p>
            </div>
            <div className="h-12 w-12 rounded-xl bg-emerald-100 flex items-center justify-center text-emerald-700">
              <Eye className="h-6 w-6" />
            </div>
          </div>

          <div className="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-xs flex items-center justify-between">
            <div>
              <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Nonaktif (Draft)</p>
              <h3 className="text-2xl font-black text-slate-600 mt-1">{inactiveCount}</h3>
              <p className="text-xs text-slate-400 mt-1">Disembunyikan dari aplikasi</p>
            </div>
            <div className="h-12 w-12 rounded-xl bg-slate-100 flex items-center justify-center text-slate-400">
              <EyeOff className="h-6 w-6" />
            </div>
          </div>
        </div>

        {/* Filter and Search Bar */}
        <div className="rounded-2xl border border-slate-200/80 bg-white p-4 shadow-xs flex flex-col md:flex-row gap-4 items-center justify-between">
          <div className="relative w-full md:w-80">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
            <input
              type="text"
              placeholder="Cari banner atau tautan..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full rounded-xl border border-slate-200 bg-slate-50/50 pl-10 pr-4 py-2 text-sm text-slate-800 placeholder-slate-400 focus:bg-white focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition-all"
            />
          </div>

          <div className="flex items-center gap-2 w-full md:w-auto">
            <span className="text-xs font-semibold text-slate-500 whitespace-nowrap">Filter Status:</span>
            <div className="inline-flex rounded-xl border border-slate-200 bg-slate-100/80 p-1 text-xs">
              <button
                onClick={() => setStatusFilter('all')}
                className={`px-3 py-1.5 rounded-lg font-semibold transition-all ${
                  statusFilter === 'all'
                    ? 'bg-white text-slate-900 shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                Semua ({banners.length})
              </button>
              <button
                onClick={() => setStatusFilter('active')}
                className={`px-3 py-1.5 rounded-lg font-semibold transition-all ${
                  statusFilter === 'active'
                    ? 'bg-white text-emerald-700 shadow-xs'
                    : 'text-slate-600 hover:text-emerald-700'
                }`}
              >
                Aktif ({activeCount})
              </button>
              <button
                onClick={() => setStatusFilter('inactive')}
                className={`px-3 py-1.5 rounded-lg font-semibold transition-all ${
                  statusFilter === 'inactive'
                    ? 'bg-white text-slate-800 shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                Nonaktif ({inactiveCount})
              </button>
            </div>
          </div>
        </div>

        {/* Banners Grid / List */}
        <div className="rounded-2xl border border-slate-200/80 bg-white p-6 shadow-xs">
          {loading ? (
            <div className="py-20 flex flex-col items-center justify-center text-emerald-600 gap-3">
              <Loader2 className="h-8 w-8 animate-spin" />
              <p className="text-xs text-slate-500 font-medium">Memuat data banner promo...</p>
            </div>
          ) : filteredBanners.length === 0 ? (
            <div className="py-16 text-center text-slate-400 space-y-3">
              <div className="h-16 w-16 mx-auto rounded-2xl bg-slate-100 flex items-center justify-center text-slate-400">
                <ImageIcon className="h-8 w-8" />
              </div>
              <h4 className="font-bold text-slate-700">Tidak ada banner yang cocok</h4>
              <p className="text-xs text-slate-400 max-w-sm mx-auto">
                {banners.length === 0
                  ? 'Belum ada banner promo yang dibuat. Klik tombol "Tambah Banner" untuk membuat materi promo pertama Anda.'
                  : 'Coba ubah kata kunci pencarian atau filter status untuk menemukan banner.'}
              </p>
              {banners.length === 0 && (
                <button
                  onClick={handleOpenAddModal}
                  className="mt-2 inline-flex items-center gap-1.5 px-4 py-2 bg-emerald-600 text-white rounded-xl text-xs font-bold hover:bg-emerald-700 transition"
                >
                  <Plus className="h-4 w-4" />
                  Tambah Banner Baru
                </button>
              )}
            </div>
          ) : (
            <div className="space-y-4">
              <div className="flex items-center justify-between text-xs text-slate-500 px-1">
                <span>
                  Menampilkan <b>{filteredBanners.length}</b> banner (urut berdasarkan prioritas tampil #1, #2, dst.)
                </span>
                {reordering && (
                  <span className="flex items-center gap-1 text-emerald-600 font-semibold">
                    <Loader2 className="h-3.5 w-3.5 animate-spin" />
                    Menyimpan urutan...
                  </span>
                )}
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
                {filteredBanners.map((banner, index) => {
                  const globalIndex = banners.findIndex((b) => b.id === banner.id);
                  const isFirst = globalIndex === 0;
                  const isLast = globalIndex === banners.length - 1;

                  return (
                    <div
                      key={banner.id}
                      className={`group relative overflow-hidden rounded-2xl border transition-all hover:shadow-md flex flex-col justify-between ${
                        banner.is_active
                          ? 'border-slate-200 bg-white hover:border-emerald-300'
                          : 'border-slate-200/60 bg-slate-50/70 opacity-80'
                      }`}
                    >
                      {/* Card Image Banner */}
                      <div>
                        <div className="relative aspect-[16/9] w-full overflow-hidden bg-slate-100">
                          <img
                            src={banner.image_url}
                            alt={banner.name}
                            className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
                            onError={(e) => {
                              (e.target as HTMLElement).style.display = 'none';
                            }}
                          />
                          <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-black/10 to-transparent pointer-events-none" />

                          {/* Order Badge */}
                          <div className="absolute top-3 left-3 flex items-center gap-1.5">
                            <span className="rounded-lg bg-black/60 backdrop-blur-md px-2.5 py-1 text-xs font-black text-white shadow-xs">
                              #{globalIndex + 1}
                            </span>
                            {isFirst && (
                              <span className="rounded-lg bg-emerald-600 px-2 py-0.5 text-[10px] font-bold text-white shadow-xs">
                                Utama
                              </span>
                            )}
                          </div>

                          {/* Active / Inactive Badge */}
                          <div className="absolute top-3 right-3">
                            <span
                              className={`inline-flex items-center gap-1 rounded-lg px-2.5 py-1 text-xs font-bold shadow-xs backdrop-blur-md ${
                                banner.is_active
                                  ? 'bg-emerald-600/90 text-white'
                                  : 'bg-slate-800/80 text-slate-300'
                              }`}
                            >
                              <span
                                className={`h-1.5 w-1.5 rounded-full ${
                                  banner.is_active ? 'bg-white animate-pulse' : 'bg-slate-400'
                                }`}
                              />
                              {banner.is_active ? 'Aktif' : 'Nonaktif'}
                            </span>
                          </div>

                          {/* Quick Reorder Controls on Hover */}
                          <div className="absolute bottom-2 right-2 flex items-center gap-1 bg-black/50 backdrop-blur-md p-1 rounded-lg">
                            <button
                              onClick={() => handleMove(globalIndex, 'up')}
                              disabled={isFirst || reordering}
                              title="Pindah ke Atas"
                              className="h-7 w-7 rounded flex items-center justify-center text-white/90 hover:bg-white/20 disabled:opacity-30 disabled:hover:bg-transparent transition"
                            >
                              <ArrowUp className="h-4 w-4" />
                            </button>
                            <button
                              onClick={() => handleMove(globalIndex, 'down')}
                              disabled={isLast || reordering}
                              title="Pindah ke Bawah"
                              className="h-7 w-7 rounded flex items-center justify-center text-white/90 hover:bg-white/20 disabled:opacity-30 disabled:hover:bg-transparent transition"
                            >
                              <ArrowDown className="h-4 w-4" />
                            </button>
                          </div>
                        </div>

                        {/* Card Content */}
                        <div className="p-4 space-y-2">
                          <h4 className="font-extrabold text-slate-900 text-sm leading-snug line-clamp-1">
                            {banner.name}
                          </h4>

                          <div className="flex items-center gap-1.5 text-xs text-slate-500">
                            <LinkIcon className="h-3.5 w-3.5 text-slate-400 shrink-0" />
                            {banner.link_url ? (
                              <span
                                title={banner.link_url}
                                className="font-mono text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded truncate max-w-[200px]"
                              >
                                {banner.link_url}
                              </span>
                            ) : (
                              <span className="italic text-slate-400">Tidak ada tautan (Pratinjau)</span>
                            )}
                          </div>
                        </div>
                      </div>

                      {/* Card Footer Actions */}
                      <div className="px-4 py-3 border-t border-slate-100 bg-slate-50/50 flex items-center justify-between gap-2">
                        {/* Toggle Active Button */}
                        <button
                          onClick={() => handleToggleActive(banner)}
                          disabled={togglingId === banner.id}
                          className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold transition ${
                            banner.is_active
                              ? 'bg-amber-50 text-amber-700 hover:bg-amber-100 border border-amber-200/60'
                              : 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100 border border-emerald-200/60'
                          }`}
                        >
                          {togglingId === banner.id ? (
                            <Loader2 className="h-3.5 w-3.5 animate-spin" />
                          ) : banner.is_active ? (
                            <>
                              <EyeOff className="h-3.5 w-3.5" />
                              <span>Sembunyikan</span>
                            </>
                          ) : (
                            <>
                              <Eye className="h-3.5 w-3.5" />
                              <span>Aktifkan</span>
                            </>
                          )}
                        </button>

                        <div className="flex items-center gap-1">
                          <button
                            onClick={() => handleOpenEditModal(banner)}
                            title="Edit Banner"
                            className="h-8 w-8 rounded-lg border border-slate-200 bg-white flex items-center justify-center text-slate-600 hover:border-emerald-500 hover:text-emerald-600 transition shadow-xs"
                          >
                            <Pencil className="h-3.5 w-3.5" />
                          </button>
                          <button
                            onClick={() => setDeletingBanner(banner)}
                            title="Hapus Banner"
                            className="h-8 w-8 rounded-lg border border-slate-200 bg-white flex items-center justify-center text-rose-500 hover:border-rose-300 hover:bg-rose-50 transition shadow-xs"
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                          </button>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Add / Edit Banner Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs animate-in fade-in duration-200">
          <div className="w-full max-w-lg rounded-3xl bg-white shadow-2xl border border-slate-200 overflow-hidden flex flex-col max-h-[90vh]">
            {/* Modal Header */}
            <div className="px-6 py-4 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
              <div className="flex items-center gap-2.5">
                <div className="h-9 w-9 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
                  <ImageIcon className="h-5 w-5" />
                </div>
                <div>
                  <h3 className="text-base font-extrabold text-slate-900">
                    {editingBanner ? 'Edit Materi Banner' : 'Tambah Banner Promo Baru'}
                  </h3>
                  <p className="text-xs text-slate-500">
                    Sesuaikan judul, gambar, dan navigasi klik banner di aplikasi.
                  </p>
                </div>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="h-8 w-8 rounded-lg text-slate-400 hover:bg-slate-100 hover:text-slate-600 flex items-center justify-center transition"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            {/* Modal Form */}
            <form onSubmit={handleSubmit} className="p-6 space-y-4 overflow-y-auto">
              {/* Name */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Nama / Judul Banner <span className="text-rose-500">*</span>
                </label>
                <input
                  type="text"
                  required
                  placeholder="Contoh: Promo Gratis Ongkir 15 Menit"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="w-full rounded-xl border border-slate-200 px-3.5 py-2.5 text-sm text-slate-900 placeholder-slate-400 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition"
                />
              </div>

              {/* Image Source Selection */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                  Materi Gambar Banner <span className="text-rose-500">*</span>
                </label>

                {/* Tabs Upload / URL */}
                <div className="grid grid-cols-2 p-1 rounded-xl bg-slate-100 text-xs font-bold mb-3">
                  <button
                    type="button"
                    onClick={() => setImageMode('upload')}
                    className={`py-1.5 rounded-lg transition ${
                      imageMode === 'upload'
                        ? 'bg-white text-emerald-700 shadow-xs'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    Upload Berkas File
                  </button>
                  <button
                    type="button"
                    onClick={() => setImageMode('url')}
                    className={`py-1.5 rounded-lg transition ${
                      imageMode === 'url'
                        ? 'bg-white text-emerald-700 shadow-xs'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    Gunakan Tautan URL
                  </button>
                </div>

                {imageMode === 'upload' ? (
                  <div className="space-y-2">
                    <label className="flex flex-col items-center justify-center border-2 border-dashed border-slate-300 rounded-2xl p-4 cursor-pointer hover:border-emerald-400 hover:bg-emerald-50/20 transition bg-slate-50/50">
                      <UploadCloud className="h-8 w-8 text-slate-400 mb-1" />
                      <span className="text-xs font-bold text-slate-700">Pilih atau Seret Gambar di sini</span>
                      <span className="text-[11px] text-slate-400 mt-0.5">Format JPG, PNG, WEBP (Maksimal 5MB)</span>
                      <input
                        type="file"
                        accept="image/png,image/jpeg,image/webp"
                        onChange={handleFileChange}
                        className="hidden"
                      />
                    </label>
                  </div>
                ) : (
                  <div>
                    <input
                      type="url"
                      placeholder="https://images.unsplash.com/..."
                      value={formData.image_url}
                      onChange={(e) => {
                        setFormData({ ...formData, image_url: e.target.value });
                        setFilePreview(e.target.value);
                      }}
                      className="w-full rounded-xl border border-slate-200 px-3.5 py-2.5 text-sm text-slate-900 placeholder-slate-400 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition"
                    />
                    <p className="text-[11px] text-slate-400 mt-1">
                      Pastikan URL gambar dapat diakses secara publik.
                    </p>
                  </div>
                )}

                {/* Image Preview Box */}
                {filePreview && (
                  <div className="mt-3 relative rounded-xl border border-slate-200 overflow-hidden aspect-[16/9] bg-slate-100">
                    <img
                      src={filePreview}
                      alt="Preview"
                      className="w-full h-full object-cover"
                      onError={() => setFilePreview(null)}
                    />
                    <div className="absolute bottom-2 left-2 bg-black/60 backdrop-blur-xs text-white text-[10px] font-bold px-2 py-0.5 rounded">
                      Pratinjau Banner
                    </div>
                  </div>
                )}
              </div>

              {/* Link URL / Click Action */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Tautan Aksi Klik (Opsional)
                </label>
                <input
                  type="text"
                  placeholder="Contoh: /flash-sale atau https://..."
                  value={formData.link_url}
                  onChange={(e) => setFormData({ ...formData, link_url: e.target.value })}
                  className="w-full rounded-xl border border-slate-200 px-3.5 py-2.5 text-sm text-slate-900 placeholder-slate-400 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 transition"
                />

                {/* Preset Suggestions */}
                <div className="mt-2 flex flex-wrap items-center gap-1.5">
                  <span className="text-[11px] text-slate-400">Pilihan cepat:</span>
                  {[
                    { label: 'Promo Gercep', val: '/flash-sale' },
                    { label: 'Katalog Kategori', val: '/categories' },
                    { label: 'Keranjang', val: '/cart' },
                    { label: 'Chat CS', val: '/chat' },
                  ].map((preset) => (
                    <button
                      key={preset.val}
                      type="button"
                      onClick={() => setFormData({ ...formData, link_url: preset.val })}
                      className="text-[11px] font-semibold px-2 py-0.5 rounded-md bg-slate-100 hover:bg-emerald-50 hover:text-emerald-700 text-slate-600 transition border border-slate-200"
                    >
                      {preset.label}
                    </button>
                  ))}
                </div>
                <p className="text-[11px] text-slate-400 mt-1">
                  Jika dikosongkan, ketukan pada banner di aplikasi akan membuka mode layar penuh pratinjau foto.
                </p>
              </div>

              {/* Status Switch */}
              <div className="pt-2">
                <label className="flex items-center gap-3 p-3 rounded-2xl border border-slate-200 bg-slate-50/50 cursor-pointer hover:bg-slate-50 transition">
                  <input
                    type="checkbox"
                    checked={formData.is_active}
                    onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                    className="h-4 w-4 rounded text-emerald-600 focus:ring-emerald-500 border-slate-300"
                  />
                  <div>
                    <span className="text-xs font-bold text-slate-800 block">
                      Aktifkan Banner Ini
                    </span>
                    <span className="text-[11px] text-slate-500 block">
                      Banner akan langsung dimuat di beranda aplikasi mobile pelanggan.
                    </span>
                  </div>
                </label>
              </div>

              {/* Modal Buttons */}
              <div className="pt-4 flex items-center justify-end gap-3 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2.5 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-50 text-sm font-semibold transition"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white text-sm font-bold shadow-sm transition disabled:opacity-50"
                >
                  {submitting && <Loader2 className="h-4 w-4 animate-spin" />}
                  <span>{editingBanner ? 'Simpan Perubahan' : 'Buat Banner'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {deletingBanner && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs animate-in fade-in duration-200">
          <div className="w-full max-w-sm rounded-3xl bg-white shadow-2xl border border-slate-200 p-6 space-y-4">
            <div className="h-12 w-12 rounded-2xl bg-rose-50 text-rose-600 flex items-center justify-center mx-auto">
              <Trash2 className="h-6 w-6" />
            </div>
            <div className="text-center space-y-1">
              <h3 className="font-extrabold text-slate-900 text-base">Hapus Banner Promo?</h3>
              <p className="text-xs text-slate-500">
                Apakah Anda yakin ingin menghapus materi banner <b>&quot;{deletingBanner.name}&quot;</b>? Tindakan ini tidak dapat dibatalkan.
              </p>
            </div>
            <div className="flex items-center justify-center gap-3 pt-2">
              <button
                type="button"
                onClick={() => setDeletingBanner(null)}
                className="w-1/2 py-2.5 rounded-xl border border-slate-200 text-slate-600 text-sm font-semibold hover:bg-slate-50 transition"
              >
                Batal
              </button>
              <button
                type="button"
                disabled={deleting}
                onClick={handleDelete}
                className="w-1/2 py-2.5 rounded-xl bg-rose-600 hover:bg-rose-700 text-white text-sm font-bold shadow-sm transition flex items-center justify-center gap-1.5 disabled:opacity-50"
              >
                {deleting && <Loader2 className="h-4 w-4 animate-spin" />}
                <span>Hapus</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </AdminLayout>
  );
}
