import type { Metadata } from "next";
import { Badge } from "@/components/ui/badge";
import { ButtonLink, SubmitButton } from "@/components/ui/button";
import { DataTable, RowActions } from "@/components/ui/data-table";
import { LoadError } from "@/components/ui/load-error";
import { PageHeader } from "@/components/ui/page-header";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { OPERATOR_TYPES, DATA_SOURCE_TYPES } from "./constants";
import { CreateOperatorForm } from "./create-form";
import { toggleOperatorActive } from "./actions";
import { DeleteOperatorButton } from "./delete-button";

export const metadata: Metadata = { title: "Operator" };

export default async function OperatorsPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();
  const { data: operators, error } = await supabase
    .from("operators")
    .select("id, name, operator_type, data_source_type, website, is_active")
    .order("name");

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title="Operator"
        description="Perusahaan transit yang menerbitkan lini dan jadwal."
      />

      <CreateOperatorForm
        operatorTypes={OPERATOR_TYPES}
        dataSourceTypes={DATA_SOURCE_TYPES}
      />

      {error ? (
        <LoadError what="Daftar operator" error={error} />
      ) : (
      <DataTable
        caption="Daftar operator"
        rows={operators ?? []}
        rowKey={(operator) => operator.id}
        emptyTitle="Belum ada operator"
        emptyDescription="Tambahkan operator lewat formulir di atas."
        columns={[
          {
            key: "name",
            header: "Nama",
            cell: (operator) => (
              <span className="font-semibold">{operator.name}</span>
            ),
          },
          { key: "type", header: "Jenis", cell: (o) => o.operator_type },
          {
            key: "source",
            header: "Sumber data",
            cell: (o) => <Badge tone="brand">{o.data_source_type}</Badge>,
          },
          {
            key: "active",
            header: "Status",
            cell: (operator) => (
              <form action={toggleOperatorActive}>
                <input type="hidden" name="id" value={operator.id} />
                <input
                  type="hidden"
                  name="is_active"
                  value={(!operator.is_active).toString()}
                />
                <SubmitButton
                  variant="ghost"
                  size="sm"
                  aria-label={
                    operator.is_active
                      ? `Nonaktifkan operator ${operator.name}`
                      : `Aktifkan operator ${operator.name}`
                  }
                  className="-mx-3"
                >
                  <Badge tone={operator.is_active ? "ok" : "neutral"}>
                    {operator.is_active ? "Aktif" : "Nonaktif"}
                  </Badge>
                </SubmitButton>
              </form>
            ),
          },
          {
            key: "actions",
            header: "Aksi",
            headerHidden: true,
            align: "right",
            cell: (operator) => (
              <RowActions>
                <ButtonLink
                  href={`/operators/${operator.id}/edit`}
                  variant="ghost"
                  size="sm"
                  aria-label={`Edit operator ${operator.name}`}
                >
                  Edit
                </ButtonLink>
                <DeleteOperatorButton
                  operatorId={operator.id}
                  name={operator.name}
                />
              </RowActions>
            ),
          },
        ]}
      />
      )}
    </div>
  );
}
