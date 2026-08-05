import { notFound } from "next/navigation";
import Link from "next/link";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { EditStationForm } from "./edit-form";

export default async function EditStationPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await verifyAdminSession();
  const { id } = await params;

  const supabase = createServiceClient();
  const { data: station } = await supabase
    .from("stations")
    .select("id, code, name, latitude, longitude, wheelchair_accessible, facilities")
    .eq("id", id)
    .maybeSingle();

  if (!station) {
    notFound();
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <Link
          href="/stations"
          className="text-sm text-black/60 hover:underline dark:text-white/60"
        >
          ← Kembali ke daftar stasiun
        </Link>
        <h1 className="mt-2 text-lg font-semibold">Edit stasiun</h1>
      </div>

      <EditStationForm station={station} />
    </div>
  );
}
