'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { History } from 'lucide-react';
import { DataTransfer } from '../../types';
import { isActiveTransfer } from '../../lib/dataTransfer';
import { useNow } from '../../lib/date';
import DataTransferItem from './DataTransferItem';

type Props = {
  /** Usually `items` from useDataTransfers({ resource }) */
  items: DataTransfer[];
  resource: string;
  /** Finished transfers younger than this stay visible (default 30 min) */
  recentMinutes?: number;
  max?: number;
};

/** Compact progress list for a resource page: running jobs plus recently finished ones. */
export default function DataTransferProgress({ items, resource, recentMinutes = 30, max = 3 }: Props) {
  const [dismissed, setDismissed] = useState<Set<string>>(new Set());
  const now = useNow(60_000);

  const visible = items
    .filter(
      (t) =>
        !dismissed.has(t.id) &&
        (isActiveTransfer(t) || (now > 0 && now - new Date(t.finished_at ?? t.created_at).getTime() < recentMinutes * 60_000))
    )
    .slice(0, max);

  if (visible.length === 0) return null;

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <h3 className="text-xs font-bold uppercase tracking-wide text-slate-500">Proses Import / Export</h3>
        <Link
          href={`/dashboard/data-transfers?resource=${resource}`}
          className="inline-flex items-center gap-1 text-xs font-semibold text-emerald-700 hover:underline"
        >
          <History className="h-3.5 w-3.5" /> Lihat riwayat
        </Link>
      </div>
      {visible.map((t) => (
        <DataTransferItem
          key={t.id}
          transfer={t}
          onDismiss={(x) => setDismissed((prev) => new Set(prev).add(x.id))}
        />
      ))}
    </div>
  );
}
