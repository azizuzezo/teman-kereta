import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Kebijakan Privasi - Teman Kereta",
  description: "Kebijakan Privasi resmi untuk aplikasi Teman Kereta.",
};

export default function PrivacyPage() {
  return (
    <main className="min-h-screen bg-slate-50 py-12 px-4 sm:px-6 lg:px-8 text-slate-800">
      <div className="max-w-4xl mx-auto bg-white p-8 sm:p-12 rounded-2xl shadow-sm border border-slate-200">
        <div className="border-b border-slate-100 pb-6 mb-8">
          <h1 className="text-3xl font-extrabold text-slate-900">
            Kebijakan Privasi Teman Kereta
          </h1>
          <p className="text-sm text-slate-500 mt-2">
            Terakhir diperbarui: 6 Agustus 2026
          </p>
        </div>

        <section className="space-y-6 text-slate-700 leading-relaxed">
          <p>
            Selamat datang di <strong>Teman Kereta</strong>. Privasi Anda sangat penting bagi kami. Dokumen Kebijakan Privasi ini menjelaskan jenis informasi yang dikumpulkan, bagaimana informasi tersebut digunakan, serta hak-hak Anda sebagai pengguna layanan kami.
          </p>

          <h2 className="text-xl font-bold text-slate-900 pt-4">
            1. Informasi yang Kami Kumpulkan
          </h2>
          <ul className="list-disc pl-6 space-y-2">
            <li>
              <strong>Data Lokasi (GPS):</strong> Digunakan untuk memberikan informasi stasiun terdekat, petunjuk arah perjalanan, serta deteksi otomatis perjalanan KRL secara langsung di perangkat Anda. Data lokasi intensif hanya diproses saat perjalanan aktif berlangsung.
            </li>
            <li>
              <strong>Data Akun (Opsional):</strong> Jika Anda mendaftar akun, kami menyimpan alamat email dan nama tampilan untuk keperluan otentikasi serta sinkronisasi preferensi.
            </li>
            <li>
              <strong>Notifikasi & Perangkat:</strong> Izin notifikasi perangkat digunakan untuk menjadwalkan peringatan stasiun tujuan dan pemberitahuan jadwal.
            </li>
          </ul>

          <h2 className="text-xl font-bold text-slate-900 pt-4">
            2. Penggunaan Informasi
          </h2>
          <p>
            Informasi yang dikumpulkan digunakan semata-mata untuk:
          </p>
          <ul className="list-disc pl-6 space-y-2">
            <li>Menyediakan layanan informasi jadwal dan posisi kereta yang akurat.</li>
            <li>Memberikan notifikasi pengingat sebelum Anda tiba di stasiun tujuan.</li>
            <li>Meningkatkan kualitas dan keandalan aplikasi Teman Kereta.</li>
          </ul>

          <h2 className="text-xl font-bold text-slate-900 pt-4">
            3. Keamanan & Penyimpanan Data
          </h2>
          <p>
            Sebagian besar data pengguna (seperti favorit, riwayat lokal, dan preferensi tampilan) disimpan secara aman di dalam penyimpanan perangkat Anda sendiri. Data akun dan otentikasi diproses melalui infrastruktur cloud yang terenkripsi secara aman.
          </p>

          <h2 className="text-xl font-bold text-slate-900 pt-4">
            4. Hak dan Kontrol Pengguna
          </h2>
          <p>
            Anda memiliki kontrol penuh atas izin lokasi dan notifikasi melalui Pengaturan perangkat Android/iOS Anda kapan saja. Anda juga dapat memperbarui nama profil atau menghapus akun melalui aplikasi.
          </p>

          <h2 className="text-xl font-bold text-slate-900 pt-4">
            5. Hubungi Kami
          </h2>
          <p>
            Jika Anda memiliki pertanyaan atau kendala terkait Kebijakan Privasi ini, silakan hubungi tim kami melalui email di:{" "}
            <a
              href="mailto:bantuan@temankereta.id"
              className="text-blue-600 font-medium hover:underline"
            >
              bantuan@temankereta.id
            </a>
          </p>
        </section>

        <div className="mt-12 pt-6 border-t border-slate-100 text-center text-sm text-slate-500">
          © 2026 Teman Kereta. All rights reserved.
        </div>
      </div>
    </main>
  );
}
