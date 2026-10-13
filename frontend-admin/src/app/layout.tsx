import type { Metadata } from 'next';
import './globals.css';
import { AuthProvider } from '../context/AuthContext';

export const metadata: Metadata = {
  title: 'Inovasi Online - Admin Portal & Multi-Role Dashboard',
  description: 'Portal Admin Inovasi Online untuk pengelolaan Super Admin, Role (Driver, Admin, Sales), Katalog, dan Pengguna.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="id">
      <body className="min-h-screen bg-slate-50 antialiased font-sans">
        <AuthProvider>
          {children}
        </AuthProvider>
      </body>
    </html>
  );
}
