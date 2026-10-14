'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '../../context/AuthContext';
import AdminSidebar from './AdminSidebar';
import AdminHeader from './AdminHeader';

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { isAuthenticated, isLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/login');
    }
  }, [isLoading, isAuthenticated, router]);

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#f6f8fa]">
        <div className="flex items-center gap-2.5 text-sm font-medium text-slate-500">
          <svg className="h-4 w-4" viewBox="0 0 50 50" aria-hidden="true">
            <circle cx="25" cy="25" r="20" fill="none" stroke="#d1fae5" strokeWidth="6" />
            <circle
              cx="25"
              cy="25"
              r="20"
              fill="none"
              stroke="#10b981"
              strokeWidth="6"
              strokeLinecap="round"
              strokeDasharray="35 100"
            >
              <animateTransform
                attributeName="transform"
                type="rotate"
                from="0 25 25"
                to="360 25 25"
                dur="0.9s"
                repeatCount="indefinite"
              />
            </circle>
          </svg>
          Loading Dashboard Admin...
        </div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return null;
  }

  return (
    <div className="min-h-screen bg-[#f6f8fa] text-slate-900">
      <AdminSidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      <div className="flex min-h-screen flex-col lg:pl-72">
        <AdminHeader onMenuToggle={() => setSidebarOpen(true)} />
        <main className="page-enter mx-auto w-full max-w-7xl flex-1 p-4 sm:p-6 lg:p-8">
          {children}
        </main>
        <footer className="px-8 pb-6 text-center text-[11px] text-slate-400">
          © {new Date().getFullYear()} Inovasi Online · Admin Portal
        </footer>
      </div>
    </div>
  );
}
