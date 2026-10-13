'use client';

import React, { useEffect, useState } from 'react';
import AdminLayout from '../../../components/layout/AdminLayout';
import { apiRequest } from '../../../lib/api';
import { FolderTree, Loader2 } from 'lucide-react';

export default function AdminCategoriesPage() {
  const [categories, setCategories] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    apiRequest<any[]>('/categories')
      .then((data) => setCategories(data || []))
      .catch(() => setCategories([]))
      .finally(() => setLoading(false));
  }, []);

  return (
    <AdminLayout>
      <div className="space-y-6">
        <div>
          <div className="flex items-center gap-2">
            <FolderTree className="h-6 w-6 text-emerald-600" />
            <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">
              Katalog Kategori Produk
            </h2>
          </div>
          <p className="mt-1 text-xs md:text-sm text-slate-500">
            Daftar pengelompokan kategori produk di marketplace.
          </p>
        </div>

        <div className="rounded-2xl border border-slate-200/80 bg-white p-6 shadow-xs">
          {loading ? (
            <div className="py-12 flex justify-center text-emerald-600">
              <Loader2 className="h-6 w-6 animate-spin" />
            </div>
          ) : categories.length === 0 ? (
            <div className="py-12 text-center text-slate-400 text-sm">
              Belum ada kategori terdaftar.
            </div>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3">
              {categories.map((c) => (
                <div key={c.id} className="flex flex-col items-center justify-center p-4 rounded-xl border border-slate-100 bg-slate-50 hover:border-emerald-300 transition-colors text-center">
                  <div className="h-12 w-12 rounded-xl bg-emerald-100 flex items-center justify-center text-emerald-700 font-bold text-sm mb-2">
                    {c.icon_url ? <img src={c.icon_url} alt={c.name} className="h-8 w-8 object-contain" /> : c.name.slice(0, 2)}
                  </div>
                  <span className="text-xs font-bold text-slate-800 line-clamp-1">{c.name}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </AdminLayout>
  );
}
