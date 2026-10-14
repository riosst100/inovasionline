'use client';

import React from 'react';
import Link from 'next/link';
import AdminLayout from '../../../../components/layout/AdminLayout';
import WarehouseForm from '../../../../components/warehouses/WarehouseForm';
import { ArrowLeft } from 'lucide-react';

export default function NewWarehousePage() {
  return (
    <AdminLayout>
      <div className="mx-auto max-w-3xl space-y-6">
        <div>
          <Link href="/dashboard/warehouses" className="mb-2 inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-800">
            <ArrowLeft className="h-4 w-4" /> Kembali
          </Link>
          <h1 className="text-2xl font-bold text-slate-900">Tambah Gudang</h1>
        </div>
        <WarehouseForm warehouse={null} />
      </div>
    </AdminLayout>
  );
}
