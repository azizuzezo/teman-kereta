"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { recordAudit } from "@/lib/audit";

export type NearbyPlaceFormState = { error?: string } | undefined;

function validateNearbyPlaceFields(formData: FormData) {
  const stationId = String(formData.get("station_id") ?? "");
  const name = String(formData.get("name") ?? "").trim();
  const category = String(formData.get("category") ?? "").trim();
  const latitude = Number(formData.get("latitude"));
  const longitude = Number(formData.get("longitude"));
  const distanceRaw = String(formData.get("distance_meters") ?? "").trim();
  const walkingRaw = String(
    formData.get("walking_duration_minutes") ?? ""
  ).trim();
  const address = String(formData.get("address") ?? "").trim() || null;
  const description =
    String(formData.get("description") ?? "").trim() || null;

  if (!stationId) return { error: "Pilih stasiun." } as const;
  if (!name || name.length > 180) {
    return { error: "Nama tempat wajib diisi (maks. 180 karakter)." } as const;
  }
  if (!category || category.length > 80) {
    return { error: "Kategori wajib diisi (maks. 80 karakter)." } as const;
  }
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    return { error: "Latitude harus angka antara -90 dan 90." } as const;
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    return { error: "Longitude harus angka antara -180 dan 180." } as const;
  }

  let distanceMeters: number | null = null;
  if (distanceRaw) {
    distanceMeters = Number(distanceRaw);
    if (!Number.isFinite(distanceMeters) || distanceMeters < 0) {
      return { error: "Jarak (meter) harus angka >= 0." } as const;
    }
  }

  let walkingMinutes: number | null = null;
  if (walkingRaw) {
    walkingMinutes = Number(walkingRaw);
    if (!Number.isFinite(walkingMinutes) || walkingMinutes < 0) {
      return { error: "Durasi jalan kaki (menit) harus angka >= 0." } as const;
    }
  }

  return {
    fields: {
      station_id: stationId,
      name,
      category,
      latitude,
      longitude,
      distance_meters: distanceMeters,
      walking_duration_minutes: walkingMinutes,
      address,
      description,
    },
  } as const;
}

export async function createNearbyPlace(
  _prevState: NearbyPlaceFormState,
  formData: FormData
): Promise<NearbyPlaceFormState> {
  const session = await verifyAdminSession();

  const validated = validateNearbyPlaceFields(formData);
  if ("error" in validated) {
    return validated;
  }

  const supabase = createServiceClient();
  const { data, error } = await supabase
    .from("nearby_places")
    .insert({ ...validated.fields, source: "admin_panel" })
    .select("id")
    .single();

  if (error) {
    return { error: `Gagal menyimpan: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "create",
    tableName: "nearby_places",
    recordId: data.id,
    changes: validated.fields,
  });

  revalidatePath("/nearby-places");
}

export async function updateNearbyPlace(
  _prevState: NearbyPlaceFormState,
  formData: FormData
): Promise<NearbyPlaceFormState> {
  const session = await verifyAdminSession();
  const id = String(formData.get("id") ?? "");
  if (!id) {
    return { error: "ID tempat tidak ditemukan." };
  }

  const validated = validateNearbyPlaceFields(formData);
  if ("error" in validated) {
    return validated;
  }

  const supabase = createServiceClient();
  const { error } = await supabase
    .from("nearby_places")
    .update(validated.fields)
    .eq("id", id);

  if (error) {
    return { error: `Gagal menyimpan: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "update",
    tableName: "nearby_places",
    recordId: id,
    changes: validated.fields,
  });

  revalidatePath("/nearby-places");
  redirect("/nearby-places");
}

export async function deleteNearbyPlace(formData: FormData) {
  const session = await verifyAdminSession();
  const id = String(formData.get("id"));

  const supabase = createServiceClient();
  const { error } = await supabase.from("nearby_places").delete().eq("id", id);

  if (!error) {
    await recordAudit({
      adminUserId: session.userId,
      action: "delete",
      tableName: "nearby_places",
      recordId: id,
    });
  }

  revalidatePath("/nearby-places");
}
