import { notFound } from "next/navigation";
import Link from "next/link";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { OPERATOR_TYPES, DATA_SOURCE_TYPES } from "../../constants";
import { EditOperatorForm } from "./edit-form";

export default async function EditOperatorPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await verifyAdminSession();
  const { id } = await params;

  const supabase = createServiceClient();
  const { data: operator } = await supabase
    .from("operators")
    .select("id, name, operator_type, data_source_type, website")
    .eq("id", id)
    .maybeSingle();

  if (!operator) {
    notFound();
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <Link
          href="/operators"
          className="text-sm text-black/60 hover:underline dark:text-white/60"
        >
          ← Kembali ke daftar operator
        </Link>
        <h1 className="mt-2 text-lg font-semibold">Edit operator</h1>
      </div>

      <EditOperatorForm
        operator={operator}
        operatorTypes={OPERATOR_TYPES}
        dataSourceTypes={DATA_SOURCE_TYPES}
      />
    </div>
  );
}
