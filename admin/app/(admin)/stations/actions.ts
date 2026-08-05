"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { recordAudit } from "@/lib/audit";

export type StationFormState = { error?: string } | undefined;

function validateStationFields(formData: FormData) {
  const code = String(formData.get("code") ?? "").trim();
  const name = String(formData.get("name") ?? "").trim();
  const latitude = Number(formData.get("latitude"));
  const longitude = Number(formData.get("longitude"));
  const wheelchairAccessible = formData.get("wheelchair_accessible") === "on";
  const facilitiesRaw = String(formData.get("facilities") ?? "{}");

  if (!code || code.length > 40) {
    return { error: "Kode stasiun wajib diisi (maks. 40 karakter)." } as const;
  }
  if (!name || name.length > 160) {
    return { error: "Nama stasiun wajib diisi (maks. 160 karakter)." } as const;
  }
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    return { error: "Latitude harus angka antara -90 dan 90." } as const;
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    return { error: "Longitude harus angka antara -180 dan 180." } as const;
  }

  let facilities: unknown;
  try {
    facilities = JSON.parse(facilitiesRaw);
  } catch {
    return { error: "Fasilitas harus berupa JSON yang valid." } as const;
  }
  if (typeof facilities !== "object" || facilities === null || Array.isArray(facilities)) {
    return { error: "Fasilitas harus berupa objek JSON, mis. {\"toilet\": true}." } as const;
  }

  return {
    fields: {
      code,
      name,
      latitude,
      longitude,
      wheelchair_accessible: wheelchairAccessible,
      facilities,
    },
  } as const;
}

export async function createStation(
  _prevState: StationFormState,
  formData: FormData
): Promise<StationFormState> {
  const session = await verifyAdminSession();

  const validated = validateStationFields(formData);
  if ("error" in validated) {
    return validated;
  }

  const supabase = createServiceClient();
  const { data, error } = await supabase
    .from("stations")
    .insert(validated.fields)
    .select("id")
    .single();

  if (error) {
    return { error: `Gagal menyimpan: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "create",
    tableName: "stations",
    recordId: data.id,
    changes: validated.fields,
  });

  revalidatePath("/stations");
}

export async function updateStation(
  _prevState: StationFormState,
  formData: FormData
): Promise<StationFormState> {
  const session = await verifyAdminSession();
  const id = String(formData.get("id") ?? "");
  if (!id) {
    return { error: "ID stasiun tidak ditemukan." };
  }

  const validated = validateStationFields(formData);
  if ("error" in validated) {
    return validated;
  }

  const supabase = createServiceClient();
  const { error } = await supabase
    .from("stations")
    .update(validated.fields)
    .eq("id", id);

  if (error) {
    return { error: `Gagal menyimpan: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "update",
    tableName: "stations",
    recordId: id,
    changes: validated.fields,
  });

  revalidatePath("/stations");
  redirect("/stations");
}

export async function deleteStation(formData: FormData) {
  const session = await verifyAdminSession();
  const id = String(formData.get("id"));

  const supabase = createServiceClient();
  const { error } = await supabase.from("stations").delete().eq("id", id);

  if (!error) {
    await recordAudit({
      adminUserId: session.userId,
      action: "delete",
      tableName: "stations",
      recordId: id,
    });
  }

  revalidatePath("/stations");
}
