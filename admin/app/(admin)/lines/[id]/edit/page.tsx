import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { TRANSPORT_MODES } from "../../constants";
import { EditLineForm } from "./edit-form";

export const metadata: Metadata = { title: "Edit lini" };

export default async function EditLinePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await verifyAdminSession();
  const { id } = await params;
  const supabase = createServiceClient();

  const [{ data: line }, { data: operators }] = await Promise.all([
    supabase
      .from("lines")
      .select("id, operator_id, code, name, transport_mode, color, text_color")
      .eq("id", id)
      .maybeSingle(),
    supabase.from("operators").select("id, name").order("name"),
  ]);

  if (!line) {
    notFound();
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Edit lini"
        description={line.name}
        back={{ href: "/lines", label: "Kembali ke daftar lini" }}
      />

      <EditLineForm
        line={line}
        operators={operators ?? []}
        transportModes={TRANSPORT_MODES}
      />
    </div>
  );
}
