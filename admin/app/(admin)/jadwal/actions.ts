"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { recordAudit } from "@/lib/audit";

const SET_NAME = /^[a-z0-9][a-z0-9_-]{0,39}$/;

function back(kind: "ok" | "error", message: string): never {
  redirect(`/jadwal?${kind}=${encodeURIComponent(message)}`);
}

function readSet(formData: FormData): string {
  const value = String(formData.get("schedule_set") ?? "").trim();
  if (!SET_NAME.test(value)) back("error", "Nama set jadwal tidak valid.");
  return value;
}

/** `2026-12-01T00:00` dari kolom datetime-local, dibaca sebagai WIB (UTC+7). */
function readWib(formData: FormData): Date {
  const raw = String(formData.get("at") ?? "").trim();
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(raw)) {
    back("error", "Waktu pergantian tidak valid.");
  }
  const at = new Date(`${raw}:00+07:00`);
  if (Number.isNaN(at.getTime())) back("error", "Waktu pergantian tidak valid.");
  return at;
}

/** Berlaku seketika: pengguna langsung melihat set ini. */
export async function switchNow(formData: FormData): Promise<void> {
  const session = await verifyAdminSession();
  const scheduleSet = readSet(formData);
  const supabase = createServiceClient();

  const { error } = await supabase.rpc("switch_schedule", {
    p_set: scheduleSet,
    p_at: new Date().toISOString(),
    p_actor: session.email ?? session.userId,
  });
  if (error) back("error", error.message);

  await recordAudit({
    adminUserId: session.userId,
    action: "update",
    tableName: "schedule_control",
    recordId: null,
    changes: { source: "schedule_switch", mode: "now", scheduleSet },
  });
  revalidatePath("/jadwal");
  back("ok", `Jadwal "${scheduleSet}" sekarang aktif untuk semua pengguna.`);
}

/** Berlaku sendiri pada waktu itu (WIB), tanpa perlu ada yang menekan tombol. */
export async function scheduleSwitch(formData: FormData): Promise<void> {
  const session = await verifyAdminSession();
  const scheduleSet = readSet(formData);
  const at = readWib(formData);
  if (at.getTime() < Date.now() + 60_000) {
    back("error", "Waktu terjadwal harus di masa depan. Untuk sekarang pakai \"Aktifkan sekarang\".");
  }
  const supabase = createServiceClient();

  const { error } = await supabase.rpc("switch_schedule", {
    p_set: scheduleSet,
    p_at: at.toISOString(),
    p_actor: session.email ?? session.userId,
  });
  if (error) back("error", error.message);

  await recordAudit({
    adminUserId: session.userId,
    action: "update",
    tableName: "schedule_control",
    recordId: null,
    changes: { source: "schedule_switch", mode: "scheduled", scheduleSet, at: at.toISOString() },
  });
  revalidatePath("/jadwal");
  back(
    "ok",
    `Jadwal "${scheduleSet}" akan aktif otomatis pada ${at.toLocaleString("id-ID", {
      timeZone: "Asia/Jakarta",
      dateStyle: "long",
      timeStyle: "short",
    })} WIB.`
  );
}

export async function cancelSwitch(): Promise<void> {
  const session = await verifyAdminSession();
  const supabase = createServiceClient();

  const { error } = await supabase.rpc("cancel_scheduled_switch", {
    p_actor: session.email ?? session.userId,
  });
  if (error) back("error", error.message);

  await recordAudit({
    adminUserId: session.userId,
    action: "update",
    tableName: "schedule_control",
    recordId: null,
    changes: { source: "schedule_switch", mode: "cancel" },
  });
  revalidatePath("/jadwal");
  back("ok", "Pergantian terjadwal dibatalkan.");
}
