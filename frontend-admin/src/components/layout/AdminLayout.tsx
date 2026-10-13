'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '../../context/AuthContext';
import AdminSidebar from './AdminSidebar';
import AdminHeader from './AdminHeader';
import { Loader2 } from 'lucide-react';

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { user, token, isLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && !token) {
      router.push('/login');
    }
  }, [isLoading, token, router]);

  if (isLoading) {
    return (
      <div className="flex h-screen w-full items-center justify-center bg-slate-50">
        <div className="flex flex-col items-center gap-3">
          <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
          <p className="text-sm font-medium text-slate-600">Memuat Portal Admin...</p>
        </div>
      </div>
    );
  }

  if (!token) {
    return null;
  }

  return (
    <div className="min-h-screen bg-slate-50/70 text-slate-900">
      <AdminSidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      <div className="flex flex-col lg:pl-72">
        <AdminHeader onMenuToggle={() => setSidebarOpen(true)} />
        <main className="flex-1 p-6 md:p-8 max-w-7xl w-full mx-auto">
          {children}
        </main>
      </div>
    </div>
  );
}
