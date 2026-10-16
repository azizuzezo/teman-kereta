import { permanentRedirect } from "next/navigation";

// Petunjuk hapus akun sekarang dilayani situs utama. URL lama di domain panel
// tetap hidup lewat redirect 308. Rute ini tetap publik di middleware.ts.
export default function DeleteAccountPage() {
  permanentRedirect("https://temankereta.web.id/delete-account");
}
