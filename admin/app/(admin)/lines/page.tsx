import Link from "next/link";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { TRANSPORT_MODES } from "./constants";
import { CreateLineForm } from "./create-form";
import { deleteLine } from "./actions";

export default async function LinesPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();

  const [{ data: lines }, { data: operators }] = await Promise.all([
    supabase
      .from("lines")
      .select("id, code, name, transport_mode, color, is_active, operators(name)")
      .order("code"),
    supabase.from("operators").select("id, name").order("name"),
  ]);

  return (
    <div className="flex flex-col gap-8">
      <div>
        <h1 className="text-lg font-semibold">Jalur</h1>
        <p className="text-sm text-black/60 dark:text-white/60">
          Jalur/rute yang dioperasikan oleh setiap operator.
        </p>
      </div>

      <CreateLineForm operators={operators ?? []} transportModes={TRANSPORT_MODES} />

      <div className="overflow-x-auto rounded-lg border border-black/10 dark:border-white/10">
        <table className="w-full text-sm">
          <thead className="border-b border-black/10 text-left dark:border-white/10">
            <tr>
              <th className="p-3">Kode</th>
              <th className="p-3">Nama</th>
              <th className="p-3">Operator</th>
              <th className="p-3">Moda</th>
              <th className="p-3">Warna</th>
              <th className="p-3" />
            </tr>
          </thead>
          <tbody>
            {(lines ?? []).map((line) => (
              <tr
                key={line.id}
                className="border-b border-black/5 last:border-0 dark:border-white/5"
              >
                <td className="p-3">{line.code}</td>
                <td className="p-3">{line.name}</td>
                <td className="p-3">
                  {(line.operators as unknown as { name: string } | null)?.name ?? "—"}
                </td>
                <td className="p-3">{line.transport_mode}</td>
                <td className="p-3">
                  {line.color && (
                    <span className="inline-flex items-center gap-2">
                      <span
                        className="inline-block h-3 w-3 rounded-full border border-black/10 dark:border-white/20"
                        style={{ backgroundColor: line.color }}
                      />
                      {line.color}
                    </span>
                  )}
                </td>
                <td className="p-3 text-right">
                  <div className="flex items-center justify-end gap-3">
                    <Link
                      href={`/lines/${line.id}/edit`}
                      className="text-xs text-black/70 hover:underline dark:text-white/70"
                    >
                      Edit
                    </Link>
                    <form action={deleteLine}>
                      <input type="hidden" name="id" value={line.id} />
                      <button
                        type="submit"
                        className="text-xs text-red-600 hover:underline dark:text-red-400"
                      >
                        Hapus
                      </button>
                    </form>
                  </div>
                </td>
              </tr>
            ))}
            {(lines ?? []).length === 0 && (
              <tr>
                <td
                  colSpan={6}
                  className="p-3 text-center text-black/50 dark:text-white/50"
                >
                  Belum ada jalur.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
