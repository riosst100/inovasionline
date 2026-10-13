'use client';

import React, { useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { apiRequest } from '../../../lib/api';
import { ShoppingBag, Loader2, PackageCheck } from 'lucide-react';

export default function AdminOrdersPage() {
  const [orders, setOrders] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    apiRequest<any>('/admin/orders')
      .then((data) => setOrders(data?.data || []))
      .catch(() => setOrders([]))
      .finally(() => setLoading(false));
  }, []);

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div>
          <div className="flex items-center gap-2">
            <ShoppingBag className="h-6 w-6 text-emerald-600" />
            <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">
              Transaksi & Pesanan Marketplace
            </h2>
          </div>
          <p className="mt-1 text-xs md:text-sm text-slate-500">
            Monitoring pesanan masuk dari pembeli dan penugasan status pengiriman driver.
          </p>
        </div>

        <div className="rounded-2xl border border-slate-200/80 bg-white p-6 shadow-xs">
          {loading ? (
            <div className="py-12 flex justify-center text-emerald-600">
              <Loader2 className="h-6 w-6 animate-spin" />
            </div>
          ) : orders.length === 0 ? (
            <div className="py-16 text-center text-slate-400">
              <PackageCheck className="h-10 w-10 mx-auto text-slate-300 mb-2" />
              <p className="text-sm font-medium">Belum ada pesanan transaksi baru.</p>
            </div>
          ) : (
            <div className="divide-y divide-slate-100">
              {orders.map((o) => (
                <div key={o.id} className="py-3 flex items-center justify-between text-xs">
                  <div>
                    <span className="font-bold text-slate-800">#{o.id}</span>
                    <span className="ml-2 text-slate-500">{o.customer_name}</span>
                  </div>
                  <span className="font-semibold text-emerald-700">{o.status}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </AdminLayout>
  );
}
