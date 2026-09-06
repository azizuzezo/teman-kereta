import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Email Terkonfirmasi - Teman Kereta",
  description: "Konfirmasi email berhasil untuk akun Teman Kereta.",
};

export default function ConfirmPage() {
  return (
    <main className="min-h-screen bg-slate-50 flex items-center justify-center p-4 sm:p-6 text-slate-800">
      <div className="max-w-md w-full bg-white p-8 rounded-2xl shadow-sm border border-slate-200 text-center space-y-6">
        <div className="w-16 h-16 bg-emerald-100 text-emerald-600 rounded-full flex items-center justify-center mx-auto text-3xl">
          ✓
        </div>

        <h1 className="text-2xl font-extrabold text-slate-900">
          Email Berhasil Dikonfirmasi!
        </h1>

        <p className="text-slate-600 leading-relaxed text-sm">
          Terima kasih! Akun <strong>Teman Kereta</strong> Anda telah aktif dan siap digunakan.
        </p>

        <div className="bg-slate-50 p-4 rounded-xl text-xs text-slate-500 border border-slate-100">
          Halaman web ini adalah portal administrasi. Untuk mulai menggunakan jadwal dan panduan rute KRL, silakan buka aplikasi di ponsel Anda.
        </div>

        <div className="pt-2 space-y-3">
          <a
            href="temankereta://login-callback"
            className="block w-full py-3 px-4 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-xl text-sm transition-colors shadow-sm"
          >
            Buka Aplikasi Teman Kereta
          </a>
          
          <a
            href="/login"
            className="block w-full py-2.5 px-4 bg-transparent text-slate-600 hover:text-slate-900 font-medium text-xs transition-colors"
          >
            Masuk ke Portal Admin (Khusus Pengelola)
          </a>
        </div>
      </div>
    </main>
  );
}
