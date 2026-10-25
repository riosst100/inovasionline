import { useMemo } from 'react';
import { useLabels } from '../../../lib/labels';

export type OrderTab = { value: string; label: string; badge: string };

// Tab order matches the admin mobile app; labels/colors come from Status Pesanan config.
const STATUS_ORDER = ['pending', 'processing', 'ready', 'on_delivery', 'completed', 'cancelled'];

export function useOrderTabs(): OrderTab[] {
  const { get } = useLabels();
  return useMemo(
    () => [
      { value: 'all', label: 'Semua', badge: 'bg-emerald-100 text-emerald-700' },
      ...STATUS_ORDER.map((k) => ({ value: k, ...get('order_status', k) })),
    ],
    [get],
  );
}

export const PAYMENT_LABELS: Record<string, { label: string; cls: string }> = {
  paid: { label: 'Lunas', cls: 'bg-green-100 text-green-700' },
  unpaid: { label: 'Belum Bayar', cls: 'bg-slate-100 text-slate-600' },
  failed: { label: 'Gagal', cls: 'bg-red-100 text-red-700' },
  refunded: { label: 'Dikembalikan', cls: 'bg-sky-100 text-sky-700' },
};

export const rupiah = (n: number) => 'Rp' + Math.round(Number(n) || 0).toLocaleString('id-ID');
