import { notFound } from "next/navigation";
import Link from "next/link";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { TRANSPORT_MODES } from "../../constants";
import { EditLineForm } from "./edit-form";

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
      <div>
        <Link
          href="/lines"
          className="text-sm text-black/60 hover:underline dark:text-white/60"
        >
          ← Kembali ke daftar jalur
        </Link>
        <h1 className="mt-2 text-lg font-semibold">Edit jalur</h1>
      </div>

      <EditLineForm
        line={line}
        operators={operators ?? []}
        transportModes={TRANSPORT_MODES}
      />
    </div>
  );
}
