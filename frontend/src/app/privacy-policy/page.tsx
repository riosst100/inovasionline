import type { Metadata } from 'next';
import Link from 'next/link';
import { CONTACT_EMAIL, SITE_NAME } from '@/lib/site';

export const metadata: Metadata = {
  title: 'Kebijakan Privasi',
  description: `Kebijakan Privasi aplikasi ${SITE_NAME}: data yang kami kumpulkan, cara penggunaan, dan hak Anda.`,
};

const UPDATED = '16 Oktober 2026';

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mt-8">
      <h2 className="text-xl font-semibold">{title}</h2>
      <div className="mt-2 space-y-3 text-slate-700 leading-relaxed">{children}</div>
    </section>
  );
}

export default function PrivacyPolicyPage() {
  return (
    <article className="mx-auto max-w-3xl px-4 py-12">
      <h1 className="text-3xl font-bold">Kebijakan Privasi</h1>
      <p className="mt-2 text-sm text-slate-500">Terakhir diperbarui: {UPDATED}</p>

      <p className="mt-6 text-slate-700 leading-relaxed">
        Kebijakan Privasi ini menjelaskan bagaimana aplikasi {SITE_NAME} (&quot;Aplikasi&quot;, &quot;kami&quot;)
        mengumpulkan, menggunakan, membagikan, dan melindungi data Anda saat menggunakan Aplikasi Android
        dan layanan terkait (package <code>com.inovasionline.app</code>). Dengan menggunakan Aplikasi, Anda
        menyetujui praktik yang dijelaskan di sini.
      </p>

      <Section title="1. Data yang Kami Kumpulkan">
        <p><b>Data yang Anda berikan:</b></p>
        <ul className="list-disc pl-6 space-y-1">
          <li>Informasi akun: nama, alamat email, nomor telepon, kata sandi (disimpan dalam bentuk ter-hash), dan foto profil.</li>
          <li>Alamat pengiriman dan catatan pesanan.</li>
          <li>Konten yang Anda unggah, seperti foto dan video (misalnya foto produk atau profil).</li>
          <li>Riwayat pesanan, transaksi, dan komunikasi dengan layanan pelanggan.</li>
        </ul>
        <p><b>Data yang dikumpulkan otomatis:</b></p>
        <ul className="list-disc pl-6 space-y-1">
          <li><b>Lokasi</b> (perkiraan dan presisi) untuk menentukan alamat pengiriman, menghitung ongkos kirim, dan melacak pengantaran.</li>
          <li>Informasi perangkat: model, versi sistem operasi, versi Aplikasi, dan token notifikasi (push).</li>
          <li>Data penggunaan dan log kesalahan untuk menjaga keamanan dan kualitas layanan.</li>
        </ul>
        <p><b>Login dengan Google:</b> jika Anda memilih masuk dengan Google, kami menerima nama, email, dan foto profil dari akun Google Anda.</p>
      </Section>

      <Section title="2. Izin Aplikasi">
        <ul className="list-disc pl-6 space-y-1">
          <li><b>Lokasi (ACCESS_FINE_LOCATION / ACCESS_COARSE_LOCATION):</b> menentukan alamat dan pengantaran. Dapat Anda nonaktifkan kapan saja di pengaturan perangkat.</li>
          <li><b>Notifikasi (POST_NOTIFICATIONS):</b> mengirim informasi status pesanan dan pembaruan.</li>
          <li><b>Kamera / Foto:</b> hanya diakses saat Anda memilih mengunggah gambar atau video.</li>
          <li><b>Instal paket (REQUEST_INSTALL_PACKAGES):</b> hanya untuk memasang pembaruan Aplikasi yang Anda setujui.</li>
        </ul>
      </Section>

      <Section title="3. Cara Kami Menggunakan Data">
        <ul className="list-disc pl-6 space-y-1">
          <li>Membuat dan mengelola akun Anda serta memproses pesanan dan pengantaran.</li>
          <li>Mengirim notifikasi terkait pesanan dan pembaruan layanan.</li>
          <li>Memberikan dukungan pelanggan, mencegah penipuan, dan menjaga keamanan.</li>
          <li>Meningkatkan fitur dan performa Aplikasi.</li>
          <li>Memenuhi kewajiban hukum.</li>
        </ul>
        <p>Kami tidak menjual data pribadi Anda.</p>
      </Section>

      <Section title="4. Berbagi Data">
        <p>Kami hanya membagikan data kepada pihak berikut sebatas yang diperlukan:</p>
        <ul className="list-disc pl-6 space-y-1">
          <li><b>Mitra pengantaran (driver) dan penjual:</b> nama, nomor telepon, alamat, dan lokasi pengantaran untuk memenuhi pesanan Anda.</li>
          <li><b>Penyedia layanan teknologi:</b> Google (Firebase Cloud Messaging untuk notifikasi dan Google Sign-In untuk login) serta penyedia hosting/infrastruktur server.</li>
          <li><b>Penyedia pembayaran</b> (jika tersedia) untuk memproses transaksi.</li>
          <li><b>Otoritas hukum</b> bila diwajibkan oleh peraturan perundang-undangan.</li>
        </ul>
        <p>Pihak-pihak tersebut wajib menjaga kerahasiaan data dan hanya menggunakannya sesuai tujuan layanan.</p>
      </Section>

      <Section title="5. Penyimpanan dan Keamanan">
        <p>
          Data disimpan di server kami dan dikirim melalui koneksi terenkripsi (HTTPS). Token sesi disimpan
          pada penyimpanan aman di perangkat. Kami menerapkan langkah keamanan yang wajar, namun tidak ada
          sistem yang sepenuhnya bebas risiko. Data disimpan selama akun aktif atau selama diperlukan untuk
          tujuan di atas dan kewajiban hukum.
        </p>
      </Section>

      <Section title="6. Hak Anda dan Penghapusan Data">
        <p>
          Anda berhak mengakses, memperbaiki, dan meminta penghapusan data pribadi Anda, serta menarik
          izin yang telah diberikan melalui pengaturan perangkat. Langkah meminta penghapusan akun dan data,
          beserta data yang dihapus dan disimpan, dijelaskan di halaman{' '}
          <Link className="underline text-brand" href="/hapus-akun">Hapus Akun</Link>.
        </p>
      </Section>

      <Section title="7. Anak-anak">
        <p>
          Aplikasi tidak ditujukan untuk anak di bawah 13 tahun dan kami tidak dengan sengaja mengumpulkan
          data mereka. Jika Anda mengetahui anak memberikan data kepada kami, hubungi kami agar data tersebut dihapus.
        </p>
      </Section>

      <Section title="8. Perubahan Kebijakan">
        <p>
          Kami dapat memperbarui kebijakan ini dari waktu ke waktu. Perubahan akan dipublikasikan di halaman
          ini beserta tanggal pembaruan.
        </p>
      </Section>

      <Section title="9. Hubungi Kami">
        <p>
          Pertanyaan tentang kebijakan ini dapat dikirim ke{' '}
          <a className="underline text-brand" href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>.
        </p>
      </Section>
    </article>
  );
}
