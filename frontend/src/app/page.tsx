import { redirect } from 'next/navigation';

// Versi web belum tersedia; sementara arahkan ke halaman download aplikasi.
export default function Home() {
  redirect('/download');
}
