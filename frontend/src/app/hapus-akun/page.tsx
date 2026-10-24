import type { Metadata } from 'next';
import Link from 'next/link';
import { CONTACT_EMAIL, SITE_NAME } from '@/lib/site';

export const metadata: Metadata = {
  title: 'Hapus Akun',
  description: `Cara meminta penghapusan akun dan data terkait di aplikasi ${SITE_NAME}.`,
};

const UPDATED = '24 Oktober 2026';

const MAIL_SUBJECT = `Permintaan Hapus Akun ${SITE_NAME}`;
const MAIL_BODY = [
  'Halo Tim Inovasi Online,',
  '',
  'Saya ingin menghapus akun saya beserta data terkait.',
  '',
  'Nama: ',
  'Email akun: ',
  'Nomor telepon akun: ',
  'Alasan (opsional): ',
].join('\n');
const MAIL_HREF = `mailto:${CONTACT_EMAIL}?subject=${encodeURIComponent(MAIL_SUBJECT)}&body=${encodeURIComponent(MAIL_BODY)}`;

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mt-8">
      <h2 className="text-xl font-semibold">{title}</h2>
      <div className="mt-2 space-y-3 text-slate-700 leading-relaxed">{children}</div>
    </section>
  );
}

export default function DeleteAccountPage() {
  return (
    <article className="mx-auto max-w-3xl px-4 py-12">
      <h1 className="text-3xl font-bold">Hapus Akun {SITE_NAME}</h1>
      <p className="mt-2 text-sm text-slate-500">Terakhir diperbarui: {UPDATED}</p>

      <p className="mt-6 text-slate-700 leading-relaxed">
        Halaman ini menjelaskan cara meminta penghapusan akun aplikasi <b>{SITE_NAME}</b> (dikembangkan oleh{' '}
        {SITE_NAME}, package <code>com.inovasionline.app</code>) beserta data yang terkait dengan akun tersebut.
      </p>

      <Section title="Langkah-langkah Meminta Penghapusan Akun">
        <ol className="list-decimal pl-6 space-y-2">
          <li>
            Kirim email ke <a className="underline text-brand" href={MAIL_HREF}>{CONTACT_EMAIL}</a> dari alamat email
            yang terdaftar di akun Anda, dengan subjek <b>&quot;{MAIL_SUBJECT}&quot;</b>.
          </li>
          <li>Cantumkan nama, email akun, dan nomor telepon yang terdaftar agar kami dapat menemukan akun Anda.</li>
          <li>
            Kami akan membalas untuk memverifikasi bahwa Anda pemilik akun. Jika email dikirim dari alamat yang
            berbeda, kami dapat meminta konfirmasi tambahan.
          </li>
          <li>
            Pastikan tidak ada pesanan yang masih berjalan dan saldo/dana Anda (jika ada) sudah dicairkan.
            Pesanan aktif akan diselesaikan atau dibatalkan terlebih dahulu.
          </li>
          <li>
            Setelah terverifikasi, akun Anda dihapus paling lambat <b>30 hari</b> dan kami mengirim email
            konfirmasi. Penghapusan bersifat permanen dan tidak dapat dibatalkan.
          </li>
        </ol>
        <a
          href={MAIL_HREF}
          className="inline-block mt-2 rounded-lg bg-brand px-5 py-2.5 font-semibold text-white hover:opacity-90"
        >
          Kirim Permintaan Hapus Akun
        </a>
      </Section>

      <Section title="Data yang Dihapus">
        <ul className="list-disc pl-6 space-y-1">
          <li>Informasi akun: nama, email, nomor telepon, kata sandi, dan foto profil.</li>
          <li>Alamat pengiriman yang tersimpan dan isi keranjang belanja.</li>
          <li>Data verifikasi identitas dan data wajah (jika pernah Anda daftarkan).</li>
          <li>Postingan, komentar, dan suka yang Anda buat, serta foto/video yang Anda unggah.</li>
          <li>Riwayat chat dengan penjual, driver, atau layanan pelanggan.</li>
          <li>Token notifikasi perangkat, riwayat pencarian, dan sesi login (termasuk tautan login Google).</li>
          <li>Profil toko, driver, atau fotografer yang terhubung dengan akun Anda.</li>
        </ul>
      </Section>

      <Section title="Data yang Disimpan dan Periode Retensi">
        <ul className="list-disc pl-6 space-y-1">
          <li>
            <b>Catatan transaksi dan pesanan</b> (nomor pesanan, nilai, tanggal, barang): disimpan hingga{' '}
            <b>10 tahun</b> untuk memenuhi kewajiban perpajakan dan akuntansi, dalam bentuk yang tidak lagi
            dikaitkan dengan nama, email, atau nomor telepon Anda.
          </li>
          <li>
            <b>Data terkait sengketa, penipuan, atau permintaan hukum</b>: disimpan selama diperlukan hingga
            perkara selesai atau sesuai ketentuan hukum yang berlaku.
          </li>
          <li>
            <b>Salinan cadangan (backup) server</b>: data yang telah dihapus akan hilang dari backup paling
            lambat <b>90 hari</b> setelah penghapusan.
          </li>
        </ul>
        <p>Selain hal di atas, kami tidak menyimpan data pribadi Anda setelah akun dihapus.</p>
      </Section>

      <Section title="Hanya Ingin Menghapus Sebagian Data?">
        <p>
          Anda juga dapat meminta penghapusan data tertentu (misalnya data wajah, postingan, atau foto) tanpa
          menghapus akun dengan mengirim email ke{' '}
          <a className="underline text-brand" href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> dan
          menyebutkan data yang ingin dihapus.
        </p>
      </Section>

      <Section title="Hubungi Kami">
        <p>
          Pertanyaan tentang penghapusan akun dapat dikirim ke{' '}
          <a className="underline text-brand" href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>. Lihat juga{' '}
          <Link className="underline text-brand" href="/privacy-policy">Kebijakan Privasi</Link> kami.
        </p>
      </Section>
    </article>
  );
}
