'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import AdminLayout from '../../components/layout/AdminLayout';
import { useAuth } from '../../context/AuthContext';
import { adminApi } from '../../lib/api';
import { Role, AdminUser } from '../../types';
import {
  ShieldCheck,
  Plus,
  ArrowRight,
  Truck,
  UserCog,
  Users2,
  Package,
  ShoppingBag,
  Image as ImageIcon,
} from 'lucide-react';

function greeting() {
  const h = new Date().getHours();
  if (h < 11) return 'Selamat pagi';
  if (h < 15) return 'Selamat siang';
  if (h < 19) return 'Selamat sore';
  return 'Selamat malam';
}

const AVATAR_COLORS = [
  'from-emerald-500 to-teal-500',
  'from-blue-500 to-indigo-500',
  'from-amber-500 to-orange-500',
  'from-purple-500 to-fuchsia-500',
  'from-rose-500 to-pink-500',
];

export default function DashboardOverviewPage() {
  const { user } = useAuth();
  const [roles, setRoles] = useState<Role[]>([]);
  const [staffUsers, setStaffUsers] = useState<AdminUser[]>([]);
  const [totalCustomers, setTotalCustomers] = useState(0);
  const [loading, setLoading] = useState(true);
  const [today, setToday] = useState('');
  const [salam, setSalam] = useState('Halo');

  useEffect(() => {
    setSalam(greeting());
    setToday(
      new Date().toLocaleDateString('id-ID', {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric',
      })
    );
  }, []);

  useEffect(() => {
    async function loadData() {
      try {
        const [rolesData, staffData, customersData] = await Promise.all([
          adminApi.getRoles().catch(() => []),
          adminApi.getStaffUsers().catch(() => ({ data: [] })),
          adminApi.getCustomers().catch(() => ({ total: 0 })),
        ]);
        setRoles(rolesData);
        setStaffUsers(staffData.data || []);
        setTotalCustomers(customersData.total || 0);
      } finally {
        setLoading(false);
      }
    }
    loadData();
  }, []);

  const stats = [
    {
      label: 'Role Terdaftar',
      value: roles.length,
      hint: 'Driver, Sales, Admin & lainnya',
      icon: ShieldCheck,
      tone: 'bg-emerald-50 text-emerald-600 ring-emerald-100',
      href: '/dashboard/roles',
    },
    {
      label: 'Admin & Staff',
      value: staffUsers.length,
      hint: 'Akun internal admin',
      icon: UserCog,
      tone: 'bg-blue-50 text-blue-600 ring-blue-100',
      href: '/dashboard/users',
    },
    {
      label: 'Pelanggan',
      value: totalCustomers,
      hint: 'Pengguna aplikasi marketplace',
      icon: Users2,
      tone: 'bg-amber-50 text-amber-600 ring-amber-100',
      href: '/dashboard/customers',
    },
    {
      label: 'Kurir',
      value: roles.find((r) => r.slug === 'driver')?.users_count ?? 0,
      hint: 'Petugas pengantaran pesanan',
      icon: Truck,
      tone: 'bg-purple-50 text-purple-600 ring-purple-100',
      href: '/dashboard/drivers',
    },
  ];

  const shortcuts = [
    { name: 'Produk', href: '/dashboard/products', icon: Package },
    { name: 'Pesanan', href: '/dashboard/orders', icon: ShoppingBag },
    { name: 'Banner', href: '/dashboard/banners', icon: ImageIcon },
    { name: 'Kurir', href: '/dashboard/drivers', icon: Truck },
  ];

  return (
    <AdminLayout>
      <div className="space-y-6">
        {/* Hero */}
        <section className="relative overflow-hidden rounded-3xl bg-slate-950 p-6 text-white shadow-xl shadow-slate-900/10 md:p-8">
          <div className="bg-dots absolute inset-0" />
          <div className="pointer-events-none absolute -right-20 -top-24 h-72 w-72 rounded-full bg-emerald-500/30 blur-3xl" />
          <div className="pointer-events-none absolute -bottom-32 left-1/3 h-64 w-64 rounded-full bg-teal-500/20 blur-3xl" />

          <div className="relative flex flex-col gap-6 md:flex-row md:items-end md:justify-between">
            <div className="max-w-2xl space-y-2">
              <p className="h-4 text-xs font-medium text-emerald-300">{today}</p>
              <h2 className="text-2xl font-extrabold tracking-tight md:text-3xl">
                {salam}, {user?.name?.split(' ')[0] || 'Admin'}
              </h2>
              <p className="text-sm leading-relaxed text-slate-300">
                Pantau role, personil, pelanggan, dan operasional marketplace dari satu tempat.
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-2.5">
              <Link
                href="/dashboard/roles"
                className="inline-flex items-center gap-2 rounded-xl bg-emerald-500 px-4 py-2.5 text-xs font-bold text-white shadow-lg shadow-emerald-500/30 transition-colors hover:bg-emerald-400"
              >
                <Plus className="h-4 w-4" />
                Buat Role Baru
              </Link>
              <Link
                href="/dashboard/users"
                className="inline-flex items-center gap-2 rounded-xl border border-white/15 bg-white/10 px-4 py-2.5 text-xs font-bold text-white backdrop-blur transition-colors hover:bg-white/20"
              >
                <UserCog className="h-4 w-4" />
                Tambah Staff
              </Link>
            </div>
          </div>
        </section>

        {/* Stats */}
        <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {stats.map((s) => {
            const Icon = s.icon;
            return (
              <Link
                key={s.label}
                href={s.href}
                className="group rounded-2xl border border-slate-200/80 bg-white p-5 shadow-xs transition-all duration-200 hover:-translate-y-0.5 hover:border-emerald-200 hover:shadow-lg hover:shadow-slate-900/5"
              >
                <div className="flex items-start justify-between">
                  <div>
                    <p className="text-xs font-semibold text-slate-500">{s.label}</p>
                    {loading ? (
                      <div className="skeleton mt-3 h-8 w-16" />
                    ) : (
                      <p className="mt-2 text-3xl font-extrabold tracking-tight text-slate-900 tabular-nums">
                        {s.value.toLocaleString('id-ID')}
                      </p>
                    )}
                  </div>
                  <div className={`flex h-11 w-11 items-center justify-center rounded-xl ring-1 ${s.tone}`}>
                    <Icon className="h-5 w-5" />
                  </div>
                </div>
                <div className="mt-4 flex items-center justify-between text-xs text-slate-400">
                  <span>{s.hint}</span>
                  <ArrowRight className="h-3.5 w-3.5 -translate-x-1 opacity-0 transition-all group-hover:translate-x-0 group-hover:text-emerald-600 group-hover:opacity-100" />
                </div>
              </Link>
            );
          })}
        </section>

        {/* Shortcuts */}
        <section className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {shortcuts.map((s) => {
            const Icon = s.icon;
            return (
              <Link
                key={s.name}
                href={s.href}
                className="group flex items-center gap-3 rounded-xl border border-slate-200/80 bg-white px-4 py-3 text-sm font-semibold text-slate-700 shadow-xs transition-all hover:border-emerald-300 hover:text-emerald-700"
              >
                <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-slate-100 text-slate-500 transition-colors group-hover:bg-emerald-50 group-hover:text-emerald-600">
                  <Icon className="h-4 w-4" />
                </span>
                {s.name}
              </Link>
            );
          })}
        </section>

        <div className="grid grid-cols-1 gap-6 xl:grid-cols-5">
          {/* Roles */}
          <section className="rounded-2xl border border-slate-200/80 bg-white shadow-xs xl:col-span-3">
            <div className="flex items-center justify-between border-b border-slate-100 px-6 py-4">
              <div>
                <h3 className="text-base font-bold text-slate-900">Role Hak Akses</h3>
                <p className="text-xs text-slate-500">Role operasional yang dikonfigurasi di platform</p>
              </div>
              <Link
                href="/dashboard/roles"
                className="inline-flex items-center gap-1.5 text-xs font-bold text-emerald-600 hover:text-emerald-700"
              >
                Kelola <ArrowRight className="h-3.5 w-3.5" />
              </Link>
            </div>

            <div className="grid grid-cols-1 gap-3 p-5 sm:grid-cols-2">
              {loading
                ? Array.from({ length: 4 }).map((_, i) => <div key={i} className="skeleton h-28" />)
                : roles.map((r) => (
                    <div
                      key={r.id}
                      className="flex flex-col justify-between rounded-xl border border-slate-100 bg-slate-50/60 p-4 transition-colors hover:border-emerald-200 hover:bg-emerald-50/30"
                    >
                      <div>
                        <div className="flex items-center justify-between gap-2">
                          <span className="truncate text-sm font-bold text-slate-900">{r.name}</span>
                          <span
                            className={`shrink-0 rounded-md px-2 py-0.5 text-[10px] font-semibold ${
                              r.is_system ? 'bg-slate-200 text-slate-700' : 'bg-emerald-100 text-emerald-700'
                            }`}
                          >
                            {r.is_system ? 'System' : 'Custom'}
                          </span>
                        </div>
                        <p className="mt-1.5 line-clamp-2 text-xs text-slate-500">
                          {r.description || 'Tidak ada deskripsi.'}
                        </p>
                      </div>
                      <div className="mt-3 flex items-center justify-between border-t border-slate-200/60 pt-3 text-xs text-slate-500">
                        <span>
                          {r.permissions?.includes('*') ? 'Semua Hak Akses' : `${r.permissions?.length || 0} Izin`}
                        </span>
                        <span className="font-semibold text-slate-800">{r.users_count || 0} Personil</span>
                      </div>
                    </div>
                  ))}
            </div>
          </section>

          {/* Staff */}
          <section className="rounded-2xl border border-slate-200/80 bg-white shadow-xs xl:col-span-2">
            <div className="flex items-center justify-between border-b border-slate-100 px-6 py-4">
              <div>
                <h3 className="text-base font-bold text-slate-900">Personil Terbaru</h3>
                <p className="text-xs text-slate-500">Akun dengan akses login admin</p>
              </div>
              <Link
                href="/dashboard/users"
                className="inline-flex items-center gap-1.5 text-xs font-bold text-emerald-600 hover:text-emerald-700"
              >
                Semua <ArrowRight className="h-3.5 w-3.5" />
              </Link>
            </div>

            <div className="divide-y divide-slate-100 px-6">
              {loading ? (
                Array.from({ length: 4 }).map((_, i) => (
                  <div key={i} className="flex items-center gap-3 py-3.5">
                    <div className="skeleton h-10 w-10 !rounded-full" />
                    <div className="flex-1 space-y-2">
                      <div className="skeleton h-3 w-2/3" />
                      <div className="skeleton h-3 w-1/2" />
                    </div>
                  </div>
                ))
              ) : staffUsers.length === 0 ? (
                <p className="py-10 text-center text-sm text-slate-400">Belum ada personil.</p>
              ) : (
                staffUsers.slice(0, 5).map((u, i) => (
                  <div key={u.id} className="flex items-center justify-between gap-3 py-3.5">
                    <div className="flex min-w-0 items-center gap-3">
                      <div
                        className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-gradient-to-br text-xs font-bold text-white ${AVATAR_COLORS[i % AVATAR_COLORS.length]}`}
                      >
                        {u.name.slice(0, 2).toUpperCase()}
                      </div>
                      <div className="min-w-0">
                        <h4 className="truncate text-sm font-semibold text-slate-900">{u.name}</h4>
                        <p className="truncate text-xs text-slate-500">{u.email}</p>
                      </div>
                    </div>
                    <span className="shrink-0 rounded-full border border-emerald-200 bg-emerald-50 px-2.5 py-0.5 text-[11px] font-semibold text-emerald-700">
                      {u.role?.name || (u.is_super_admin ? 'Super Admin' : 'Staff')}
                    </span>
                  </div>
                ))
              )}
            </div>
          </section>
        </div>
      </div>
    </AdminLayout>
  );
}
