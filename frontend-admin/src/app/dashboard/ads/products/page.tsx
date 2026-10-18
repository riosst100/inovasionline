'use client';

import React from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { PackageOpen } from 'lucide-react';

export default function AdProductsPage() {
  return (
    <AdminLayout>
      <div className="mx-auto max-w-3xl space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Iklan Produk</h1>
          <p className="text-sm text-slate-500">Kelola produk yang dipromosikan sebagai iklan di aplikasi.</p>
        </div>

        <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-slate-200 bg-white p-10 text-center">
          <PackageOpen className="h-10 w-10 text-slate-300" />
          <p className="text-sm text-slate-500">Belum ada iklan.</p>
        </div>
      </div>
    </AdminLayout>
  );
}
