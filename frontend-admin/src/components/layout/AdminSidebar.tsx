'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useAuth } from '../../context/AuthContext';
import {
  LayoutDashboard,
  ShieldCheck,
  UserCog,
  Users2,
  Image as ImageIcon,
  FolderTree,
  ShoppingBag,
  Sparkles,
  LogOut,
  Truck,
} from 'lucide-react';

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function AdminSidebar({ isOpen, onClose }: SidebarProps) {
  const pathname = usePathname();
  const { user, isSuperAdmin, logout } = useAuth();

  const navigation = [
    {
      name: 'Ringkasan Dashboard',
      href: '/dashboard',
      icon: LayoutDashboard,
    },
    {
      name: 'Kurir',
      href: '/dashboard/drivers',
      icon: Truck,
    },
    {
      name: 'Hak Akses & Role',
      href: '/dashboard/roles',
      icon: ShieldCheck,
      badge: isSuperAdmin ? 'Super Admin' : undefined,
    },
    {
      name: 'User Admin & Staff',
      href: '/dashboard/users',
      icon: UserCog,
      badge: 'Internal',
    },
    {
      name: 'Data Pelanggan (Customer)',
      href: '/dashboard/customers',
      icon: Users2,
    },
    {
      name: 'Banner & Slider Promo',
      href: '/dashboard/banners',
      icon: ImageIcon,
    },
    {
      name: 'Katalog Kategori',
      href: '/dashboard/categories',
      icon: FolderTree,
    },
    {
      name: 'Pesanan Marketplace',
      href: '/dashboard/orders',
      icon: ShoppingBag,
    },
  ];

  const roleName = user?.role?.name || (isSuperAdmin ? 'Super Admin' : 'Staff');

  return (
    <>
      {/* Mobile backdrop */}
      {isOpen && (
        <div
          onClick={onClose}
          className="fixed inset-0 z-40 bg-black/50 backdrop-blur-xs lg:hidden"
        />
      )}

      <aside
        className={`fixed top-0 bottom-0 left-0 z-50 flex w-72 flex-col bg-slate-900 text-slate-100 transition-transform duration-300 ease-in-out lg:translate-x-0 ${
          isOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        {/* Brand Header */}
        <div className="flex h-18 items-center gap-3 border-b border-slate-800 px-6">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-tr from-emerald-600 to-teal-400 font-bold text-white shadow-md shadow-emerald-500/20">
            IO
          </div>
          <div className="flex flex-col">
            <span className="text-base font-bold tracking-tight text-white">
              Inovasi Online
            </span>
            <span className="text-xs font-medium text-emerald-400 flex items-center gap-1">
              <Sparkles className="h-3 w-3" /> Admin Portal
            </span>
          </div>
        </div>

        {/* Navigation list */}
        <div className="flex-1 overflow-y-auto px-4 py-5">
          <div className="mb-2 px-3 text-[11px] font-semibold uppercase tracking-wider text-slate-400">
            Pusat Kendali Admin
          </div>
          <nav className="space-y-1.5">
            {navigation.map((item) => {
              const isActive = pathname === item.href;
              const Icon = item.icon;

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={onClose}
                  className={`group flex items-center justify-between rounded-xl px-3.5 py-2.5 text-sm font-medium transition-all duration-150 ${
                    isActive
                      ? 'bg-emerald-600 text-white shadow-md shadow-emerald-600/30 font-semibold'
                      : 'text-slate-300 hover:bg-slate-800/80 hover:text-white'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <Icon
                      className={`h-4.5 w-4.5 transition-colors ${
                        isActive ? 'text-white' : 'text-slate-400 group-hover:text-emerald-400'
                      }`}
                    />
                    <span>{item.name}</span>
                  </div>
                  {item.badge && (
                    <span className="rounded-md bg-emerald-500/20 px-2 py-0.5 text-[10px] font-semibold text-emerald-300 border border-emerald-500/30">
                      {item.badge}
                    </span>
                  )}
                </Link>
              );
            })}
          </nav>
        </div>

        {/* Bottom User Profile Section */}
        <div className="border-t border-slate-800 bg-slate-950/60 p-4">
          <div className="flex items-center justify-between gap-3 rounded-xl bg-slate-800/60 p-3 border border-slate-800">
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-emerald-600 text-xs font-bold text-white shadow-sm">
                {user?.name?.slice(0, 2).toUpperCase() || 'SA'}
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate text-xs font-semibold text-white">
                  {user?.name || 'Super Admin'}
                </p>
                <div className="mt-0.5 flex items-center gap-1">
                  <span className="inline-block h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse" />
                  <span className="truncate text-[10.5px] font-medium text-emerald-300">
                    {roleName}
                  </span>
                </div>
              </div>
            </div>
            <button
              onClick={() => logout()}
              title="Keluar dari akun admin"
              className="rounded-lg p-1.5 text-slate-400 hover:bg-rose-500/20 hover:text-rose-400 transition-colors"
            >
              <LogOut className="h-4 w-4" />
            </button>
          </div>
        </div>
      </aside>
    </>
  );
}
