'use client';

import React, { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useAuth } from '../../context/AuthContext';
import { Menu, LogOut, ChevronRight, ChevronDown, Home, ShieldCheck, MonitorSmartphone } from 'lucide-react';

interface HeaderProps {
  onMenuToggle: () => void;
}

const LABELS: Record<string, string> = {
  dashboard: 'Dashboard',
  drivers: 'Kurir',
  roles: 'Hak Akses & Role',
  users: 'User Admin & Staff',
  customers: 'Pelanggan',
  banners: 'Banner & Promo',
  products: 'Produk',
  categories: 'Kategori',
  search: 'Pencarian',
  suggestions: 'Saran Pencarian',
  orders: 'Pesanan',
  sessions: 'Sesi & Perangkat',
};

export default function AdminHeader({ onMenuToggle }: HeaderProps) {
  const { user, isSuperAdmin, logout } = useAuth();
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const roleName = user?.role?.name || (isSuperAdmin ? 'Super Admin' : 'Staff');

  const segments = pathname.split('/').filter(Boolean);
  const crumbs = segments.map((seg, i) => ({
    label: LABELS[seg] ?? seg.charAt(0).toUpperCase() + seg.slice(1),
    href: '/' + segments.slice(0, i + 1).join('/'),
  }));

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) setMenuOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, []);

  return (
    <header className="sticky top-0 z-30 flex h-16 w-full items-center justify-between border-b border-slate-200/70 bg-white/75 px-4 backdrop-blur-xl sm:px-6 lg:px-8">
      <div className="flex min-w-0 items-center gap-3">
        <button
          onClick={onMenuToggle}
          aria-label="Buka menu"
          className="rounded-xl p-2 text-slate-600 transition-colors hover:bg-slate-100 lg:hidden"
        >
          <Menu className="h-5 w-5" />
        </button>

        <nav aria-label="Breadcrumb" className="flex min-w-0 items-center gap-1.5 text-sm">
          <Home className="hidden h-4 w-4 shrink-0 text-slate-400 sm:block" />
          {crumbs.map((c, i) => {
            const last = i === crumbs.length - 1;
            return (
              <React.Fragment key={c.href}>
                {i > 0 && <ChevronRight className="hidden h-3.5 w-3.5 shrink-0 text-slate-300 sm:block" />}
                {last ? (
                  <span className="truncate font-semibold text-slate-900">{c.label}</span>
                ) : (
                  <Link
                    href={c.href}
                    className="hidden truncate text-slate-500 transition-colors hover:text-slate-900 sm:inline"
                  >
                    {c.label}
                  </Link>
                )}
              </React.Fragment>
            );
          })}
        </nav>
      </div>

      <div ref={menuRef} className="relative">
        <button
          onClick={() => setMenuOpen((v) => !v)}
          aria-haspopup="menu"
          aria-expanded={menuOpen}
          className="flex items-center gap-2.5 rounded-full border border-transparent py-1 pl-1 pr-2.5 transition-colors hover:border-slate-200 hover:bg-white"
        >
          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-gradient-to-br from-emerald-600 to-teal-500 text-xs font-bold text-white shadow-sm">
            {user?.name?.slice(0, 2).toUpperCase() || 'SA'}
          </div>
          <div className="hidden text-left md:block">
            <div className="text-xs font-semibold leading-tight text-slate-800">
              {user?.name || 'Super Admin'}
            </div>
            <div className="text-[11px] leading-tight text-slate-400">{roleName}</div>
          </div>
          <ChevronDown
            className={`hidden h-4 w-4 text-slate-400 transition-transform md:block ${menuOpen ? 'rotate-180' : ''}`}
          />
        </button>

        {menuOpen && (
          <div
            role="menu"
            className="animate-fade-in absolute right-0 mt-2 w-64 overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xl shadow-slate-900/10"
          >
            <div className="border-b border-slate-100 bg-slate-50/70 p-4">
              <p className="truncate text-sm font-semibold text-slate-900">{user?.name || 'Super Admin'}</p>
              <p className="truncate text-xs text-slate-500">{user?.email || 'admin@inovasionline.com'}</p>
              <span className="mt-2.5 inline-flex items-center gap-1.5 rounded-full border border-emerald-200 bg-emerald-50 px-2.5 py-0.5 text-[11px] font-semibold text-emerald-700">
                <ShieldCheck className="h-3 w-3" />
                {roleName}
              </span>
            </div>
            <div className="p-1.5">
              <Link
                href="/dashboard/sessions"
                role="menuitem"
                onClick={() => setMenuOpen(false)}
                className="flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-sm text-slate-700 transition-colors hover:bg-slate-100"
              >
                <MonitorSmartphone className="h-4 w-4 text-slate-400" />
                Sesi & Perangkat
              </Link>
              <button
                role="menuitem"
                onClick={() => logout()}
                className="flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-sm font-medium text-rose-600 transition-colors hover:bg-rose-50"
              >
                <LogOut className="h-4 w-4" />
                Keluar
              </button>
            </div>
          </div>
        )}
      </div>
    </header>
  );
}
