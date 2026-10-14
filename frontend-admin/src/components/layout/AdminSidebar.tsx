'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useAuth } from '../../context/AuthContext';
import {
  LayoutDashboard,
  ShieldCheck,
  UserCog,
  Users2,
  Image as ImageIcon,
  LayoutTemplate,
  FolderTree,
  ShoppingBag,
  LogOut,
  Truck,
  Boxes,
  Package,
  Warehouse,
  SlidersHorizontal,
  ChevronDown,
  MonitorSmartphone,
  Search,
  TextSearch,
  X,
} from 'lucide-react';

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
}

type NavItem = {
  name: string;
  href: string;
  icon: React.ElementType;
  badge?: string;
  children?: { name: string; href: string; icon: React.ElementType }[];
};

type NavSection = { title: string; items: NavItem[] };

export default function AdminSidebar({ isOpen, onClose }: SidebarProps) {
  const pathname = usePathname();
  const { user, isSuperAdmin, logout } = useAuth();
  const [openGroups, setOpenGroups] = useState<Record<string, boolean>>({});

  const sections: NavSection[] = [
    {
      title: 'Utama',
      items: [{ name: 'Ringkasan Dashboard', href: '/dashboard', icon: LayoutDashboard }],
    },
    {
      title: 'Operasional',
      items: [
        { name: 'Pesanan', href: '/dashboard/orders', icon: ShoppingBag },
        { name: 'Kurir', href: '/dashboard/drivers', icon: Truck },
        { name: 'Gudang / Hub', href: '/dashboard/warehouses', icon: Warehouse },
        {
          name: 'Katalog',
          href: '/dashboard/catalog',
          icon: Boxes,
          children: [
            { name: 'Produk', href: '/dashboard/products', icon: Package },
            { name: 'Kategori', href: '/dashboard/categories', icon: FolderTree },
            { name: 'Atribut Produk', href: '/dashboard/attributes', icon: SlidersHorizontal },
          ],
        },
        {
          name: 'Pencarian',
          href: '/dashboard/search',
          icon: Search,
          children: [
            { name: 'Saran Pencarian', href: '/dashboard/search/suggestions', icon: TextSearch },
          ],
        },
        {
          name: 'Tampilan',
          href: '/dashboard/display',
          icon: LayoutTemplate,
          children: [{ name: 'Banner', href: '/dashboard/banners', icon: ImageIcon }],
        },
      ],
    },
    {
      title: 'Pengguna',
      items: [
        { name: 'Customer', href: '/dashboard/customers', icon: Users2 },
        { name: 'User', href: '/dashboard/users', icon: UserCog, badge: 'Internal' },
        {
          name: 'Hak Akses & Role',
          href: '/dashboard/roles',
          icon: ShieldCheck,
          badge: isSuperAdmin ? 'Super' : undefined,
        },
      ],
    },
    {
      title: 'Keamanan',
      items: [{ name: 'Sesi & Perangkat', href: '/dashboard/sessions', icon: MonitorSmartphone }],
    },
  ];

  const roleName = user?.role?.name || (isSuperAdmin ? 'Super Admin' : 'Staff');

  return (
    <>
      {/* Mobile backdrop */}
      {isOpen && (
        <div
          onClick={onClose}
          className="animate-fade-in fixed inset-0 z-40 bg-slate-950/60 backdrop-blur-sm lg:hidden"
        />
      )}

      <aside
        className={`fixed top-0 bottom-0 left-0 z-50 flex w-72 flex-col border-r border-white/5 bg-slate-950 text-slate-100 transition-transform duration-300 ease-out lg:translate-x-0 ${
          isOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div className="pointer-events-none absolute inset-x-0 top-0 h-48 bg-gradient-to-b from-emerald-500/10 to-transparent" />

        {/* Brand */}
        <div className="relative flex h-16 shrink-0 items-center justify-between px-5">
          <Link href="/dashboard" onClick={onClose} className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-500 to-teal-400 text-sm font-extrabold text-white shadow-lg shadow-emerald-500/25">
              IO
            </div>
            <div className="flex flex-col leading-tight">
              <span className="text-[15px] font-bold tracking-tight text-white">Inovasi Online</span>
              <span className="text-[11px] font-medium text-emerald-400">Admin Portal</span>
            </div>
          </Link>
          <button
            onClick={onClose}
            aria-label="Tutup menu"
            className="rounded-lg p-1.5 text-slate-400 transition-colors hover:bg-white/10 hover:text-white lg:hidden"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Navigation */}
        <div className="relative flex-1 overflow-y-auto px-3 pb-4 pt-2">
          {sections.map((section) => (
            <div key={section.title} className="mb-5">
              <div className="mb-1.5 px-3 text-[10.5px] font-semibold uppercase tracking-[0.12em] text-slate-500">
                {section.title}
              </div>
              <nav className="space-y-0.5">
                {section.items.map((item) => {
                  const Icon = item.icon;

                  if (item.children) {
                    const childActive = item.children.some((c) => pathname === c.href);
                    const open = openGroups[item.name] ?? childActive;

                    return (
                      <div key={item.href}>
                        <button
                          type="button"
                          onClick={() => setOpenGroups({ ...openGroups, [item.name]: !open })}
                          aria-expanded={open}
                          className={`group flex w-full items-center justify-between rounded-lg px-3 py-2 text-[13.5px] font-medium transition-colors ${
                            childActive
                              ? 'text-white'
                              : 'text-slate-400 hover:bg-white/5 hover:text-white'
                          }`}
                        >
                          <div className="flex items-center gap-3">
                            <Icon
                              className={`h-[18px] w-[18px] ${childActive ? 'text-emerald-400' : 'text-slate-500 group-hover:text-emerald-400'}`}
                            />
                            <span>{item.name}</span>
                          </div>
                          <ChevronDown
                            className={`h-4 w-4 text-slate-500 transition-transform duration-200 ${open ? 'rotate-180' : ''}`}
                          />
                        </button>
                        {open && (
                          <div className="animate-fade-in ml-[21px] mt-0.5 space-y-0.5 border-l border-white/10 pl-3">
                            {item.children.map((child) => {
                              const active = pathname === child.href;
                              const ChildIcon = child.icon;
                              return (
                                <Link
                                  key={child.href}
                                  href={child.href}
                                  onClick={onClose}
                                  className={`flex items-center gap-2.5 rounded-lg px-3 py-1.5 text-[13px] transition-colors ${
                                    active
                                      ? 'bg-emerald-500/15 font-semibold text-emerald-300'
                                      : 'text-slate-400 hover:bg-white/5 hover:text-white'
                                  }`}
                                >
                                  <ChildIcon className="h-4 w-4" />
                                  {child.name}
                                </Link>
                              );
                            })}
                          </div>
                        )}
                      </div>
                    );
                  }

                  const isActive =
                    item.href === '/dashboard' ? pathname === item.href : pathname.startsWith(item.href);

                  return (
                    <Link
                      key={item.href}
                      href={item.href}
                      onClick={onClose}
                      aria-current={isActive ? 'page' : undefined}
                      className={`group relative flex items-center justify-between rounded-lg px-3 py-2 text-[13.5px] font-medium transition-colors ${
                        isActive
                          ? 'bg-emerald-500/15 text-white'
                          : 'text-slate-400 hover:bg-white/5 hover:text-white'
                      }`}
                    >
                      {isActive && (
                        <span className="absolute -left-3 top-1/2 h-5 w-1 -translate-y-1/2 rounded-r-full bg-emerald-400" />
                      )}
                      <div className="flex items-center gap-3">
                        <Icon
                          className={`h-[18px] w-[18px] transition-colors ${
                            isActive ? 'text-emerald-400' : 'text-slate-500 group-hover:text-emerald-400'
                          }`}
                        />
                        <span>{item.name}</span>
                      </div>
                      {item.badge && (
                        <span className="rounded-md border border-emerald-500/25 bg-emerald-500/10 px-1.5 py-0.5 text-[10px] font-semibold text-emerald-300">
                          {item.badge}
                        </span>
                      )}
                    </Link>
                  );
                })}
              </nav>
            </div>
          ))}
        </div>

        {/* User */}
        <div className="relative shrink-0 border-t border-white/5 p-3">
          <div className="flex items-center justify-between gap-3 rounded-xl bg-white/5 p-2.5">
            <div className="flex min-w-0 items-center gap-2.5">
              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-emerald-500 to-teal-500 text-xs font-bold text-white">
                {user?.name?.slice(0, 2).toUpperCase() || 'SA'}
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate text-xs font-semibold text-white">{user?.name || 'Super Admin'}</p>
                <div className="mt-0.5 flex items-center gap-1.5">
                  <span className="inline-block h-1.5 w-1.5 rounded-full bg-emerald-400" />
                  <span className="truncate text-[11px] text-slate-400">{roleName}</span>
                </div>
              </div>
            </div>
            <button
              onClick={() => logout()}
              title="Keluar dari akun admin"
              aria-label="Keluar"
              className="rounded-lg p-2 text-slate-400 transition-colors hover:bg-rose-500/15 hover:text-rose-400"
            >
              <LogOut className="h-4 w-4" />
            </button>
          </div>
        </div>
      </aside>
    </>
  );
}
