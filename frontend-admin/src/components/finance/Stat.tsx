import React from 'react';
import { rupiah } from '../../lib/wallet';

/** Rupiah with an explicit minus for negative amounts (lib/wallet's rupiah drops the sign). */
export const signedRupiah = (n: number) => (n < 0 ? '−' : '') + rupiah(n);

type Tone = 'in' | 'out' | 'warn';

const TONES: Record<Tone, string> = {
  in: 'text-emerald-700',
  out: 'text-rose-700',
  warn: 'text-amber-700',
};

export default function Stat({ label, value, hint, tone }: { label: string; value: string; hint?: React.ReactNode; tone?: Tone }) {
  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
      <p className="text-xs text-slate-500">{label}</p>
      <p className={`mt-1 text-lg font-bold ${tone ? TONES[tone] : 'text-slate-900'}`}>{value}</p>
      {hint && <div className="mt-0.5 text-xs text-slate-400">{hint}</div>}
    </div>
  );
}
