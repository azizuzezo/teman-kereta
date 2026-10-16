import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { OPERATOR_TYPES, DATA_SOURCE_TYPES } from "../../constants";
import { EditOperatorForm } from "./edit-form";

export const metadata: Metadata = { title: "Edit operator" };

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
      <PageHeader
        title="Edit operator"
        description={operator.name}
        back={{ href: "/operators", label: "Kembali ke daftar operator" }}
      />

      <EditOperatorForm
        operator={operator}
        operatorTypes={OPERATOR_TYPES}
        dataSourceTypes={DATA_SOURCE_TYPES}
      />
    </div>
  );
}
