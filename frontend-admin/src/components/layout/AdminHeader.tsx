'use client';

import React from 'react';
import { useAuth } from '../../context/AuthContext';
import { Menu, ShieldAlert, LogOut } from 'lucide-react';

interface HeaderProps {
  onMenuToggle: () => void;
}

export default function AdminHeader({ onMenuToggle }: HeaderProps) {
  const { user, isSuperAdmin, logout } = useAuth();
  const roleName = user?.role?.name || (isSuperAdmin ? 'Super Admin' : 'Staff');

  return (
    <header className="sticky top-0 z-30 flex h-18 w-full items-center justify-between border-b border-slate-200 bg-white/80 px-6 backdrop-blur-md">
      {/* Mobile Toggle & Title */}
      <div className="flex items-center gap-3">
        <button
          onClick={onMenuToggle}
          className="rounded-xl p-2 text-slate-600 hover:bg-slate-100 lg:hidden"
        >
          <Menu className="h-5 w-5" />
        </button>
        <div>
          <h1 className="text-base font-bold text-slate-900 hidden sm:block">
            Portal Admin Inovasi Online
          </h1>
          <p className="text-xs text-slate-500 hidden sm:block">
            Manajemen Internal: Super Admin, Driver, Sales, dan Operasional Marketplace
          </p>
        </div>
      </div>

      {/* Right User Bar */}
      <div className="flex items-center gap-3">
        {/* Role Badge */}
        <div className="flex items-center gap-2 rounded-full bg-emerald-50 px-3 py-1 border border-emerald-200 text-xs font-semibold text-emerald-800">
          <ShieldAlert className="h-3.5 w-3.5 text-emerald-600" />
          <span>Role: {roleName}</span>
        </div>

        {/* User Card */}
        <div className="flex items-center gap-2.5 pl-2">
          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-slate-900 text-xs font-bold text-white shadow-xs">
            {user?.name?.slice(0, 2).toUpperCase() || 'SA'}
          </div>
          <div className="hidden md:block text-left">
            <div className="text-xs font-semibold text-slate-800 leading-tight">
              {user?.name || 'Super Admin'}
            </div>
            <div className="text-[11px] text-slate-400 leading-tight">
              {user?.email || 'admin@inovasionline.com'}
            </div>
          </div>
        </div>

        <button
          onClick={() => logout()}
          className="flex items-center gap-1.5 rounded-xl border border-rose-200 bg-rose-50 px-3 py-1.5 text-xs font-semibold text-rose-700 hover:bg-rose-100 transition-colors shadow-2xs"
          title="Keluar"
        >
          <LogOut className="h-3.5 w-3.5" />
          <span className="hidden sm:inline">Logout</span>
        </button>
      </div>
    </header>
  );
}
