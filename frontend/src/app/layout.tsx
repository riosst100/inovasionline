import type { Metadata } from 'next';
import Link from 'next/link';
import './globals.css';
import { SITE_NAME, SITE_URL } from '@/lib/site';

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: { default: SITE_NAME, template: `%s | ${SITE_NAME}` },
  description: 'Inovasi Online — belanja online dan layanan pengantaran dalam satu aplikasi.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id">
      <body className="min-h-screen flex flex-col antialiased font-sans">
        <header className="bg-white border-b border-slate-200">
          <div className="mx-auto max-w-4xl px-4 h-16 flex items-center justify-between">
            <Link href="/" className="flex items-center gap-2 font-bold text-lg">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src="/logo.png" alt="" width={32} height={32} />
              {SITE_NAME}
            </Link>
            <nav className="flex gap-4 text-sm text-slate-600">
              <Link href="/download" className="hover:text-brand">Download</Link>
              <Link href="/privacy-policy" className="hover:text-brand">Kebijakan Privasi</Link>
              <Link href="/hapus-akun" className="hover:text-brand">Hapus Akun</Link>
            </nav>
          </div>
        </header>
        <main className="flex-1">{children}</main>
        <footer className="border-t border-slate-200 bg-white py-6 text-center text-sm text-slate-500">
          © {new Date().getFullYear()} {SITE_NAME}. Semua hak dilindungi.
        </footer>
      </body>
    </html>
  );
}
