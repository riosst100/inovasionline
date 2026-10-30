'use client';

import React, { useEffect, useState } from 'react';
import { formatDate } from '../../../lib/date';
import Link from 'next/link';
import AdminLayout from '../../../components/layout/AdminLayout';
import VerificationStatus from '../../../components/customers/VerificationStatus';
import LastSeen from '../../../components/customers/LastSeen';
import { adminApi } from '../../../lib/api';
import { BannableFeature, Customer, GuestInstall } from '../../../types';
import {
  Users2,
  Search,
  Loader2,
  Ban,
  ShieldCheck,
  ShieldOff,
  MessageSquareOff,
  UserPlus,
  Eye,
  Smartphone
} from 'lucide-react';

const FEATURE_OPTIONS: { value: BannableFeature; label: string }[] = [
  { value: 'chat', label: 'Chat' },
  { value: 'posts', label: 'Postingan' },
  { value: 'purchase', label: 'Pembelian' },
];

export default function CustomersPage() {
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [tab, setTab] = useState<'registered' | 'guests'>('registered');
  const [guests, setGuests] = useState<GuestInstall[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [total, setTotal] = useState(0);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [banTarget, setBanTarget] = useState<Customer | null>(null);
  const [banFeatures, setBanFeatures] = useState<BannableFeature[]>([]);
  const [banReason, setBanReason] = useState('');

  const [showAdd, setShowAdd] = useState(false);
  const [addForm, setAddForm] = useState({ name: '', email: '', phone: '', password: '' });
  const [adding, setAdding] = useState(false);
  const [addError, setAddError] = useState('');

  const openAddModal = () => {
    setAddForm({ name: '', email: '', phone: '', password: '' });
    setAddError('');
    setShowAdd(true);
  };

  const handleAddCustomer = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setAdding(true);
      setAddError('');
      await adminApi.createCustomer(addForm);
      setShowAdd(false);
      await fetchCustomers();
    } catch (err) {
      setAddError(err instanceof Error ? err.message : 'Gagal menambahkan pelanggan.');
    } finally {
      setAdding(false);
    }
  };

  const fetchCustomers = async () => {
    try {
      setLoading(true);
      if (tab === 'guests') {
        const rows = await adminApi.getGuests({ search: search || undefined });
        setGuests(Array.isArray(rows) ? rows : []);
        return;
      }
      const res = await adminApi.getCustomers({ search: search || undefined });
      // apiRequest unwraps to `data`, which the backend returns as a plain array.
      const rows = (Array.isArray(res) ? res : res.data) || [];
      setCustomers(rows);
      setTotal(Array.isArray(res) ? rows.length : res.total || 0);
    } catch {
      setCustomers([]);
      setGuests([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCustomers();
  }, [tab]);

  const openBanModal = (c: Customer) => {
    setBanTarget(c);
    setBanFeatures(c.banned_features ?? []);
    setBanReason(c.ban_reason ?? '');
  };

  const toggleFeature = (f: BannableFeature) =>
    setBanFeatures((prev) => (prev.includes(f) ? prev.filter((x) => x !== f) : [...prev, f]));

  const allSelected = banFeatures.length === FEATURE_OPTIONS.length;

  const applyUpdated = (id: string, updated: Customer) =>
    setCustomers((prev) => prev.map((x) => (x.id === id ? { ...x, ...updated } : x)));

  const handleSaveBan = async () => {
    if (!banTarget) return;
    try {
      setBusyId(banTarget.id);
      const updated = banFeatures.length
        ? await adminApi.banCustomer(banTarget.id, banFeatures, banReason)
        : await adminApi.unbanCustomer(banTarget.id);
      applyUpdated(banTarget.id, updated);
      setBanTarget(null);
    } catch (err) {
      window.alert(err instanceof Error ? err.message : 'Gagal menyimpan pembatasan fitur.');
    } finally {
      setBusyId(null);
    }
  };

  const handleToggleBlock = async (c: Customer) => {
    let reason: string | null | undefined;
    if (c.is_blocked) {
      if (!window.confirm(`Buka blokir ${c.name}?`)) return;
    } else {
      reason = window.prompt(`Blokir ${c.name}? Isi alasan (opsional):`, '');
      if (reason === null) return;
    }

    try {
      setBusyId(c.id);
      const updated = c.is_blocked
        ? await adminApi.unblockCustomer(c.id)
        : await adminApi.blockCustomer(c.id, reason || undefined);
      applyUpdated(c.id, updated);
    } catch (err) {
      window.alert(err instanceof Error ? err.message : 'Gagal memperbarui status blokir.');
    } finally {
      setBusyId(null);
    }
  };

  const handleRevokeVerification = async (c: Customer) => {
    const reason = window.prompt(
      `Cabut verifikasi wajah ${c.name}? Customer wajib verifikasi ulang sebelum memakai COD/Paylater.\nAlasan (wajib):`,
      ''
    );
    if (reason === null) return;
    if (!reason.trim()) {
      window.alert('Alasan pencabutan wajib diisi.');
      return;
    }

    try {
      setBusyId(c.id);
      applyUpdated(c.id, await adminApi.revokeCustomerVerification(c.id, reason.trim()));
    } catch (err) {
      window.alert(err instanceof Error ? err.message : 'Gagal mencabut verifikasi.');
    } finally {
      setBusyId(null);
    }
  };

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    fetchCustomers();
  };

  return (
    <AdminLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <div className="flex items-center gap-2">
              <Users2 className="h-6 w-6 text-emerald-600" />
              <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">
                Data Pengguna
              </h2>
            </div>
            <p className="mt-1 text-xs md:text-sm text-slate-500">
              Daftar pembeli dan pengguna yang mendaftar melalui aplikasi mobile Inovasi Online ({total} pengguna).
            </p>
          </div>
          <button
            onClick={openAddModal}
            className="inline-flex items-center justify-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-xs md:text-sm font-semibold text-white hover:bg-emerald-700"
          >
            <UserPlus className="h-4 w-4" /> Tambah Customer
          </button>
        </div>

        {/* Tabs */}
        <div className="flex gap-2">
          {([['registered', 'Terdaftar'], ['guests', 'Guest (belum daftar)']] as const).map(([key, label]) => (
            <button
              key={key}
              onClick={() => setTab(key)}
              className={`rounded-xl px-4 py-2 text-xs md:text-sm font-semibold ${
                tab === key ? 'bg-emerald-600 text-white' : 'border border-slate-200 bg-white text-slate-600 hover:bg-slate-50'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        {/* Search */}
        <div className="flex items-center justify-between rounded-2xl border border-slate-200/80 bg-white p-4 shadow-xs">
          <form onSubmit={handleSearchSubmit} className="relative w-full sm:w-96">
            <Search className="pointer-events-none absolute inset-y-0 left-0 my-auto ml-3 h-4 w-4 text-slate-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={tab === 'guests' ? 'Cari perangkat, IP, atau install ID...' : 'Cari nama, email, atau no. telepon...'}
              className="w-full rounded-xl border border-slate-200 bg-slate-50 py-2 pl-9 pr-3 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:bg-white focus:ring-1 focus:ring-emerald-500"
            />
          </form>
        </div>

        {tab === 'guests' ? (
          <div className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-xs">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs md:text-sm">
                <thead className="border-b border-slate-200 bg-slate-50/80 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                  <tr>
                    <th className="py-3.5 px-5">Perangkat</th>
                    <th className="py-3.5 px-5">Platform</th>
                    <th className="py-3.5 px-5">IP</th>
                    <th className="py-3.5 px-5">Layar Terakhir</th>
                    <th className="py-3.5 px-5">Terakhir Online</th>
                    <th className="py-3.5 px-5">Pertama Terlihat</th>
                    <th className="py-3.5 px-5 text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 font-medium">
                  {loading ? (
                    <tr>
                      <td colSpan={7} className="py-12 text-center text-slate-400">
                        <Loader2 className="mx-auto h-6 w-6 animate-spin text-emerald-600" />
                      </td>
                    </tr>
                  ) : guests.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="py-12 text-center text-slate-400">Belum ada guest.</td>
                    </tr>
                  ) : (
                    guests.map((g) => (
                      <tr key={g.id} className="hover:bg-slate-50/60 transition-colors">
                        <td className="py-4 px-5">
                          <div className="flex items-center gap-3">
                            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-slate-100 text-slate-500 shrink-0">
                              <Smartphone className="h-4 w-4" />
                            </div>
                            <div>
                              <span className="font-bold text-slate-900">
                                {[g.device_brand, g.device_model].filter(Boolean).join(' ') || g.device_name || 'Perangkat tidak dikenal'}
                              </span>
                              {g.is_emulator && (
                                <span className="ml-2 rounded-md bg-amber-50 px-1.5 py-0.5 text-[10px] font-semibold text-amber-700">Emulator</span>
                              )}
                              <p className="text-xs text-slate-400">Guest · {g.install_id.slice(0, 8)}</p>
                            </div>
                          </div>
                        </td>
                        <td className="py-4 px-5 text-xs text-slate-600">
                          {g.platform}{g.os_version ? ` ${g.os_version}` : ''}
                          {g.app_version && <p className="text-slate-400">v{g.app_version}</p>}
                        </td>
                        <td className="py-4 px-5 text-xs text-slate-600">{g.ip_address || '-'}</td>
                        <td className="py-4 px-5 text-xs text-slate-600">{g.current_screen || '-'}</td>
                        <td className="py-4 px-5 whitespace-nowrap"><LastSeen at={g.last_seen_at} /></td>
                        <td className="py-4 px-5 text-xs text-slate-500">{g.first_seen_at ? formatDate(g.first_seen_at) : '-'}</td>
                        <td className="py-4 px-5 text-right whitespace-nowrap">
                          <Link
                            href={`/dashboard/customers/guests/${g.id}`}
                            className="inline-flex items-center gap-1 rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-50"
                          >
                            <Eye className="h-3.5 w-3.5" /> Detail
                          </Link>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        ) : (
        <div className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-xs">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs md:text-sm">
              <thead className="border-b border-slate-200 bg-slate-50/80 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                <tr>
                  <th className="py-3.5 px-5">Nama Pengguna</th>
                  <th className="py-3.5 px-5">Kontak</th>
                  <th className="py-3.5 px-5">Status Verifikasi</th>
                  <th className="py-3.5 px-5">Terakhir Online</th>
                  <th className="py-3.5 px-5">Terdaftar Sejak</th>
                  <th className="py-3.5 px-5">Status</th>
                  <th className="py-3.5 px-5 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 font-medium">
                {loading ? (
                  <tr>
                    <td colSpan={7} className="py-12 text-center text-slate-400">
                      <div className="flex flex-col items-center gap-2">
                        <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />
                        <span>Memuat data pelanggan...</span>
                      </div>
                    </td>
                  </tr>
                ) : customers.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-12 text-center text-slate-400">
                      Belum ada data pelanggan yang terdaftar.
                    </td>
                  </tr>
                ) : (
                  customers.map((c) => (
                    <tr key={c.id} className="hover:bg-slate-50/60 transition-colors">
                      <td className="py-4 px-5">
                        <div className="flex items-center gap-3">
                          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-slate-200 font-bold text-xs text-slate-700 shrink-0">
                            {c.name.slice(0, 2).toUpperCase()}
                          </div>
                          <div>
                            <span className="font-bold text-slate-900">{c.name}</span>
                            <p className="text-xs text-slate-400">{c.email}</p>
                          </div>
                        </div>
                      </td>
                      <td className="py-4 px-5 text-xs text-slate-600">
                        {c.phone || '-'}
                      </td>
                      <td className="py-4 px-5">
                        <VerificationStatus customer={c} />
                      </td>
                      <td className="py-4 px-5 whitespace-nowrap">
                        <LastSeen at={c.last_seen_at} />
                      </td>
                      <td className="py-4 px-5 text-xs text-slate-500">
                        {formatDate(c.created_at)}
                      </td>
                      <td className="py-4 px-5">
                        {c.is_blocked ? (
                          <span
                            title={c.block_reason || undefined}
                            className="inline-flex items-center gap-1 rounded-md bg-red-50 px-2 py-0.5 text-xs font-semibold text-red-700"
                          >
                            <Ban className="h-3.5 w-3.5" /> Diblokir
                          </span>
                        ) : (
                          <span className="rounded-md bg-emerald-50 px-2 py-0.5 text-xs font-semibold text-emerald-700">
                            Aktif
                          </span>
                        )}
                        {(c.banned_features ?? []).length > 0 && (
                          <div className="mt-1 flex flex-wrap gap-1" title={c.ban_reason || undefined}>
                            {c.banned_features.map((f) => (
                              <span key={f} className="rounded-md bg-amber-50 px-1.5 py-0.5 text-[10px] font-semibold text-amber-700">
                                Banned: {FEATURE_OPTIONS.find((o) => o.value === f)?.label ?? f}
                              </span>
                            ))}
                          </div>
                        )}
                      </td>
                      <td className="py-4 px-5 text-right space-x-2 whitespace-nowrap">
                        <Link
                          href={`/dashboard/customers/${c.id}`}
                          className="inline-flex items-center gap-1 rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-50"
                        >
                          <Eye className="h-3.5 w-3.5" /> Detail
                        </Link>
                        <button
                          onClick={() => openBanModal(c)}
                          disabled={busyId === c.id}
                          className="inline-flex items-center gap-1 rounded-lg border border-amber-200 px-3 py-1.5 text-xs font-semibold text-amber-700 hover:bg-amber-50 disabled:opacity-50"
                        >
                          <MessageSquareOff className="h-3.5 w-3.5" /> Banned
                        </button>
                        {c.verification_status === 'verified' && (
                          <button
                            onClick={() => handleRevokeVerification(c)}
                            disabled={busyId === c.id}
                            className="inline-flex items-center gap-1 rounded-lg border border-rose-200 px-3 py-1.5 text-xs font-semibold text-rose-700 hover:bg-rose-50 disabled:opacity-50"
                          >
                            <ShieldOff className="h-3.5 w-3.5" /> Cabut Verifikasi
                          </button>
                        )}
                        <button
                          onClick={() => handleToggleBlock(c)}
                          disabled={busyId === c.id}
                          className={`inline-flex items-center gap-1 rounded-lg border px-3 py-1.5 text-xs font-semibold disabled:opacity-50 ${
                            c.is_blocked
                              ? 'border-emerald-200 text-emerald-700 hover:bg-emerald-50'
                              : 'border-red-200 text-red-700 hover:bg-red-50'
                          }`}
                        >
                          {c.is_blocked ? <ShieldCheck className="h-3.5 w-3.5" /> : <Ban className="h-3.5 w-3.5" />}
                          {c.is_blocked ? 'Buka Blokir' : 'Blokir'}
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
        )}
      </div>

      {showAdd && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <form onSubmit={handleAddCustomer} className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
            <h3 className="text-lg font-extrabold text-slate-900">Tambah Customer</h3>
            <p className="mt-1 text-xs text-slate-500">Akun langsung aktif dan terverifikasi.</p>

            <div className="mt-4 space-y-3">
              {([
                ['name', 'Nama', 'text', true],
                ['email', 'Email', 'email', true],
                ['phone', 'No. Telepon (opsional)', 'tel', false],
                ['password', 'Password (min. 8 karakter)', 'password', true],
              ] as const).map(([key, label, type, required]) => (
                <label key={key} className="block text-xs font-semibold text-slate-700">
                  {label} {required && <span className="text-rose-500">*</span>}
                  <input
                    type={type}
                    required={required}
                    minLength={key === 'password' ? 8 : undefined}
                    value={addForm[key]}
                    onChange={(e) => setAddForm((p) => ({ ...p, [key]: e.target.value }))}
                    placeholder={label}
                    className="mt-1 w-full rounded-xl border border-slate-200 p-3 text-sm font-normal outline-none focus:border-emerald-500"
                  />
                </label>
              ))}
            </div>

            {addError && <p className="mt-3 text-xs font-semibold text-red-600">{addError}</p>}

            <div className="mt-5 flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setShowAdd(false)}
                className="rounded-lg border border-slate-200 px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-50"
              >
                Batal
              </button>
              <button
                type="submit"
                disabled={adding}
                className="rounded-lg bg-emerald-600 px-4 py-2 text-xs font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
              >
                {adding ? 'Menyimpan...' : 'Simpan'}
              </button>
            </div>
          </form>
        </div>
      )}

      {banTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
            <h3 className="text-lg font-extrabold text-slate-900">Banned fitur: {banTarget.name}</h3>
            <p className="mt-1 text-xs text-slate-500">
              Pilih fitur yang dilarang. Kosongkan semua lalu simpan untuk mencabut pembatasan.
            </p>

            <div className="mt-4 space-y-2 text-sm">
              <label className="flex items-center gap-2 font-semibold text-slate-900">
                <input
                  type="checkbox"
                  checked={allSelected}
                  onChange={() => setBanFeatures(allSelected ? [] : FEATURE_OPTIONS.map((o) => o.value))}
                />
                Semua fitur
              </label>
              {FEATURE_OPTIONS.map((o) => (
                <label key={o.value} className="flex items-center gap-2 pl-5 text-slate-700">
                  <input
                    type="checkbox"
                    checked={banFeatures.includes(o.value)}
                    onChange={() => toggleFeature(o.value)}
                  />
                  {o.label}
                </label>
              ))}
            </div>

            <textarea
              value={banReason}
              onChange={(e) => setBanReason(e.target.value)}
              placeholder="Alasan (opsional)"
              rows={3}
              className="mt-4 w-full rounded-xl border border-slate-200 p-3 text-sm outline-none focus:border-emerald-500"
            />

            <div className="mt-5 flex justify-end gap-2">
              <button
                onClick={() => setBanTarget(null)}
                className="rounded-lg border border-slate-200 px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-50"
              >
                Batal
              </button>
              <button
                onClick={handleSaveBan}
                disabled={busyId === banTarget.id}
                className="rounded-lg bg-amber-600 px-4 py-2 text-xs font-semibold text-white hover:bg-amber-700 disabled:opacity-50"
              >
                Simpan
              </button>
            </div>
          </div>
        </div>
      )}
    </AdminLayout>
  );
}
