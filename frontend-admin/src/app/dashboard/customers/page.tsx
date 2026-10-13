'use client';

import React, { useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { adminApi } from '../../../lib/api';
import { Customer } from '../../../types';
import {
  Users2,
  Search,
  Loader2,
  CheckCircle,
  XCircle,
  Store
} from 'lucide-react';

export default function CustomersPage() {
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [total, setTotal] = useState(0);

  const fetchCustomers = async () => {
    try {
      setLoading(true);
      const res = await adminApi.getCustomers({ search: search || undefined });
      setCustomers(res.data || []);
      setTotal(res.total || 0);
    } catch {
      setCustomers([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCustomers();
  }, []);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    fetchCustomers();
  };

  return (
    <AdminLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <div className="flex items-center gap-2">
              <Users2 className="h-6 w-6 text-emerald-600" />
              <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">
                Data Pelanggan (Customer Marketplace)
              </h2>
            </div>
            <p className="mt-1 text-xs md:text-sm text-slate-500">
              Daftar pembeli dan pengguna yang mendaftar melalui aplikasi mobile Inovasi Online ({total} pelanggan).
            </p>
          </div>
        </div>

        {/* Search */}
        <div className="flex items-center justify-between rounded-2xl border border-slate-200/80 bg-white p-4 shadow-xs">
          <form onSubmit={handleSearchSubmit} className="relative w-full sm:w-96">
            <Search className="pointer-events-none absolute inset-y-0 left-0 my-auto ml-3 h-4 w-4 text-slate-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Cari nama, email, atau no. telepon..."
              className="w-full rounded-xl border border-slate-200 bg-slate-50 py-2 pl-9 pr-3 text-xs md:text-sm text-slate-900 outline-none focus:border-emerald-500 focus:bg-white focus:ring-1 focus:ring-emerald-500"
            />
          </form>
        </div>

        {/* Table */}
        <div className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-xs">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs md:text-sm">
              <thead className="border-b border-slate-200 bg-slate-50/80 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                <tr>
                  <th className="py-3.5 px-5">Nama Pelanggan</th>
                  <th className="py-3.5 px-5">Kontak</th>
                  <th className="py-3.5 px-5">Status Verifikasi</th>
                  <th className="py-3.5 px-5">Tipe Akun</th>
                  <th className="py-3.5 px-5">Terdaftar Sejak</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 font-medium">
                {loading ? (
                  <tr>
                    <td colSpan={5} className="py-12 text-center text-slate-400">
                      <div className="flex flex-col items-center gap-2">
                        <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />
                        <span>Memuat data pelanggan...</span>
                      </div>
                    </td>
                  </tr>
                ) : customers.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="py-12 text-center text-slate-400">
                      Belum ada data pelanggan yang terdaftar.
                    </td>
                  </tr>
                ) : (
                  customers.map((c) => (
                    <tr key={c.id} className="hover:bg-slate-50/60 transition-colors">
                      <td className="py-4 px-5">
                        <div className="flex items-center gap-3">
                          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-slate-200 font-bold text-xs text-slate-700 shrink-0">
                            {c.name.slice(0, 2).toUpperCase()}
                          </div>
                          <div>
                            <span className="font-bold text-slate-900">{c.name}</span>
                            <p className="text-xs text-slate-400">{c.email}</p>
                          </div>
                        </div>
                      </td>
                      <td className="py-4 px-5 text-xs text-slate-600">
                        {c.phone || '-'}
                      </td>
                      <td className="py-4 px-5">
                        {c.is_verified ? (
                          <span className="inline-flex items-center gap-1 rounded-md bg-emerald-50 px-2 py-0.5 text-xs font-semibold text-emerald-700">
                            <CheckCircle className="h-3.5 w-3.5" /> Terverifikasi
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 rounded-md bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-500">
                            <XCircle className="h-3.5 w-3.5" /> Belum Verifikasi
                          </span>
                        )}
                      </td>
                      <td className="py-4 px-5">
                        {c.is_seller ? (
                          <span className="inline-flex items-center gap-1 rounded-md bg-blue-50 px-2 py-0.5 text-xs font-semibold text-blue-700 border border-blue-200">
                            <Store className="h-3.5 w-3.5" /> Penjual (Seller)
                          </span>
                        ) : (
                          <span className="rounded-md bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-600">
                            Pembeli Biasa
                          </span>
                        )}
                      </td>
                      <td className="py-4 px-5 text-xs text-slate-500">
                        {new Date(c.created_at).toLocaleDateString('id-ID', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric',
                        })}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </AdminLayout>
  );
}
