'use client';

import React from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { Award } from 'lucide-react';

export default function AdBrandsPage() {
  return (
    <AdminLayout>
      <div className="mx-auto max-w-3xl space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Iklan Brands</h1>
          <p className="text-sm text-slate-500">Kelola brand yang dipromosikan sebagai iklan di aplikasi.</p>
        </div>

        <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-slate-200 bg-white p-10 text-center">
          <Award className="h-10 w-10 text-slate-300" />
          <p className="text-sm text-slate-500">Belum ada iklan.</p>
        </div>
      </div>
    </AdminLayout>
  );
}
