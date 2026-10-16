import type { Metadata } from 'next';
import { API_URL, SITE_NAME } from '@/lib/site';

export const metadata: Metadata = {
  title: 'Download Aplikasi Android',
  description: `Unduh aplikasi ${SITE_NAME} untuk Android (file APK).`,
};

// Selalu ambil info versi terbaru dari backend.
export const dynamic = 'force-dynamic';

type LatestVersion = {
  version: string;
  build_number: number;
  release_notes: string;
  apk_url: string | null;
};

async function getLatest(): Promise<LatestVersion | null> {
  try {
    const res = await fetch(`${API_URL}/app-version/latest`, { cache: 'no-store' });
    if (!res.ok) return null;
    const json = await res.json();
    return json.data ?? null;
  } catch {
    return null;
  }
}

export default async function DownloadPage() {
  const latest = await getLatest();
  const apkUrl = latest?.apk_url ?? null;

  return (
    <div className="mx-auto max-w-2xl px-4 py-12">
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-8 text-center">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo.png" alt={SITE_NAME} width={80} height={80} className="mx-auto mb-4" />
        <h1 className="text-2xl font-bold">Download {SITE_NAME}</h1>
        <p className="mt-2 text-slate-600">Aplikasi resmi untuk Android.</p>

        {latest && (
          <p className="mt-4 text-sm text-slate-500">
            Versi {latest.version} (build {latest.build_number})
          </p>
        )}

        {apkUrl ? (
          <a
            href={apkUrl}
            download
            className="mt-6 inline-block rounded-xl bg-brand px-8 py-3 font-semibold text-white hover:opacity-90"
          >
            Download APK
          </a>
        ) : (
          <p className="mt-6 rounded-xl bg-amber-50 border border-amber-200 p-4 text-sm text-amber-800">
            File APK belum tersedia saat ini. Silakan coba lagi nanti.
          </p>
        )}

        {latest?.release_notes && (
          <div className="mt-8 text-left">
            <h2 className="font-semibold">Catatan rilis</h2>
            <p className="mt-1 whitespace-pre-line text-sm text-slate-600">{latest.release_notes}</p>
          </div>
        )}
      </div>

      <div className="mt-8 bg-white rounded-2xl border border-slate-200 p-6">
        <h2 className="font-semibold">Cara instal</h2>
        <ol className="mt-2 list-decimal pl-5 space-y-1 text-sm text-slate-600">
          <li>Buka halaman ini di perangkat Android Anda dan ketuk <b>Download APK</b>.</li>
          <li>Buka file yang diunduh. Jika diminta, izinkan <b>Instal dari sumber ini</b> untuk browser Anda.</li>
          <li>Ketuk <b>Instal</b>, lalu buka aplikasi.</li>
        </ol>
        <p className="mt-4 text-xs text-slate-500">
          Dengan menggunakan aplikasi, Anda menyetujui <a className="underline" href="/privacy-policy">Kebijakan Privasi</a> kami.
        </p>
      </div>
    </div>
  );
}
