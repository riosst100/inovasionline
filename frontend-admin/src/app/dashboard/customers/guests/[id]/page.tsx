'use client';

import React, { Suspense, useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { ArrowLeft, Loader2, Smartphone } from 'lucide-react';
import AdminLayout from '../../../../../components/layout/AdminLayout';
import InstallDetailView from '../../../../../components/customers/InstallDetail';
import { adminApi } from '../../../../../lib/api';
import { GuestInstallDetail } from '../../../../../types';

function GuestDetailPageContent() {
  const { id } = useParams<{ id: string }>();
  const [g, setG] = useState<GuestInstallDetail | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    adminApi.getGuest(id).then(setG).catch((e) => setError(e instanceof Error ? e.message : 'Gagal memuat detail guest.'));
  }, [id]);

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div>
          <Link href="/dashboard/customers" className="inline-flex items-center gap-1 text-xs font-semibold text-slate-500 hover:text-slate-800">
            <ArrowLeft className="h-3.5 w-3.5" /> Kembali ke Data Pengguna
          </Link>
          <div className="mt-2 flex items-center gap-2">
            <Smartphone className="h-6 w-6 text-emerald-600" />
            <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">Detail Guest</h2>
          </div>
        </div>

        {error && <p className="text-sm font-semibold text-red-600">{error}</p>}
        {!g && !error && <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />}

        {g && (
          <InstallDetailView g={g} />
        )}
      </div>
    </AdminLayout>
  );
}

// useParams() must sit inside <Suspense> or prerendering the dynamic route fails the build.
export default function GuestDetailPage() {
  return (
    <Suspense>
      <GuestDetailPageContent />
    </Suspense>
  );
}
