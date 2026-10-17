'use client';

import React from 'react';
import AdminLayout from '../layout/AdminLayout';

interface PromotionPlaceholderProps {
  title: string;
  description: string;
  icon: React.ElementType;
}

export default function PromotionPlaceholder({ title, description, icon: Icon }: PromotionPlaceholderProps) {
  return (
    <AdminLayout>
      <div className="mx-auto max-w-5xl space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">{title}</h1>
          <p className="text-sm text-slate-500">{description}</p>
        </div>

        <div className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-slate-300 bg-white p-12 text-center">
          <div className="mb-3 flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-50 text-emerald-600">
            <Icon className="h-6 w-6" />
          </div>
          <p className="font-semibold text-slate-800">Belum ada {title.toLowerCase()}</p>
          <p className="mt-1 text-sm text-slate-500">Fitur pengelolaan {title.toLowerCase()} sedang disiapkan.</p>
        </div>
      </div>
    </AdminLayout>
  );
}
