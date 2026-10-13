'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import AdminLayout from '../../components/layout/AdminLayout';
import { useAuth } from '../../context/AuthContext';
import { adminApi } from '../../lib/api';
import { Role, AdminUser } from '../../types';
import {
  Users,
  ShieldCheck,
  Plus,
  ArrowRight,
  Sparkles,
  Truck,
  DollarSign,
  UserCog,
  Users2
} from 'lucide-react';

export default function DashboardOverviewPage() {
  const { user } = useAuth();
  const [roles, setRoles] = useState<Role[]>([]);
  const [staffUsers, setStaffUsers] = useState<AdminUser[]>([]);
  const [totalCustomers, setTotalCustomers] = useState(0);
  const [loading, setLoading] = useState(true);

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

  const totalRoles = roles.length;
  const totalStaff = staffUsers.length;

  return (
    <AdminLayout>
      <div className="space-y-8">
        {/* Welcome Hero Banner */}
        <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-slate-900 via-slate-800 to-emerald-950 p-6 md:p-8 text-white shadow-xl">
          <div className="relative z-10 flex flex-col md:flex-row md:items-center md:justify-between gap-6">
            <div className="space-y-2 max-w-2xl">
              <div className="inline-flex items-center gap-2 rounded-full bg-emerald-500/20 px-3 py-1 text-xs font-semibold text-emerald-300 border border-emerald-500/30">
                <Sparkles className="h-3.5 w-3.5" />
                <span>Pusat Kendali Super Admin & Multi-Role</span>
              </div>
              <h2 className="text-2xl md:text-3xl font-extrabold tracking-tight">
                Selamat Datang, {user?.name || 'Super Admin'}! 👋
              </h2>
              <p className="text-sm text-slate-300 leading-relaxed">
                Portal admin ini terpisah sepenuhnya dari akun customer marketplace. Anda dapat mengelola hak akses kustom untuk personil <span className="text-emerald-300 font-semibold">Driver, Sales, Admin</span>, serta memonitor customer dan pesanan.
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <Link
                href="/dashboard/roles"
                className="flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2.5 text-xs font-bold text-white shadow-md shadow-emerald-600/30 hover:bg-emerald-500 transition-colors"
              >
                <Plus className="h-4 w-4" />
                <span>Buat Role Baru</span>
              </Link>
              <Link
                href="/dashboard/users"
                className="flex items-center gap-2 rounded-xl bg-slate-800 px-4 py-2.5 text-xs font-bold text-slate-200 hover:bg-slate-700 transition-colors border border-slate-700"
              >
                <UserCog className="h-4 w-4" />
                <span>Tambah User Staff</span>
              </Link>
            </div>
          </div>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-xs transition-hover hover:shadow-md">
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                Total Role Terdaftar
              </span>
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50 text-emerald-600">
                <ShieldCheck className="h-5 w-5" />
              </div>
            </div>
            <div className="mt-3 flex items-baseline gap-2">
              <span className="text-2xl font-extrabold text-slate-900">{totalRoles}</span>
              <span className="text-xs text-slate-500">role aktif</span>
            </div>
            <p className="mt-2 text-xs text-slate-400">Termasuk Driver, Sales, Admin</p>
          </div>

          <div className="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-xs transition-hover hover:shadow-md">
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                User Admin & Staff
              </span>
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-blue-50 text-blue-600">
                <UserCog className="h-5 w-5" />
              </div>
            </div>
            <div className="mt-3 flex items-baseline gap-2">
              <span className="text-2xl font-extrabold text-slate-900">{totalStaff}</span>
              <span className="text-xs text-slate-500">personil</span>
            </div>
            <p className="mt-2 text-xs text-slate-400">Akun internal admin_users</p>
          </div>

          <div className="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-xs transition-hover hover:shadow-md">
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                Total Customer Pembeli
              </span>
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-50 text-amber-600">
                <Users2 className="h-5 w-5" />
              </div>
            </div>
            <div className="mt-3 flex items-baseline gap-2">
              <span className="text-2xl font-extrabold text-slate-900">{totalCustomers}</span>
              <span className="text-xs text-slate-500">pelanggan</span>
            </div>
            <p className="mt-2 text-xs text-slate-400">Pengguna aplikasi marketplace</p>
          </div>

          <div className="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-xs transition-hover hover:shadow-md">
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                Kurir
              </span>
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-purple-50 text-purple-600">
                <Truck className="h-5 w-5" />
              </div>
            </div>
            <div className="mt-3 flex items-baseline gap-2">
              <span className="text-2xl font-extrabold text-slate-900">
                {roles.find(r => r.slug === 'driver')?.users_count ?? 0}
              </span>
              <span className="text-xs text-slate-500">kurir siap</span>
            </div>
            <p className="mt-2 text-xs text-slate-400">Petugas pengantaran pesanan</p>
          </div>
        </div>

        {/* Roles Quick Overview List */}
        <div className="rounded-2xl border border-slate-200/80 bg-white p-6 shadow-xs">
          <div className="flex items-center justify-between border-b border-slate-100 pb-4">
            <div>
              <h3 className="text-base font-bold text-slate-900">
                Daftar Role Hak Akses Sistem
              </h3>
              <p className="text-xs text-slate-500">
                Role operasional yang dikonfigurasikan di platform
              </p>
            </div>
            <Link
              href="/dashboard/roles"
              className="flex items-center gap-1.5 text-xs font-bold text-emerald-600 hover:text-emerald-700"
            >
              <span>Kelola Semua Role</span>
              <ArrowRight className="h-3.5 w-3.5" />
            </Link>
          </div>

          <div className="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {roles.map((r) => (
              <div
                key={r.id}
                className="flex flex-col justify-between rounded-xl border border-slate-100 bg-slate-50/70 p-4 transition-all hover:border-emerald-300 hover:bg-emerald-50/20"
              >
                <div>
                  <div className="flex items-center justify-between">
                    <span className="font-bold text-sm text-slate-900">{r.name}</span>
                    {r.is_system ? (
                      <span className="rounded-md bg-slate-200 px-2 py-0.5 text-[10px] font-semibold text-slate-700">
                        System
                      </span>
                    ) : (
                      <span className="rounded-md bg-emerald-100 px-2 py-0.5 text-[10px] font-semibold text-emerald-700">
                        Custom
                      </span>
                    )}
                  </div>
                  <p className="mt-1.5 line-clamp-2 text-xs text-slate-500">
                    {r.description || 'Tidak ada deskripsi.'}
                  </p>
                </div>

                <div className="mt-4 flex items-center justify-between border-t border-slate-200/60 pt-3 text-xs text-slate-500">
                  <span>{r.permissions?.includes('*') ? 'Semua Hak Akses' : `${r.permissions?.length || 0} Izin`}</span>
                  <span className="font-semibold text-slate-800">{r.users_count || 0} Personil</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Quick Staff Members List */}
        <div className="rounded-2xl border border-slate-200/80 bg-white p-6 shadow-xs">
          <div className="flex items-center justify-between border-b border-slate-100 pb-4">
            <div>
              <h3 className="text-base font-bold text-slate-900">
                Personil Staff & Admin Terdaftar
              </h3>
              <p className="text-xs text-slate-500">
                Daftar akun personil yang memiliki hak akses login ke sistem admin
              </p>
            </div>
            <Link
              href="/dashboard/users"
              className="flex items-center gap-1.5 text-xs font-bold text-emerald-600 hover:text-emerald-700"
            >
              <span>Lihat Semua Staff</span>
              <ArrowRight className="h-3.5 w-3.5" />
            </Link>
          </div>

          <div className="mt-4 divide-y divide-slate-100">
            {staffUsers.slice(0, 5).map((u) => (
              <div key={u.id} className="flex items-center justify-between py-3.5">
                <div className="flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center rounded-full bg-slate-800 font-bold text-xs text-white">
                    {u.name.slice(0, 2).toUpperCase()}
                  </div>
                  <div>
                    <h4 className="text-sm font-semibold text-slate-900">{u.name}</h4>
                    <p className="text-xs text-slate-500">{u.email}</p>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  <span className="rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-700 border border-emerald-200">
                    {u.role?.name || (u.is_super_admin ? 'Super Admin' : 'Staff')}
                  </span>
                  <span className="text-xs text-slate-400">
                    {new Date(u.created_at).toLocaleDateString('id-ID')}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </AdminLayout>
  );
}
