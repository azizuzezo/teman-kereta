import Link from "next/link";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { OPERATOR_TYPES, DATA_SOURCE_TYPES } from "./constants";
import { CreateOperatorForm } from "./create-form";
import { toggleOperatorActive } from "./actions";
import { DeleteOperatorButton } from "./delete-button";

export default async function OperatorsPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();
  const { data: operators } = await supabase
    .from("operators")
    .select("id, name, operator_type, data_source_type, website, is_active")
    .order("name");

  return (
    <div className="flex flex-col gap-8">
      <div>
        <h1 className="text-lg font-semibold">Operator</h1>
        <p className="text-sm text-black/60 dark:text-white/60">
          Perusahaan/operator transit yang menerbitkan jalur dan jadwal.
        </p>
      </div>

      <CreateOperatorForm
        operatorTypes={OPERATOR_TYPES}
        dataSourceTypes={DATA_SOURCE_TYPES}
      />

      <div className="overflow-x-auto rounded-lg border border-black/10 dark:border-white/10">
        <table className="w-full text-sm">
          <thead className="border-b border-black/10 text-left dark:border-white/10">
            <tr>
              <th className="p-3">Nama</th>
              <th className="p-3">Jenis</th>
              <th className="p-3">Sumber data</th>
              <th className="p-3">Aktif</th>
              <th className="p-3" />
            </tr>
          </thead>
          <tbody>
            {(operators ?? []).map((operator) => (
              <tr
                key={operator.id}
                className="border-b border-black/5 last:border-0 dark:border-white/5"
              >
                <td className="p-3">{operator.name}</td>
                <td className="p-3">{operator.operator_type}</td>
                <td className="p-3">{operator.data_source_type}</td>
                <td className="p-3">
                  <form action={toggleOperatorActive}>
                    <input type="hidden" name="id" value={operator.id} />
                    <input
                      type="hidden"
                      name="is_active"
                      value={(!operator.is_active).toString()}
                    />
                    <button
                      type="submit"
                      className={
                        operator.is_active
                          ? "rounded-full bg-green-100 px-2 py-0.5 text-xs text-green-800 dark:bg-green-900/40 dark:text-green-300"
                          : "rounded-full bg-black/5 px-2 py-0.5 text-xs dark:bg-white/10"
                      }
                    >
                      {operator.is_active ? "Aktif" : "Nonaktif"}
                    </button>
                  </form>
                </td>
                <td className="p-3 text-right">
                  <div className="flex items-center justify-end gap-3">
                    <Link
                      href={`/operators/${operator.id}/edit`}
                      className="text-xs text-black/70 hover:underline dark:text-white/70"
                    >
                      Edit
                    </Link>
                    <DeleteOperatorButton operatorId={operator.id} />
                  </div>
                </td>
              </tr>
            ))}
            {(operators ?? []).length === 0 && (
              <tr>
                <td
                  colSpan={5}
                  className="p-3 text-center text-black/50 dark:text-white/50"
                >
                  Belum ada operator.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
