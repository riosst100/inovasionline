'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Check, ChevronDown, Search } from 'lucide-react';

interface Option {
  value: string;
  label: string;
}

interface Props {
  value: string;
  onChange: (value: string) => void;
  options: Option[];
  placeholder?: string;
  emptyLabel?: string;
}

export default function SearchableSelect({
  value,
  onChange,
  options,
  placeholder = 'Pilih...',
  emptyLabel,
}: Props) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (!ref.current?.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return q ? options.filter((o) => o.label.toLowerCase().includes(q)) : options;
  }, [options, query]);

  const selected = options.find((o) => o.value === value);

  const pick = (v: string) => {
    onChange(v);
    setOpen(false);
    setQuery('');
  };

  const itemCls = (active: boolean) =>
    `flex w-full items-center justify-between px-3 py-2 text-left text-sm hover:bg-emerald-50 ${
      active ? 'bg-emerald-50 font-semibold text-emerald-700' : 'text-slate-700'
    }`;

  return (
    <div ref={ref} className="relative mt-1">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="flex w-full items-center justify-between rounded-xl border border-slate-200 bg-white px-3 py-2 text-left text-sm focus:border-emerald-500 focus:outline-none"
      >
        <span className={selected ? 'text-slate-800' : 'text-slate-400'}>
          {selected?.label ?? emptyLabel ?? placeholder}
        </span>
        <ChevronDown className={`h-4 w-4 text-slate-400 transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>

      {open && (
        <div className="absolute z-30 mt-1 w-full overflow-hidden rounded-xl border border-slate-200 bg-white shadow-lg">
          <div className="flex items-center gap-2 border-b border-slate-100 px-3 py-2">
            <Search className="h-4 w-4 text-slate-400" />
            <input
              autoFocus
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Cari..."
              className="w-full bg-transparent text-sm outline-none"
            />
          </div>
          <div className="max-h-56 overflow-y-auto py-1">
            {emptyLabel && !query && (
              <button type="button" onClick={() => pick('')} className={itemCls(value === '')}>
                <span>{emptyLabel}</span>
                {value === '' && <Check className="h-4 w-4" />}
              </button>
            )}
            {filtered.map((o) => (
              <button key={o.value} type="button" onClick={() => pick(o.value)} className={itemCls(o.value === value)}>
                <span>{o.label}</span>
                {o.value === value && <Check className="h-4 w-4" />}
              </button>
            ))}
            {filtered.length === 0 && (
              <p className="px-3 py-3 text-center text-xs text-slate-400">Tidak ditemukan.</p>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
