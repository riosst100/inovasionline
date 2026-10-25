'use client';

import React from 'react';
import { todayWib } from '../../lib/date';

export type Period = { from: string; to: string };

const PRESETS: { label: string; period: () => Period }[] = [
  { label: 'Hari ini', period: () => ({ from: todayWib(), to: todayWib() }) },
  { label: '7 hari', period: () => ({ from: todayWib(-6), to: todayWib() }) },
  { label: 'Bulan ini', period: () => ({ from: todayWib().slice(0, 8) + '01', to: todayWib() }) },
  { label: '30 hari', period: () => ({ from: todayWib(-29), to: todayWib() }) },
  { label: '1 tahun', period: () => ({ from: todayWib(-364), to: todayWib() }) },
];

/** Default period for Keuangan pages. Reads "today", so call it in a dynamic (Suspense) render. */
export const thisMonth = (): Period => PRESETS[2].period();

/** Date presets + range inputs shared by the Keuangan pages (WIB dates, max 366 days on the backend). */
export default function PeriodFilter({ value, onChange }: { value: Period; onChange: (p: Period) => void }) {
  const input = 'rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-500';

  return (
    <div className="flex flex-wrap items-center gap-2">
      {PRESETS.map((pr) => {
        const p = pr.period();
        const active = value.from === p.from && value.to === p.to;
        return (
          <button
            key={pr.label}
            type="button"
            onClick={() => onChange(p)}
            className={`rounded-full border px-3 py-1 text-xs font-medium ${active ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-600 hover:bg-slate-50'}`}
          >
            {pr.label}
          </button>
        );
      })}
      <input type="date" className={input} value={value.from} max={value.to} onChange={(e) => e.target.value && onChange({ ...value, from: e.target.value })} aria-label="Dari tanggal" />
      <span className="text-sm text-slate-400">s/d</span>
      <input type="date" className={input} value={value.to} min={value.from} onChange={(e) => e.target.value && onChange({ ...value, to: e.target.value })} aria-label="Sampai tanggal" />
    </div>
  );
}
