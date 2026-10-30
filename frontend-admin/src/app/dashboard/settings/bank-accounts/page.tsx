'use client';

import React, { useCallback, useEffect, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { useAuth } from '../../../../context/AuthContext';
import { adminApi, ApiError } from '../../../../lib/api';
import { BankAccount, BankAccountType } from '../../../../types';
import {
  AlertCircle,
  Check,
  CheckCircle2,
  Copy,
  Landmark,
  Loader2,
  Pencil,
  Plus,
  Trash2,
  Wallet,
  X,
} from 'lucide-react';

const POPULAR_BANKS = ['BCA', 'BRI', 'Mandiri', 'BNI', 'BSI', 'BTN', 'CIMB Niaga', 'Permata', 'SeaBank', 'Bank Jago'];
const POPULAR_EWALLETS = ['DANA', 'GoPay', 'OVO', 'ShopeePay', 'LinkAja', 'i.saku'];

type FormState = {
  type: BankAccountType;
  bank_name: string;
  account_number: string;
  account_holder_name: string;
  description: string;
  instructions: string;
  is_enabled: boolean;
};

const emptyForm: FormState = {
  type: 'bank_transfer',
  bank_name: '',
  account_number: '',
  account_holder_name: '',
  description: '',
  instructions: '',
  is_enabled: true,
};

export default function BankAccountsPage() {
  const { canManage } = useAuth();
  const canWrite = canManage('bank_accounts');

  const [items, setItems] = useState<BankAccount[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [filterType, setFilterType] = useState<'all' | BankAccountType>('all');
  const [search, setSearch] = useState('');
  const [modal, setModal] = useState<{ editing: BankAccount | null } | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);

  const load = useCallback(async () => {
    try {
      setItems(await adminApi.getBankAccounts());
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat daftar bank & e-wallet.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const openCreate = (defaultType: BankAccountType = 'bank_transfer') => {
    setForm({ ...emptyForm, type: defaultType });
    setError(null);
    setModal({ editing: null });
  };

  const openEdit = (item: BankAccount) => {
    setForm({
      type: item.type === 'ewallet' ? 'ewallet' : 'bank_transfer',
      bank_name: item.bank_name ?? item.name,
      account_number: item.account_number ?? '',
      account_holder_name: item.account_holder_name ?? '',
      description: item.description ?? '',
      instructions: item.instructions ?? '',
      is_enabled: item.is_enabled,
    });
    setError(null);
    setModal({ editing: item });
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!modal) return;
    const editing = modal.editing;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const bankName = form.bank_name.trim();
      const saved = await adminApi.saveBankAccount(
        {
          type: form.type,
          name: bankName,
          bank_name: bankName,
          account_number: form.account_number.trim(),
          account_holder_name: form.account_holder_name.trim(),
          description: form.description.trim() || null,
          instructions: form.instructions.trim() || null,
          is_enabled: form.is_enabled,
        },
        editing?.id
      );
      setModal(null);
      setSuccess(editing ? `${saved.bank_name ?? saved.name} berhasil diperbarui.` : `${saved.bank_name ?? saved.name} berhasil ditambahkan.`);
      await load();
    } catch (err) {
      const first = err instanceof ApiError && err.errors ? Object.values(err.errors)[0]?.[0] : null;
      setError(first || (err instanceof ApiError ? err.message : 'Gagal menyimpan rekening/e-wallet.'));
    } finally {
      setSaving(false);
    }
  };

  const toggle = async (item: BankAccount) => {
    if (!canWrite) return;
    setBusyId(item.id);
    setError(null);
    setSuccess(null);
    try {
      const updated = await adminApi.toggleBankAccount(item.id);
      setItems((prev) => prev.map((x) => (x.id === updated.id ? updated : x)));
      setSuccess(`${updated.bank_name ?? updated.name} ${updated.is_enabled ? 'diaktifkan' : 'dinonaktifkan'}.`);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Gagal mengubah status.');
    } finally {
      setBusyId(null);
    }
  };

  const remove = async (item: BankAccount) => {
    const label = item.bank_name ?? item.name;
    if (!confirm(`Hapus ${item.type === 'ewallet' ? 'e-wallet' : 'rekening bank'} "${label}" (${item.account_number ?? '-'})?`)) {
      return;
    }
    setBusyId(item.id);
    setError(null);
    setSuccess(null);
    try {
      await adminApi.deleteBankAccount(item.id);
      setSuccess(`${label} berhasil dihapus.`);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Gagal menghapus rekening/e-wallet.');
    } finally {
      setBusyId(null);
    }
  };

  const copyAccountNumber = async (item: BankAccount) => {
    if (!item.account_number) return;
    try {
      await navigator.clipboard.writeText(item.account_number);
      setCopiedId(item.id);
      setTimeout(() => setCopiedId((prev) => (prev === item.id ? null : prev)), 1500);
    } catch {
      // Clipboard blocked on non-HTTPS
    }
  };

  const q = search.trim().toLowerCase();
  const visible = items.filter((item) => {
    if (filterType !== 'all' && item.type !== filterType) return false;
    if (!q) return true;
    return [item.bank_name, item.name, item.account_number, item.account_holder_name, item.description]
      .some((v) => v?.toLowerCase().includes(q));
  });

  const bankCount = items.filter((x) => x.type === 'bank_transfer').length;
  const ewalletCount = items.filter((x) => x.type === 'ewallet').length;
  const suggestions = form.type === 'ewallet' ? POPULAR_EWALLETS : POPULAR_BANKS;

  const inputCls =
    'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500 disabled:bg-slate-50 disabled:text-slate-400';

  return (
    <AdminLayout>
      <div className="mx-auto max-w-6xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Bank & E-Wallet Aplikasi</h1>
            <p className="text-sm text-slate-500">
              Kelola daftar rekening bank dan e-wallet (DANA, GoPay, OVO, dll.) milik aplikasi/admin untuk pembayaran checkout dan top up manual dengan bukti transfer.
            </p>
          </div>
          {canWrite && (
            <button
              onClick={() => openCreate('bank_transfer')}
              className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
            >
              <Plus className="h-4 w-4" /> Tambah Bank / E-Wallet
            </button>
          )}
        </div>

        {error && !modal && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4 shrink-0" /> {error}
          </div>
        )}
        {success && (
          <div className="flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-700">
            <CheckCircle2 className="h-4 w-4 shrink-0" /> {success}
          </div>
        )}

        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="inline-flex rounded-xl border border-slate-200 bg-white p-1 shadow-xs">
            {[
              { key: 'all' as const, label: `Semua (${items.length})` },
              { key: 'bank_transfer' as const, label: `Bank (${bankCount})` },
              { key: 'ewallet' as const, label: `E-Wallet (${ewalletCount})` },
            ].map((tab) => (
              <button
                key={tab.key}
                type="button"
                onClick={() => setFilterType(tab.key)}
                className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${
                  filterType === tab.key
                    ? 'bg-emerald-600 text-white'
                    : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari nama bank/e-wallet, nomor rekening, atau atas nama..."
            className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500 sm:max-w-xs"
          />
        </div>

        <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
          {loading ? (
            <div className="flex justify-center p-10">
              <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
            </div>
          ) : visible.length === 0 ? (
            <div className="p-10 text-center">
              <p className="text-sm text-slate-500">
                {items.length === 0
                  ? 'Belum ada rekening bank atau e-wallet yang ditambahkan.'
                  : 'Tidak ada data yang cocok dengan pencarian.'}
              </p>
              {canWrite && items.length === 0 && (
                <div className="mt-4 flex justify-center gap-2">
                  <button
                    type="button"
                    onClick={() => openCreate('bank_transfer')}
                    className="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 px-3.5 py-2 text-xs font-semibold text-slate-700 hover:bg-slate-50"
                  >
                    <Landmark className="h-4 w-4 text-sky-600" /> Tambah Bank
                  </button>
                  <button
                    type="button"
                    onClick={() => openCreate('ewallet')}
                    className="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 px-3.5 py-2 text-xs font-semibold text-slate-700 hover:bg-slate-50"
                  >
                    <Wallet className="h-4 w-4 text-violet-600" /> Tambah E-Wallet
                  </button>
                </div>
              )}
            </div>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">Jenis</th>
                  <th className="px-4 py-3">Bank / E-Wallet</th>
                  <th className="px-4 py-3">Nomor Rekening / Akun</th>
                  <th className="px-4 py-3">Atas Nama</th>
                  <th className="px-4 py-3">Instruksi</th>
                  <th className="px-4 py-3">Status</th>
                  {canWrite && <th className="px-4 py-3" />}
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {visible.map((item) => {
                  const isEwallet = item.type === 'ewallet';
                  const title = item.bank_name || item.name;
                  return (
                    <tr key={item.id}>
                      <td className="whitespace-nowrap px-4 py-3">
                        <span
                          className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold ${
                            isEwallet ? 'bg-violet-100 text-violet-700' : 'bg-sky-100 text-sky-700'
                          }`}
                        >
                          {isEwallet ? <Wallet className="h-3.5 w-3.5" /> : <Landmark className="h-3.5 w-3.5" />}
                          {isEwallet ? 'E-Wallet' : 'Bank'}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <div className="font-semibold text-slate-900">{title}</div>
                        {item.description && <div className="text-xs text-slate-500">{item.description}</div>}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3">
                        {item.account_number ? (
                          <div className="inline-flex items-center gap-1.5">
                            <span className="font-mono font-semibold text-slate-800">{item.account_number}</span>
                            <button
                              type="button"
                              onClick={() => copyAccountNumber(item)}
                              title="Salin nomor"
                              className="rounded p-1 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
                            >
                              {copiedId === item.id ? (
                                <Check className="h-3.5 w-3.5 text-emerald-600" />
                              ) : (
                                <Copy className="h-3.5 w-3.5" />
                              )}
                            </button>
                          </div>
                        ) : (
                          <span className="text-slate-400">-</span>
                        )}
                      </td>
                      <td className="px-4 py-3 font-medium text-slate-700">{item.account_holder_name || '-'}</td>
                      <td className="max-w-xs px-4 py-3 text-xs text-slate-500">
                        {item.instructions ? (
                          <span className="line-clamp-2">{item.instructions}</span>
                        ) : (
                          <span className="text-slate-400">-</span>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        <button
                          type="button"
                          role="switch"
                          aria-checked={item.is_enabled}
                          aria-label={`${item.is_enabled ? 'Nonaktifkan' : 'Aktifkan'} ${title}`}
                          onClick={() => toggle(item)}
                          disabled={!canWrite || busyId !== null}
                          className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors disabled:opacity-50 ${
                            item.is_enabled ? 'bg-emerald-500' : 'bg-slate-300'
                          }`}
                        >
                          <span
                            className={`inline-block h-5 w-5 rounded-full bg-white shadow transition-transform ${
                              item.is_enabled ? 'translate-x-5' : 'translate-x-0.5'
                            }`}
                          />
                        </button>
                      </td>
                      {canWrite && (
                        <td className="whitespace-nowrap px-4 py-3 text-right">
                          <button
                            onClick={() => openEdit(item)}
                            title="Ubah"
                            className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
                          >
                            <Pencil className="h-4 w-4" />
                          </button>
                          <button
                            onClick={() => remove(item)}
                            disabled={busyId !== null}
                            title="Hapus"
                            className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-50"
                          >
                            {busyId === item.id ? (
                              <Loader2 className="h-4 w-4 animate-spin" />
                            ) : (
                              <Trash2 className="h-4 w-4" />
                            )}
                          </button>
                        </td>
                      )}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {modal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/50 p-4">
          <form
            onSubmit={submit}
            className="max-h-[90vh] w-full max-w-lg space-y-4 overflow-y-auto rounded-2xl bg-white p-6 shadow-xl"
          >
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-slate-900">
                {modal.editing ? 'Ubah Bank / E-Wallet' : 'Tambah Bank / E-Wallet'}
              </h2>
              <button
                type="button"
                onClick={() => setModal(null)}
                className="rounded-lg p-1 text-slate-400 hover:bg-slate-100"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            {error && (
              <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
                <AlertCircle className="h-4 w-4 shrink-0" /> {error}
              </div>
            )}

            <div>
              <label className="mb-1.5 block text-xs font-medium text-slate-600">
                Jenis Pembayaran <span className="text-rose-500">*</span>
              </label>
              <div className="grid grid-cols-2 gap-2.5">
                {[
                  { value: 'bank_transfer' as const, label: 'Rekening Bank', hint: 'BCA, BRI, Mandiri, BNI, dll.', icon: Landmark },
                  { value: 'ewallet' as const, label: 'E-Wallet', hint: 'DANA, GoPay, OVO, ShopeePay, dll.', icon: Wallet },
                ].map((opt) => {
                  const Icon = opt.icon;
                  const active = form.type === opt.value;
                  return (
                    <button
                      key={opt.value}
                      type="button"
                      onClick={() => setForm({ ...form, type: opt.value })}
                      className={`flex items-start gap-2.5 rounded-xl border p-3 text-left transition-colors ${
                        active
                          ? 'border-emerald-500 bg-emerald-50/70 text-emerald-950'
                          : 'border-slate-200 hover:bg-slate-50'
                      }`}
                    >
                      <Icon className={`mt-0.5 h-4 w-4 shrink-0 ${active ? 'text-emerald-600' : 'text-slate-400'}`} />
                      <div>
                        <div className="text-sm font-semibold">{opt.label}</div>
                        <div className="text-[11px] text-slate-500">{opt.hint}</div>
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">
                {form.type === 'ewallet' ? 'Nama E-Wallet' : 'Nama Bank'} <span className="text-rose-500">*</span>
              </label>
              <input
                value={form.bank_name}
                onChange={(e) => setForm({ ...form, bank_name: e.target.value })}
                required
                maxLength={100}
                placeholder={form.type === 'ewallet' ? 'mis. DANA, GoPay, OVO' : 'mis. BCA, BRI, Mandiri'}
                className={inputCls}
              />
              <div className="mt-1.5 flex flex-wrap gap-1.5">
                {suggestions.map((name) => (
                  <button
                    key={name}
                    type="button"
                    onClick={() => setForm({ ...form, bank_name: name })}
                    className={`rounded-lg border px-2 py-0.5 text-[11px] font-medium transition-colors ${
                      form.bank_name.trim().toLowerCase() === name.toLowerCase()
                        ? 'border-emerald-500 bg-emerald-50 text-emerald-700'
                        : 'border-slate-200 bg-slate-50 text-slate-600 hover:bg-slate-100'
                    }`}
                  >
                    {name}
                  </button>
                ))}
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">
                  {form.type === 'ewallet' ? 'Nomor HP / E-Wallet' : 'Nomor Rekening'} <span className="text-rose-500">*</span>
                </label>
                <input
                  value={form.account_number}
                  onChange={(e) => setForm({ ...form, account_number: e.target.value })}
                  required
                  maxLength={100}
                  placeholder={form.type === 'ewallet' ? 'mis. 081234567890' : 'mis. 1234567890'}
                  className={`${inputCls} font-mono`}
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">
                  Atas Nama (Pemilik) <span className="text-rose-500">*</span>
                </label>
                <input
                  value={form.account_holder_name}
                  onChange={(e) => setForm({ ...form, account_holder_name: e.target.value })}
                  required
                  maxLength={150}
                  placeholder="mis. PT Inovasi Online"
                  className={inputCls}
                />
              </div>
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">Deskripsi Singkat (opsional)</label>
              <input
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                maxLength={255}
                placeholder="mis. Transfer manual & kirim bukti pembayaran ke admin"
                className={inputCls}
              />
            </div>

            <div>
              <label className="mb-1 block text-xs font-medium text-slate-600">
                Instruksi Pembayaran / Top Up (opsional)
              </label>
              <textarea
                rows={3}
                value={form.instructions}
                onChange={(e) => setForm({ ...form, instructions: e.target.value })}
                maxLength={1000}
                placeholder="mis. Transfer sesuai nominal tagihan, lalu unggah foto/screenshot bukti transfer untuk diverifikasi admin."
                className={inputCls}
              />
            </div>

            <label className="flex items-center gap-2 text-sm text-slate-700">
              <input
                type="checkbox"
                checked={form.is_enabled}
                onChange={(e) => setForm({ ...form, is_enabled: e.target.checked })}
              />
              Aktif (tampilkan saat checkout dan top up manual)
            </label>

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setModal(null)}
                className="rounded-xl border border-slate-200 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
              >
                Batal
              </button>
              <button
                type="submit"
                disabled={saving}
                className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
              >
                {saving && <Loader2 className="h-4 w-4 animate-spin" />}
                Simpan
              </button>
            </div>
          </form>
        </div>
      )}
    </AdminLayout>
  );
}

