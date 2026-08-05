import { LoginForm } from "./login-form";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-8 p-8">
      <div className="flex flex-col items-center gap-1 text-center">
        <h1 className="text-xl font-semibold">Teman Kereta Admin</h1>
        <p className="text-sm text-black/60 dark:text-white/60">
          Masuk dengan akun admin untuk mengelola data transit.
        </p>
      </div>
      {error === "not_admin" && (
        <p className="max-w-sm text-center text-sm text-red-600 dark:text-red-400">
          Akun ini berhasil masuk tetapi belum terdaftar sebagai admin.
          Hubungi admin lain untuk ditambahkan ke daftar akses.
        </p>
      )}
      <LoginForm />
    </main>
  );
}
