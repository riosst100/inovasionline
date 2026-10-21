'use client';

import { useCallback, useEffect, useState } from 'react';
import { apiRequest } from './api';

export type LabelItem = { group: string; key: string; label: string; color: string };

// Full class strings so Tailwind can see them.
export const LABEL_COLORS: Record<string, { name: string; badge: string }> = {
  slate: { name: 'Abu-abu', badge: 'bg-slate-100 text-slate-700' },
  emerald: { name: 'Hijau Zamrud', badge: 'bg-emerald-100 text-emerald-700' },
  green: { name: 'Hijau', badge: 'bg-green-100 text-green-700' },
  amber: { name: 'Kuning', badge: 'bg-amber-100 text-amber-700' },
  orange: { name: 'Oranye', badge: 'bg-orange-100 text-orange-700' },
  red: { name: 'Merah', badge: 'bg-red-100 text-red-700' },
  rose: { name: 'Merah Muda', badge: 'bg-rose-100 text-rose-700' },
  violet: { name: 'Ungu', badge: 'bg-violet-100 text-violet-700' },
  sky: { name: 'Biru Muda', badge: 'bg-sky-100 text-sky-700' },
  blue: { name: 'Biru', badge: 'bg-blue-100 text-blue-700' },
};

export const badgeClass = (color?: string) => (LABEL_COLORS[color ?? ''] ?? LABEL_COLORS.slate).badge;

// Single source of truth for every label shown in the admin web.
let cache: LabelItem[] | null = null;
let inflight: Promise<LabelItem[]> | null = null;
const listeners = new Set<(items: LabelItem[]) => void>();

export function setLabelCache(items: LabelItem[]): LabelItem[] {
  cache = items;
  listeners.forEach((l) => l(items));
  return items;
}

function load(): Promise<LabelItem[]> {
  if (cache) return Promise.resolve(cache);
  if (!inflight) {
    inflight = apiRequest<LabelItem[]>('/admin/label-configs')
      .then(setLabelCache)
      .finally(() => {
        inflight = null;
      });
  }
  return inflight;
}

export function useLabels() {
  const [items, setItems] = useState<LabelItem[]>(cache ?? []);
  const [ready, setReady] = useState(cache !== null);

  useEffect(() => {
    const l = (i: LabelItem[]) => setItems(i);
    listeners.add(l);
    load()
      .then((i) => {
        setItems(i);
        setReady(true);
      })
      .catch(() => setReady(true));
    return () => {
      listeners.delete(l);
    };
  }, []);

  const group = useCallback((g: string) => items.filter((i) => i.group === g), [items]);

  /** Label + badge classes for a key; falls back to the raw key. */
  const get = useCallback(
    (g: string, key?: string | null) => {
      const found = items.find((i) => i.group === g && i.key === key);
      return { label: found?.label ?? key ?? '-', badge: badgeClass(found?.color) };
    },
    [items],
  );

  return { items, ready, group, get };
}
