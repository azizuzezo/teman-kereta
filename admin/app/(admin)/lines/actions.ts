"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { recordAudit } from "@/lib/audit";
import { TRANSPORT_MODES } from "./constants";

export type LineFormState = { error?: string } | undefined;

const HEX_COLOR = /^#[0-9A-Fa-f]{6}$/;

function validateLineFields(formData: FormData) {
  const operatorId = String(formData.get("operator_id") ?? "");
  const code = String(formData.get("code") ?? "").trim();
  const name = String(formData.get("name") ?? "").trim();
  const transportMode = String(formData.get("transport_mode") ?? "");
  const color = String(formData.get("color") ?? "").trim() || null;
  const textColor = String(formData.get("text_color") ?? "").trim() || null;

  if (!operatorId) return { error: "Pilih operator." } as const;
  if (!code || code.length > 40) {
    return { error: "Kode jalur wajib diisi (maks. 40 karakter)." } as const;
  }
  if (!name || name.length > 160) {
    return { error: "Nama jalur wajib diisi (maks. 160 karakter)." } as const;
  }
  if (!TRANSPORT_MODES.includes(transportMode as (typeof TRANSPORT_MODES)[number])) {
    return { error: "Moda transportasi tidak valid." } as const;
  }
  if (color && !HEX_COLOR.test(color)) {
    return { error: "Warna harus format #RRGGBB." } as const;
  }
  if (textColor && !HEX_COLOR.test(textColor)) {
    return { error: "Warna teks harus format #RRGGBB." } as const;
  }

  return {
    fields: {
      operator_id: operatorId,
      code,
      name,
      transport_mode: transportMode,
      color,
      text_color: textColor,
    },
  } as const;
}

export async function createLine(
  _prevState: LineFormState,
  formData: FormData
): Promise<LineFormState> {
  const session = await verifyAdminSession();

  const validated = validateLineFields(formData);
  if ("error" in validated) {
    return validated;
  }

  const supabase = createServiceClient();
  const { data, error } = await supabase
    .from("lines")
    .insert(validated.fields)
    .select("id")
    .single();

  if (error) {
    return { error: `Gagal menyimpan: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "create",
    tableName: "lines",
    recordId: data.id,
    changes: validated.fields,
  });

  revalidatePath("/lines");
}

export async function updateLine(
  _prevState: LineFormState,
  formData: FormData
): Promise<LineFormState> {
  const session = await verifyAdminSession();
  const id = String(formData.get("id") ?? "");
  if (!id) {
    return { error: "ID jalur tidak ditemukan." };
  }

  const validated = validateLineFields(formData);
  if ("error" in validated) {
    return validated;
  }

  const supabase = createServiceClient();
  const { error } = await supabase
    .from("lines")
    .update(validated.fields)
    .eq("id", id);

  if (error) {
    return { error: `Gagal menyimpan: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "update",
    tableName: "lines",
    recordId: id,
    changes: validated.fields,
  });

  revalidatePath("/lines");
  redirect("/lines");
}

export type DeleteLineState = { error?: string } | undefined;

export async function deleteLine(
  _prevState: DeleteLineState,
  formData: FormData
): Promise<DeleteLineState> {
  const session = await verifyAdminSession();
  const id = String(formData.get("id"));

  const supabase = createServiceClient();

  // Check first so the message can say exactly how many trips are blocking,
  // not just that "some trips exist somewhere" — the previous version made
  // the admin guess which schedule data to go clean up first.
  const { count: tripCount } = await supabase
    .from("trips")
    .select("id", { count: "exact", head: true })
    .eq("line_id", id);
  if (tripCount && tripCount > 0) {
    return {
      error: `Jalur ini masih memiliki ${tripCount} trip/jadwal terkait — hapus trip tersebut dulu (misalnya lewat impor ulang GTFS dengan cakupan yang lebih kecil, atau hapus manual) sebelum menghapus jalur.`,
    };
  }

  const { error } = await supabase.from("lines").delete().eq("id", id);

  if (error) {
    if (error.code === "23503") {
      return {
        error:
          "Jalur ini masih memiliki data terkait yang tidak terdeteksi otomatis — periksa trip/data lain yang mereferensikan jalur ini.",
      };
    }
    return { error: `Gagal menghapus: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "delete",
    tableName: "lines",
    recordId: id,
  });

  revalidatePath("/lines");
}
