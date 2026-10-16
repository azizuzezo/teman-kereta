import { permanentRedirect } from "next/navigation";

// Kebijakan privasi sekarang dilayani situs utama. URL lama di domain panel
// tetap hidup lewat redirect 308. Rute ini tetap publik di middleware.ts.
export default function PrivacyPage() {
  permanentRedirect("https://temankereta.web.id/privacy");
}
