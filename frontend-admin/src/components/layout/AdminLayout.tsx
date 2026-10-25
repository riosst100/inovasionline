'use client';

import React, { useState, useEffect } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { ShieldAlert } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import AdminSidebar, { firstAllowedHref, menuForPath } from './AdminSidebar';
import AdminHeader from './AdminHeader';
import { InstantOrderBanner } from '../orders/InstantOrders';

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { isAuthenticated, isLoading, canView } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const menu = menuForPath(pathname);
  const denied = menu !== null && !canView(menu);

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/login');
    }
  }, [isLoading, isAuthenticated, router]);

  // Login lands on /dashboard; roles without the dashboard go to their first menu instead.
  const landing = pathname === '/dashboard' && denied ? firstAllowedHref(canView) : null;
  useEffect(() => {
    if (!isLoading && landing) router.replace(landing);
  }, [isLoading, landing, router]);

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
        {/* Not on the dashboard (it has the order panels) or the orders page itself. */}
        {canView('orders') && pathname !== '/dashboard' && menu !== 'orders' && <InstantOrderBanner />}
        <main className="page-enter mx-auto w-full max-w-7xl flex-1 p-4 sm:p-6 lg:p-8">
          {denied ? (
            landing ? null : (
              <div className="mx-auto mt-16 max-w-md rounded-2xl border border-slate-200 bg-white p-8 text-center shadow-xs">
                <ShieldAlert className="mx-auto h-10 w-10 text-amber-500" />
                <h2 className="mt-3 text-lg font-bold text-slate-900">Tidak punya akses</h2>
                <p className="mt-1 text-sm text-slate-500">
                  Role Anda belum diberi hak akses ke menu ini. Hubungi Super Admin bila Anda memerlukannya.
                </p>
              </div>
            )
          ) : (
            children
          )}
        </main>
        <footer className="px-8 pb-6 text-center text-[11px] text-slate-400">
          © {new Date().getFullYear()} Inovasi Online · Admin Portal
        </footer>
      </div>
    </div>
  );
}
