import { WalletTopupStatus, WalletTransactionRow } from '../types';

export const rupiah = (n: number) => 'Rp' + Math.round(Math.abs(n)).toLocaleString('id-ID');

export const formatDateTime = (iso: string) =>
  new Date(iso).toLocaleString('id-ID', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });

/** Today in WIB as YYYY-MM-DD, matching the backend's date filters. */
export const todayWib = (offsetDays = 0) => {
  const d = new Date(Date.now() + offsetDays * 86400000);
  return d.toLocaleDateString('en-CA', { timeZone: 'Asia/Jakarta' });
};

export const TRANSACTION_TYPE_LABEL: Record<WalletTransactionRow['type'], string> = {
  topup: 'Top Up',
  payment: 'Pembayaran',
  refund: 'Pengembalian Dana',
  adjustment: 'Penyesuaian',
  bonus: 'Bonus',
  ad_chest: 'Peti Hadiah',
};

export const TOPUP_STATUS: Record<WalletTopupStatus, { label: string; badge: string }> = {
  pending: { label: 'Berjalan', badge: 'bg-amber-50 text-amber-700 ring-amber-200' },
  paid: { label: 'Berhasil', badge: 'bg-emerald-50 text-emerald-700 ring-emerald-200' },
  failed: { label: 'Gagal', badge: 'bg-rose-50 text-rose-700 ring-rose-200' },
  expired: { label: 'Kedaluwarsa', badge: 'bg-slate-100 text-slate-600 ring-slate-200' },
};
