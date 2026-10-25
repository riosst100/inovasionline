'use client';

import React, { useState } from 'react';
import { formatDateTime } from '../../lib/date';

/** Seen within this window counts as online (the app sends a heartbeat while in the foreground). */
const ONLINE_MS = 5 * 60 * 1000;

function relative(ms: number): string {
  const min = Math.floor(ms / 60000);
  if (min < 60) return `${Math.max(min, 1)} menit lalu`;
  const hours = Math.floor(min / 60);
  if (hours < 24) return `${hours} jam lalu`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days} hari lalu`;
  return '';
}

/** "Online" / "5 menit lalu" / a date, from the customer's last_seen_at (app heartbeat or API use). */
export default function LastSeen({ at }: { at: string | null | undefined }) {
  // Read the clock once per mount; the list reloads often enough for "x menit lalu".
  const [now] = useState(() => Date.now());

  if (!at) return <span className="text-xs text-slate-400">Belum pernah</span>;

  const date = new Date(at);
  const ago = now - date.getTime();
  const full = formatDateTime(date);

  if (ago < ONLINE_MS) {
    return (
      <span title={full} className="inline-flex items-center gap-1.5 text-xs font-semibold text-emerald-700">
        <span className="h-2 w-2 rounded-full bg-emerald-500" /> Online
      </span>
    );
  }

  return (
    <span title={full} className="text-xs text-slate-600">
      {relative(ago) || full}
    </span>
  );
}
