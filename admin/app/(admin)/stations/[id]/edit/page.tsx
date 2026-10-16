import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { EditStationForm } from "./edit-form";

export const metadata: Metadata = { title: "Edit stasiun" };

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
      <PageHeader
        title="Edit stasiun"
        description={station.name}
        back={{ href: "/stations", label: "Kembali ke daftar stasiun" }}
      />

      <EditStationForm station={station} />
    </div>
  );
}
