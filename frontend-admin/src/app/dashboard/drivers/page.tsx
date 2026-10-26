'use client';

import React, { useEffect, useState } from 'react';
import { formatDateTime, formatTime } from '../../../lib/date';
import AdminLayout from '../../../components/layout/AdminLayout';
import ImportExportActions from '../../../components/data-transfer/ImportExportActions';
import DataTransferProgress from '../../../components/data-transfer/DataTransferProgress';
import { adminApi } from '../../../lib/api';
import { useDataTransfers } from '../../../lib/dataTransfer';
import { waLink } from '../../../lib/whatsapp';
import { Driver, DriverOrder } from '../../../types';
import {
  Truck,
  Plus,
  Pencil,
  Trash2,
  Check,
  AlertCircle,
  Loader2,
  X,
  Search,
  Filter,
  CheckCircle2,
  XCircle,
  Package,
  Calendar,
  MapPin,
  Phone,
  Mail,
  Car,
  ExternalLink,
  ChevronRight,
  Sparkles
} from 'lucide-react';

const IMPORT_HINT = (
  <>
    Kolom: <b>name</b> (wajib), <b>phone</b> (wajib, nomor HP untuk login), vehicle_type, vehicle_plate_number,
    is_active (1/0), password (wajib untuk kurir baru, min. 6 karakter). Kurir dengan nomor HP yang sudah ada akan{' '}
    <b>diperbarui</b>
    {' '}(password kosong = tidak diubah); selain itu dibuat baru. Password tidak ikut diekspor.
  </>
);

export default function DriversPage() {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Search & Status Filter
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'inactive'>('all');

  // Add / Edit Modal State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingDriver, setEditingDriver] = useState<Driver | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    phone: '',
    vehicle_type: 'Motor Honda Vario 160',
    vehicle_plate_number: '',
    password: '',
    is_active: true,
  });
  const [submitting, setSubmitting] = useState(false);

  // Status Toggle Loading
  const [togglingId, setTogglingId] = useState<string | null>(null);

  // Delete State
  const [deletingDriver, setDeletingDriver] = useState<Driver | null>(null);

  // Driver Orders Modal State
  const [selectedDriverForOrders, setSelectedDriverForOrders] = useState<Driver | null>(null);
  const [driverOrders, setDriverOrders] = useState<DriverOrder[]>([]);
  const [ordersLoading, setOrdersLoading] = useState(false);

  const fetchDrivers = async () => {
    try {
      setLoading(true);
      const res = await adminApi.getDrivers({
        search: search || undefined,
        is_active: statusFilter === 'all' ? undefined : statusFilter === 'active',
      });
      setDrivers(res || []);
    } catch (err: any) {
      setError(err?.message || 'Gagal memuat data kurir.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDrivers();
  }, [statusFilter]);

  const transfers = useDataTransfers({ resource: 'drivers', perPage: 5 }, (t) => {
    if (t.type === 'import' && t.status === 'completed') fetchDrivers();
  });

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    fetchDrivers();
  };

  const openCreateModal = () => {
    setEditingDriver(null);
    setFormData({
      name: '',
      phone: '',
      vehicle_type: 'Motor',
      vehicle_plate_number: '',
      password: '',
      is_active: true,
    });
    setIsModalOpen(true);
  };

  const openEditModal = (driver: Driver) => {
    setEditingDriver(driver);
    setFormData({
      name: driver.name,
      phone: driver.phone || '',
      vehicle_type: driver.vehicle_type || 'Motor',
      vehicle_plate_number: driver.vehicle_plate_number || '',
      password: '',
      is_active: driver.is_active,
    });
    setIsModalOpen(true);
  };

  const handleToggleStatus = async (driver: Driver) => {
    setTogglingId(driver.id);
    setError(null);
    try {
      const updated = await adminApi.setDriverStatus(driver.id, !driver.is_active);
      setDrivers((prev) =>
        prev.map((d) => (d.id === driver.id ? { ...d, is_active: updated.is_active } : d))
      );
      setSuccessMsg(
        `Status kurir "${driver.name}" berhasil diubah menjadi ${
          updated.is_active ? 'Aktif' : 'Non-Aktif'
        }.`
      );
    } catch (err: any) {
      setError(err?.message || 'Gagal mengubah status kurir.');
    } finally {
      setTogglingId(null);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);

    try {
      if (editingDriver) {
        await adminApi.updateDriver(editingDriver.id, {
          name: formData.name,
          phone: formData.phone.trim(),
          vehicle_type: formData.vehicle_type || undefined,
          vehicle_plate_number: formData.vehicle_plate_number.trim() || null,
          password: formData.password || undefined,
          is_active: formData.is_active,
        });
        setSuccessMsg(`Data kurir "${formData.name}" berhasil diperbarui.`);
      } else {
        await adminApi.createDriver({
          name: formData.name,
          phone: formData.phone.trim(),
          vehicle_type: formData.vehicle_type || undefined,
          vehicle_plate_number: formData.vehicle_plate_number || undefined,
          password: formData.password,
          is_active: formData.is_active,
        });
        setSuccessMsg(`Kurir baru "${formData.name}" berhasil didaftarkan.`);
      }
      setIsModalOpen(false);
      fetchDrivers();
    } catch (err: any) {
      setError(err?.message || 'Gagal menyimpan data kurir.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async () => {
    if (!deletingDriver) return;
    setSubmitting(true);
    try {
      await adminApi.deleteDriver(deletingDriver.id);
      setSuccessMsg(`Kurir "${deletingDriver.name}" berhasil dihapus.`);
      setDeletingDriver(null);
      fetchDrivers();
    } catch (err: any) {
      setError(err?.message || 'Gagal menghapus kurir.');
    } finally {
      setSubmitting(false);
    }
  };

  // Open Orders Detail Modal
  const openOrdersModal = async (driver: Driver) => {
    setSelectedDriverForOrders(driver);
    setOrdersLoading(true);
    setDriverOrders([]);
    try {
      const res = await adminApi.getDriverOrders(driver.id);
      setDriverOrders(res || []);
    } catch {
      setDriverOrders([]);
    } finally {
      setOrdersLoading(false);
    }
  };

  const formatRupiah = (num: number) => {
    return new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      maximumFractionDigits: 0,
    }).format(num);
  };

  return (
    <AdminLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <div className="flex items-center gap-2">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-100 text-amber-700">
                <Truck className="h-5 w-5" />
              </div>
              <div>
                <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">
                  Manajemen Kurir
                </h2>
                <p className="text-xs md:text-sm text-slate-500">
                  Daftar kurir pengantaran, status kendaraan, dan riwayat pesanan yang diantar.
                </p>
              </div>
            </div>
          </div>

          <div className="flex flex-wrap items-start gap-2">
            <ImportExportActions resource="drivers" onStarted={transfers.track} importHint={IMPORT_HINT} />
            <button
              onClick={openCreateModal}
              className="flex items-center justify-center gap-2 rounded-xl bg-emerald-600 px-4 py-2.5 text-xs font-bold text-white shadow-md shadow-emerald-600/25 hover:bg-emerald-500 transition-colors"
            >
              <Plus className="h-4 w-4" />
              <span>Tambah Kurir Baru</span>
            </button>
          </div>
        </div>

        <DataTransferProgress items={transfers.items} resource="drivers" />

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

        {/* Filter & Search Bar */}
        <div className="flex flex-col sm:flex-row items-center justify-between gap-3 rounded-2xl border border-slate-200/80 bg-white p-4 shadow-xs">
          <form onSubmit={handleSearchSubmit} className="relative w-full sm:w-80">
            <Search className="pointer-events-none absolute inset-y-0 left-0 my-auto ml-3 h-4 w-4 text-slate-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Cari kurir, plat nomor, atau HP..."
              className="w-full rounded-xl border border-slate-200 bg-slate-50 py-2 pl-9 pr-3 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:bg-white focus:ring-1 focus:ring-emerald-500"
            />
          </form>

          <div className="flex items-center gap-2.5 w-full sm:w-auto">
            <Filter className="h-4 w-4 text-slate-400 shrink-0" />
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as any)}
              className="w-full sm:w-auto rounded-xl border border-slate-200 bg-slate-50 py-2 px-3 text-xs md:text-sm font-medium text-slate-700 outline-none focus:border-emerald-500 focus:bg-white"
            >
              <option value="all">Semua Status (Aktif & Non-Aktif)</option>
              <option value="active">Hanya Aktif</option>
              <option value="inactive">Hanya Non-Aktif</option>
            </select>
          </div>
        </div>

        {/* Drivers Table */}
        <div className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-xs">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs md:text-sm">
              <thead className="border-b border-slate-200 bg-slate-50/80 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                <tr>
                  <th className="py-3.5 px-5">Profil Kurir</th>
                  <th className="py-3.5 px-5">Nomor WA</th>
                  <th className="py-3.5 px-5">Kendaraan</th>
                  <th className="py-3.5 px-5">Plat Nomor</th>
                  <th className="py-3.5 px-5">Status</th>
                  <th className="py-3.5 px-5">Total Pesanan Diantar</th>
                  <th className="py-3.5 px-5 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 font-medium">
                {loading ? (
                  <tr>
                    <td colSpan={7} className="py-12 text-center text-slate-400">
                      <div className="flex flex-col items-center gap-2">
                        <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />
                        <span>Memuat data kurir...</span>
                      </div>
                    </td>
                  </tr>
                ) : drivers.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-12 text-center text-slate-400">
                      Tidak ditemukan data kurir.
                    </td>
                  </tr>
                ) : (
                  drivers.map((driver) => (
                    <tr key={driver.id} className="hover:bg-slate-50/60 transition-colors">
                      {/* Name & Avatar */}
                      <td className="py-4 px-5">
                        <div className="flex items-center gap-3">
                          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-amber-600 font-bold text-xs text-white shrink-0 shadow-xs">
                            {driver.name.slice(0, 2).toUpperCase()}
                          </div>
                          <div>
                            <span className="font-bold text-slate-900">{driver.name}</span>
                          </div>
                        </div>
                      </td>

                      {/* WhatsApp */}
                      <td className="py-4 px-5 text-xs text-slate-600">
                        {waLink(driver.phone) ? (
                          <a
                            href={waLink(driver.phone)!}
                            target="_blank"
                            rel="noopener noreferrer"
                            title="Chat via WhatsApp"
                            className="font-medium text-emerald-700 hover:underline"
                          >
                            {driver.phone}
                          </a>
                        ) : (
                          driver.phone || '-'
                        )}
                      </td>

                      {/* Vehicle */}
                      <td className="py-4 px-5 text-xs font-semibold text-slate-800">
                        {driver.vehicle_type || 'Motor'}
                      </td>

                      {/* Plate */}
                      <td className="py-4 px-5">
                        {driver.vehicle_plate_number ? (
                          <span className="font-mono text-[11px] font-bold text-amber-700 bg-amber-50 border border-amber-200 rounded px-1.5 py-0.2 w-fit">
                            {driver.vehicle_plate_number}
                          </span>
                        ) : (
                          <span className="text-[11px] text-slate-400">-</span>
                        )}
                      </td>

                      {/* Status with Toggle Button */}
                      <td className="py-4 px-5">
                        <button
                          type="button"
                          onClick={() => handleToggleStatus(driver)}
                          disabled={togglingId === driver.id}
                          className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-bold transition-all ${
                            driver.is_active
                              ? 'bg-emerald-100 text-emerald-800 border border-emerald-300 hover:bg-emerald-200'
                              : 'bg-slate-200 text-slate-600 border border-slate-300 hover:bg-slate-300'
                          }`}
                          title="Klik untuk ubah status"
                        >
                          {togglingId === driver.id ? (
                            <Loader2 className="h-3.5 w-3.5 animate-spin" />
                          ) : driver.is_active ? (
                            <CheckCircle2 className="h-3.5 w-3.5 text-emerald-600" />
                          ) : (
                            <XCircle className="h-3.5 w-3.5 text-slate-500" />
                          )}
                          <span>{driver.is_active ? 'Aktif' : 'Non-Aktif'}</span>
                        </button>
                      </td>

                      {/* Total Orders - CLICKABLE */}
                      <td className="py-4 px-5">
                        <button
                          type="button"
                          onClick={() => openOrdersModal(driver)}
                          className="group inline-flex items-center gap-2 rounded-xl bg-slate-100 hover:bg-emerald-50 px-3 py-1.5 border border-slate-200 hover:border-emerald-300 text-xs font-bold text-slate-800 hover:text-emerald-700 transition-all shadow-2xs"
                          title="Klik untuk melihat detail list pesanan"
                        >
                          <Package className="h-4 w-4 text-slate-500 group-hover:text-emerald-600" />
                          <span>{driver.delivered_orders_count || 0} Pesanan</span>
                          <ChevronRight className="h-3.5 w-3.5 text-slate-400 group-hover:text-emerald-600 group-hover:translate-x-0.5 transition-transform" />
                        </button>
                      </td>

                      {/* Actions */}
                      <td className="py-4 px-5 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => openEditModal(driver)}
                            className="rounded-lg p-1.5 text-slate-500 hover:bg-slate-100 hover:text-slate-800 transition-colors"
                            title="Edit Kurir"
                          >
                            <Pencil className="h-4 w-4" />
                          </button>
                          <button
                            onClick={() => setDeletingDriver(driver)}
                            className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 transition-colors"
                            title="Hapus Kurir"
                          >
                            <Trash2 className="h-4 w-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* MODAL: LIST PESANAN DRIVER (Triggered by clicking total pesanan) */}
        {selectedDriverForOrders && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
            <div className="w-full max-w-2xl max-h-[85vh] flex flex-col rounded-3xl bg-white shadow-2xl border border-slate-200 overflow-hidden animate-in fade-in zoom-in-95 duration-200">
              {/* Modal Header */}
              <div className="flex items-center justify-between border-b border-slate-100 px-6 py-4 bg-slate-50/80">
                <div className="flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-100 text-amber-700">
                    <Truck className="h-5 w-5" />
                  </div>
                  <div>
                    <h3 className="font-bold text-slate-900 text-base">
                      Daftar Pesanan: {selectedDriverForOrders.name}
                    </h3>
                    <p className="text-xs text-slate-500">
                      Plat: {selectedDriverForOrders.vehicle_plate_number || '-'} ({selectedDriverForOrders.vehicle_type || 'Motor'}) • Total: {driverOrders.length} Pesanan
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setSelectedDriverForOrders(null)}
                  className="rounded-xl p-1.5 text-slate-400 hover:bg-slate-200 hover:text-slate-700 transition-colors"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>

              {/* Modal Body */}
              <div className="flex-1 overflow-y-auto p-6">
                {ordersLoading ? (
                  <div className="py-12 flex flex-col items-center justify-center text-emerald-600 gap-2">
                    <Loader2 className="h-6 w-6 animate-spin" />
                    <span className="text-xs text-slate-500">Memuat rincian pesanan...</span>
                  </div>
                ) : driverOrders.length === 0 ? (
                  <div className="py-12 text-center text-slate-400">
                    <Package className="h-10 w-10 mx-auto text-slate-300 mb-2" />
                    <p className="text-sm font-semibold text-slate-700">Belum ada pesanan yang diantar</p>
                    <p className="text-xs text-slate-400 mt-1">Kurir ini belum ditugaskan untuk mengantar pesanan apapun.</p>
                  </div>
                ) : (
                  <div className="space-y-3.5">
                    {driverOrders.map((order) => (
                      <div
                        key={order.id}
                        className="rounded-2xl border border-slate-200 bg-slate-50/50 p-4 transition-all hover:bg-white hover:border-slate-300 shadow-2xs"
                      >
                        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 border-b border-slate-200/60 pb-3">
                          <div className="flex items-center gap-2">
                            <span className="font-mono text-xs font-bold text-slate-900 bg-slate-200 px-2 py-0.5 rounded-md">
                              {order.order_number}
                            </span>
                            <span className="text-xs font-semibold text-slate-700">
                              {order.customer_name}
                            </span>
                          </div>

                          <div className="flex items-center gap-2">
                            <span className={`rounded-full px-2.5 py-0.5 text-[11px] font-bold ${
                              order.status === 'completed'
                                ? 'bg-emerald-100 text-emerald-800'
                                : order.status === 'on_delivery'
                                ? 'bg-amber-100 text-amber-800'
                                : 'bg-blue-100 text-blue-800'
                            }`}>
                              {order.status === 'completed'
                                ? 'Selesai'
                                : order.status === 'on_delivery'
                                ? 'Sedang Dikirim'
                                : order.status === 'processing'
                                ? 'Perlu Diproses'
                                : order.status === 'ready'
                                ? 'Perlu Dikirim'
                                : order.status === 'cancelled'
                                ? 'Dibatalkan'
                                : order.status === 'pending'
                                ? 'Belum Bayar'
                                : order.status}
                            </span>
                            <span className="font-bold text-xs text-slate-900">
                              {formatRupiah(order.grand_total)}
                            </span>
                          </div>
                        </div>

                        {/* Delivery Details */}
                        <div className="mt-3 flex items-start gap-2 text-xs text-slate-600">
                          <MapPin className="h-4 w-4 shrink-0 text-slate-400 mt-0.5" />
                          <span className="leading-relaxed">
                            {order.delivery_address}
                          </span>
                        </div>

                        <div className="mt-2.5 flex items-center justify-between text-[11px] text-slate-400 border-t border-slate-100 pt-2">
                          <div className="flex items-center gap-1">
                            <Calendar className="h-3.5 w-3.5" />
                            <span>Order: {formatDateTime(order.created_at)}</span>
                          </div>
                          {order.completed_at && (
                            <span className="text-emerald-600 font-semibold">
                              Selesai: {formatTime(order.completed_at)}
                            </span>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Modal Footer */}
              <div className="flex items-center justify-end border-t border-slate-100 px-6 py-3.5 bg-slate-50/50">
                <button
                  type="button"
                  onClick={() => setSelectedDriverForOrders(null)}
                  className="rounded-xl bg-slate-200 px-4 py-2 text-xs font-bold text-slate-700 hover:bg-slate-300 transition-colors"
                >
                  Tutup
                </button>
              </div>
            </div>
          </div>
        )}

        {/* MODAL: TAMBAH / EDIT DRIVER */}
        {isModalOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
            <div className="w-full max-w-lg rounded-3xl bg-white shadow-2xl border border-slate-200 overflow-hidden animate-in fade-in zoom-in-95 duration-200">
              <div className="flex items-center justify-between border-b border-slate-100 px-6 py-4 bg-slate-50/50">
                <div className="flex items-center gap-2">
                  <Truck className="h-5 w-5 text-emerald-600" />
                  <h3 className="font-bold text-slate-900 text-base">
                    {editingDriver ? `Edit Kurir: ${editingDriver.name}` : 'Tambah Kurir Baru'}
                  </h3>
                </div>
                <button
                  onClick={() => setIsModalOpen(false)}
                  className="rounded-xl p-1.5 text-slate-400 hover:bg-slate-200 hover:text-slate-700 transition-colors"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>

              <form onSubmit={handleSubmit} className="p-6 space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Nama Lengkap Kurir <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    placeholder="Contoh: Budi Santoso"
                    required
                    className="w-full rounded-xl border border-slate-300 py-2.5 px-3.5 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Nomor HP / WhatsApp <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="tel"
                    inputMode="tel"
                    value={formData.phone}
                    onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    placeholder="081234567890"
                    required
                    className="w-full rounded-xl border border-slate-300 py-2.5 px-3.5 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                  />
                  <p className="mt-1 text-[11px] text-slate-500">Dipakai kurir untuk login di aplikasi kurir.</p>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                      Jenis Kendaraan
                    </label>
                    <input
                      type="text"
                      value={formData.vehicle_type}
                      onChange={(e) => setFormData({ ...formData, vehicle_type: e.target.value })}
                      placeholder="Motor Honda Vario, Mobil Van, dll"
                      className="w-full rounded-xl border border-slate-300 py-2.5 px-3.5 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">
                      Nomor Plat Polisi
                    </label>
                    <input
                      type="text"
                      value={formData.vehicle_plate_number}
                      onChange={(e) => setFormData({ ...formData, vehicle_plate_number: e.target.value })}
                      placeholder="B 1234 ABC"
                      className="w-full rounded-xl border border-slate-300 py-2.5 px-3.5 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 font-mono"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Kata Sandi {editingDriver ? '(Kosongkan jika tidak diubah)' : <span className="text-rose-500">*</span>}
                  </label>
                  <input
                    type="password"
                    value={formData.password}
                    onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                    placeholder={editingDriver ? '••••••••' : 'Minimal 6 karakter'}
                    required={!editingDriver}
                    className="w-full rounded-xl border border-slate-300 py-2.5 px-3.5 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                  />
                </div>

                {/* Status Toggle */}
                <div className="pt-2">
                  <label className="flex items-center gap-3 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={formData.is_active}
                      onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                      className="h-4 w-4 rounded text-emerald-600 focus:ring-emerald-500"
                    />
                    <div className="flex flex-col">
                      <span className="text-xs font-bold text-slate-900">
                        Status Kurir Aktif
                      </span>
                      <span className="text-[11px] text-slate-500">
                        Kurir aktif dapat login dan menerima tugas pengiriman pesanan.
                      </span>
                    </div>
                  </label>
                </div>

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
                    <span>{editingDriver ? 'Simpan Perubahan' : 'Daftarkan Kurir'}</span>
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* MODAL: KONFIRMASI HAPUS DRIVER */}
        {deletingDriver && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
            <div className="w-full max-w-sm rounded-3xl bg-white p-6 shadow-2xl border border-slate-200">
              <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-rose-100 text-rose-600 mx-auto">
                <Trash2 className="h-6 w-6" />
              </div>
              <h3 className="mt-4 text-center font-bold text-slate-900 text-base">
                Hapus Kurir "{deletingDriver.name}"?
              </h3>
              <p className="mt-1 text-center text-xs text-slate-500 leading-relaxed">
                Akun kurir ini tidak akan dapat login lagi ke aplikasi.
              </p>

              <div className="mt-6 flex items-center justify-center gap-3">
                <button
                  type="button"
                  onClick={() => setDeletingDriver(null)}
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
