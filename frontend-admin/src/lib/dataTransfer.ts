'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { apiDownload, apiRequest, apiRequestFull } from './api';
import { DataTransfer, DataTransferFormat, DataTransferStatus, DataTransferType, PaginationMeta } from '../types';

/**
 * Generic queued CSV/XLSX import & export. A resource key (e.g. "categories")
 * must be registered in the backend's DataTransferRegistry.
 */

export const RESOURCE_LABELS: Record<string, string> = {
  categories: 'Kategori',
  products: 'Produk',
  warehouses: 'Gudang',
  'product-stocks': 'Stok Produk',
  suppliers: 'Supplier',
  brands: 'Brand',
  attributes: 'Atribut Produk',
  drivers: 'Kurir',
};

export const STATUS_META: Record<DataTransferStatus, { label: string; badge: string; bar: string }> = {
  pending: { label: 'Menunggu', badge: 'bg-slate-100 text-slate-600', bar: 'bg-slate-400' },
  processing: { label: 'Diproses', badge: 'bg-sky-100 text-sky-700', bar: 'bg-sky-500' },
  completed: { label: 'Selesai', badge: 'bg-emerald-100 text-emerald-700', bar: 'bg-emerald-500' },
  failed: { label: 'Gagal', badge: 'bg-rose-100 text-rose-700', bar: 'bg-rose-500' },
};

export const isActiveTransfer = (t: Pick<DataTransfer, 'status'>) =>
  t.status === 'pending' || t.status === 'processing';

export type DataTransferQuery = {
  resource?: string;
  type?: DataTransferType | '';
  status?: DataTransferStatus | 'active' | '';
  page?: number;
  perPage?: number;
};

export const dataTransferApi = {
  async list(q: DataTransferQuery = {}): Promise<{ items: DataTransfer[]; meta?: PaginationMeta }> {
    const query = new URLSearchParams();
    if (q.resource) query.set('resource', q.resource);
    if (q.type) query.set('type', q.type);
    if (q.status) query.set('status', q.status);
    query.set('page', String(q.page ?? 1));
    query.set('per_page', String(q.perPage ?? 20));
    const res = await apiRequestFull<DataTransfer[]>(`/admin/data-transfers?${query}`);
    return { items: res.data ?? [], meta: res.meta };
  },

  async get(id: string): Promise<DataTransfer> {
    return apiRequest<DataTransfer>(`/admin/data-transfers/${id}`);
  },

  async startExport(resource: string, format: DataTransferFormat, filters: Record<string, unknown> = {}): Promise<DataTransfer> {
    return apiRequest<DataTransfer>('/admin/data-transfers/export', {
      method: 'POST',
      body: JSON.stringify({ resource, format, filters }),
    });
  },

  async startImport(resource: string, file: File): Promise<DataTransfer> {
    const body = new FormData();
    body.append('resource', resource);
    body.append('file', file);
    // Uploads can take longer than the default 15s timeout.
    return apiRequest<DataTransfer>('/admin/data-transfers/import', { method: 'POST', body }, 120000);
  },

  async remove(id: string): Promise<void> {
    await apiRequest<void>(`/admin/data-transfers/${id}`, { method: 'DELETE' });
  },

  download(t: DataTransfer): Promise<void> {
    return apiDownload(`/admin/data-transfers/${t.id}/download`, t.file_name || `${t.resource}.${t.format}`);
  },

  downloadTemplate(resource: string, format: DataTransferFormat): Promise<void> {
    return apiDownload(
      `/admin/data-transfers/template?resource=${encodeURIComponent(resource)}&format=${format}`,
      `template-${resource}.${format}`
    );
  },
};

const POLL_MS = 2000;

/**
 * Loads data transfers and keeps polling while any of them is still running.
 * `onFinished` fires once for each transfer that moves from running to done
 * (e.g. reload the category list after an import completes).
 */
export function useDataTransfers(query: DataTransferQuery, onFinished?: (t: DataTransfer) => void) {
  const [items, setItems] = useState<DataTransfer[]>([]);
  const [meta, setMeta] = useState<PaginationMeta | undefined>();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const activeIds = useRef<Set<string>>(new Set());
  const onFinishedRef = useRef(onFinished);
  useEffect(() => {
    onFinishedRef.current = onFinished;
  }, [onFinished]);

  const { resource, type, status, page, perPage } = query;

  const refresh = useCallback(async () => {
    try {
      const res = await dataTransferApi.list({ resource, type, status, page, perPage });
      setItems(res.items);
      setMeta(res.meta);
      setError('');

      res.items.forEach((t) => {
        if (activeIds.current.has(t.id) && !isActiveTransfer(t)) onFinishedRef.current?.(t);
      });
      activeIds.current = new Set(res.items.filter(isActiveTransfer).map((t) => t.id));
    } catch (err: any) {
      setError(err?.message || 'Gagal memuat riwayat import/export.');
    } finally {
      setLoading(false);
    }
  }, [resource, type, status, page, perPage]);

  // Filter changes keep the previous list on screen until the new one arrives.
  useEffect(() => {
    const timer = setTimeout(refresh, 0);
    return () => clearTimeout(timer);
  }, [refresh]);

  const hasActive = items.some(isActiveTransfer);
  useEffect(() => {
    if (!hasActive) return;
    const timer = setInterval(refresh, POLL_MS);
    return () => clearInterval(timer);
  }, [hasActive, refresh]);

  /** Show a just-started transfer immediately and start polling it. */
  const track = useCallback((t: DataTransfer) => {
    activeIds.current.add(t.id);
    setItems((prev) => [t, ...prev.filter((x) => x.id !== t.id)]);
  }, []);

  return { items, meta, loading, error, refresh, track };
}
