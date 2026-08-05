"use server";

import { revalidatePath } from "next/cache";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { recordAudit } from "@/lib/audit";
import { importGtfsFeed, type GtfsImportSummary } from "@/lib/gtfs/importer";

export type GtfsImportState =
  | { error: string }
  | { summary: GtfsImportSummary }
  | undefined;

const MAX_WINDOW_DAYS = 30;

export async function importGtfs(
  _prevState: GtfsImportState,
  formData: FormData
): Promise<GtfsImportState> {
  const session = await verifyAdminSession();

  const operatorId = String(formData.get("operator_id") ?? "");
  const windowDaysRaw = Number(formData.get("window_days"));
  const file = formData.get("file");

  if (!operatorId) {
    return { error: "Pilih operator untuk jalur yang akan diimpor." };
  }
  if (
    !Number.isFinite(windowDaysRaw) ||
    windowDaysRaw < 1 ||
    windowDaysRaw > MAX_WINDOW_DAYS
  ) {
    return {
      error: `Jumlah hari harus antara 1 dan ${MAX_WINDOW_DAYS}.`,
    };
  }
  if (!(file instanceof File) || file.size === 0) {
    return { error: "Pilih berkas GTFS (.zip)." };
  }

  const supabase = createServiceClient();
  const startDateIso = new Date().toISOString().slice(0, 10);

  try {
    const zipBytes = await file.arrayBuffer();
    const summary = await importGtfsFeed({
      supabase,
      operatorId,
      zipBytes,
      startDateIso,
      windowDays: windowDaysRaw,
    });

    await recordAudit({
      adminUserId: session.userId,
      action: "create",
      tableName: "trips",
      recordId: null,
      changes: {
        source: "gtfs_import",
        operatorId,
        startDateIso,
        windowDays: windowDaysRaw,
        ...summary,
      },
    });

    revalidatePath("/operators");
    revalidatePath("/lines");
    revalidatePath("/stations");
    revalidatePath("/dashboard");

    return { summary };
  } catch (error) {
    return {
      error: error instanceof Error ? error.message : "Impor GTFS gagal.",
    };
  }
}
