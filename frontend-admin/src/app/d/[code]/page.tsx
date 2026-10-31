'use client';

import React, { Suspense, useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import { PackageCheck, ShoppingBag, Truck } from 'lucide-react';

/**
 * Landing page of the parcel QR label (public, no login). The QR is a link to here, so a phone camera
 * can open it: the driver goes on to the driver app (scan), the buyer to the Inovasi Online app (order).
 */
export default function ParcelLinkPage() {
  return (
    <Suspense fallback={null}>
      <ParcelLink />
    </Suspense>
  );
}

function ParcelLink() {
  const params = useParams<{ code: string }>();
  const code = decodeURIComponent(String(params.code ?? ''));
  const [orderId, setOrderId] = useState('');

  useEffect(() => {
    setOrderId(new URLSearchParams(window.location.search).get('o') ?? '');
  }, []);

  const driverLink = `iodriver://scan?code=${encodeURIComponent(code)}`;
  const buyerLink = `inovasionline://app/orders/${encodeURIComponent(orderId)}`;

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 p-4">
      <div className="w-full max-w-sm rounded-2xl bg-white p-6 text-center shadow-sm">
        <PackageCheck className="mx-auto h-10 w-10 text-emerald-600" />
        <h1 className="mt-3 text-lg font-extrabold text-slate-900">Paket Inovasi Online</h1>
        <p className="mt-1 text-sm text-slate-500">Pilih aplikasi untuk membuka paket ini.</p>

        <a
          href={driverLink}
          className="mt-5 flex items-center justify-center gap-2 rounded-xl bg-emerald-600 py-3 text-sm font-bold text-white hover:bg-emerald-700"
        >
          <Truck className="h-4 w-4" /> Buka di Aplikasi Driver
        </a>
        {orderId && (
          <a
            href={buyerLink}
            className="mt-3 flex items-center justify-center gap-2 rounded-xl border border-emerald-600 py-3 text-sm font-bold text-emerald-700 hover:bg-emerald-50"
          >
            <ShoppingBag className="h-4 w-4" /> Buka di Aplikasi Inovasi Online
          </a>
        )}
        <p className="mt-4 text-xs text-slate-400">Aplikasi belum terpasang? Pasang dulu, lalu buka link ini lagi.</p>
      </div>
    </main>
  );
}
