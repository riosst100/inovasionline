'use client';

import React, { Suspense, useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import AdminLayout from '../../../../components/layout/AdminLayout';
import WarehouseForm from '../../../../components/warehouses/WarehouseForm';
import { adminApi, ApiError } from '../../../../lib/api';
import { Warehouse } from '../../../../types';
import { AlertCircle, ArrowLeft, Loader2 } from 'lucide-react';

function EditWarehouse() {
  const { id } = useParams<{ id: string }>();
  const [warehouse, setWarehouse] = useState<Warehouse | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    adminApi
      .getWarehouse(id)
      .then(setWarehouse)
      .catch((e) => setError(e instanceof ApiError ? e.message : 'Gagal memuat gudang.'));
  }, [id]);

  return (
    <AdminLayout>
      <div className="mx-auto max-w-3xl space-y-6">
        <div>
          <Link href="/dashboard/warehouses" className="mb-2 inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-800">
            <ArrowLeft className="h-4 w-4" /> Kembali
          </Link>
          <h1 className="text-2xl font-bold text-slate-900">Ubah Gudang</h1>
        </div>
        {error ? (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        ) : !warehouse ? (
          <div className="flex justify-center p-10">
            <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
          </div>
        ) : (
          <WarehouseForm warehouse={warehouse} />
        )}
      </div>
    </AdminLayout>
  );
}

export default function EditWarehousePage() {
  return (
    <Suspense
      fallback={
        <AdminLayout>
          <div className="flex justify-center p-10">
            <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
          </div>
        </AdminLayout>
      }
    >
      <EditWarehouse />
    </Suspense>
  );
}
