import type { Metadata } from "next";
import { Badge } from "@/components/ui/badge";
import { Card, Section } from "@/components/ui/card";
import { ConfirmButton } from "@/components/ui/confirm-button";
import { Button } from "@/components/ui/button";
import { Notice } from "@/components/ui/notice";
import { PageHeader } from "@/components/ui/page-header";
import { RecordCard, RecordList } from "@/components/ui/record-card";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { cancelSwitch, scheduleSwitch, switchNow } from "./actions";

export const metadata: Metadata = { title: "Jadwal" };

type SetRow = {
  schedule_set: string;
  trips: number;
  first_date: string | null;
  last_date: string | null;
  lines: number;
};
type LogRow = {
  at: string;
  actor: string | null;
  action: "switch" | "schedule" | "cancel";
  from_set: string | null;
  to_set: string | null;
  effective_at: string | null;
};
type Status = {
  effective_set: string;
  active_set: string;
  previous_set: string | null;
  next_set: string | null;
  switch_at: string | null;
  updated_at: string;
  updated_by: string | null;
  sets: SetRow[];
  log: LogRow[];
};

/** Hari berlaku GAPEKA 2026: tombol pintas untuk menjadwalkannya tepat tengah malam WIB. */
const GAPEKA_2026_SET = "gapeka2026";
const GAPEKA_2026_START = "2026-12-01T00:00";

function wib(value: string | null) {
  if (!value) return "-";
  return new Date(value).toLocaleString("id-ID", {
    timeZone: "Asia/Jakarta",
    dateStyle: "medium",
    timeStyle: "short",
  });
}

function dateRange(row: SetRow) {
  if (!row.first_date || !row.last_date) return "-";
  return row.first_date === row.last_date
    ? row.first_date
    : `${row.first_date} s/d ${row.last_date}`;
}

const ACTION_LABEL: Record<LogRow["action"], string> = {
  switch: "Ganti sekarang",
  schedule: "Jadwalkan",
  cancel: "Batalkan jadwal",
};

export default async function JadwalPage({
  searchParams,
}: {
  searchParams: Promise<{ ok?: string; error?: string }>;
}) {
  await verifyAdminSession();
  const { ok, error: actionError } = await searchParams;
  const supabase = createServiceClient();

  const { data, error } = await supabase.rpc("get_schedule_status");
  const status = (data ?? null) as Status | null;

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title="Jadwal"
        description="Beberapa set jadwal bisa disiapkan berdampingan; satu tombol menentukan set mana yang dilihat pengguna, tanpa build ulang aplikasi."
      />

      {ok && (
        <div role="status">
          <Notice tone="info" title="Berhasil">
            <p>{ok}</p>
          </Notice>
        </div>
      )}
      {actionError && (
        <div role="alert">
          <Notice tone="bad" title="Gagal">
            <p>{actionError}</p>
          </Notice>
        </div>
      )}

      {error || !status ? (
        <div role="alert">
          <Notice tone="warn" title="Saklar jadwal belum terpasang di database">
            <p>
              Terapkan dulu migrasi <code>20261118090000_gapeka_estimated_times</code>{" "}
              lalu <code>20261122090000_schedule_switch</code>. Sampai itu selesai,
              halaman ini tidak bisa dipakai dan jadwal berjalan seperti biasa.
            </p>
          </Notice>
        </div>
      ) : (
        <>
          <Card tone="soft">
            <div className="flex flex-col gap-3">
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-sm text-ink-muted">Dilihat pengguna sekarang:</span>
                <Badge tone="ok">{status.effective_set}</Badge>
              </div>
              {status.next_set && status.switch_at ? (
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <p className="text-sm text-ink">
                    Akan berganti ke <strong>{status.next_set}</strong> otomatis pada{" "}
                    <strong>{wib(status.switch_at)} WIB</strong>.
                  </p>
                  <ConfirmButton
                    action={cancelSwitch}
                    label="Batalkan jadwal"
                    ariaLabel="Batalkan pergantian terjadwal"
                    title="Batalkan pergantian terjadwal?"
                    description={`Jadwal tetap ${status.effective_set}. Pergantian ke ${status.next_set} tidak akan terjadi sampai dijadwalkan lagi.`}
                    confirmLabel="Ya, batalkan"
                    variant="secondary"
                    triggerVariant="secondary"
                  />
                </div>
              ) : (
                <p className="text-sm text-ink-muted">Tidak ada pergantian terjadwal.</p>
              )}
              <p className="text-xs text-ink-muted">
                Terakhir diubah {wib(status.updated_at)} WIB
                {status.updated_by ? ` oleh ${status.updated_by}` : ""}.
              </p>
            </div>
          </Card>

          <Section
            title="Set jadwal"
            description="Set muncul di sini setelah ada perjalanan yang diimpor ke dalamnya (halaman Impor GTFS, kolom Set jadwal)."
          >
            <RecordList
              isEmpty={status.sets.length === 0}
              empty={{
                title: "Belum ada perjalanan",
                description: "Impor jadwal dulu.",
              }}
            >
              {status.sets.map((set) => {
                const isEffective = set.schedule_set === status.effective_set;
                const isPending = set.schedule_set === status.next_set;
                const isGapeka = set.schedule_set === GAPEKA_2026_SET;
                return (
                  <RecordCard
                    key={set.schedule_set}
                    title={set.schedule_set}
                    badges={
                      <>
                        {isEffective && <Badge tone="ok">Aktif</Badge>}
                        {isPending && <Badge tone="warn">Terjadwal</Badge>}
                      </>
                    }
                    meta={`${set.trips.toLocaleString("id-ID")} perjalanan · ${set.lines} lini · tanggal ${dateRange(set)}`}
                    actions={
                      isEffective ? undefined : (
                        <div className="flex flex-col gap-3 md:items-end">
                          <ConfirmButton
                            action={switchNow}
                            fields={{ schedule_set: set.schedule_set }}
                            label="Aktifkan sekarang"
                            ariaLabel={`Aktifkan set ${set.schedule_set} sekarang`}
                            title={`Aktifkan "${set.schedule_set}" sekarang?`}
                            description={`Semua pengguna langsung melihat jadwal ${set.schedule_set} (${set.trips.toLocaleString("id-ID")} perjalanan). Set ${status.effective_set} disembunyikan, tidak dihapus: tombol ini bisa dibalik kapan saja.`}
                            confirmLabel="Ya, aktifkan"
                            variant="primary"
                            triggerVariant="primary"
                          />
                          {isGapeka && (
                            <ConfirmButton
                              action={scheduleSwitch}
                              fields={{ schedule_set: set.schedule_set, at: GAPEKA_2026_START }}
                              label="Jadwalkan 1 Desember 00:00 WIB"
                              ariaLabel="Jadwalkan GAPEKA 2026 untuk 1 Desember 2026 pukul 00:00 WIB"
                              title="Jadwalkan GAPEKA 2026?"
                              description={`Jadwal berganti otomatis ke ${set.schedule_set} tepat 1 Desember 2026 pukul 00:00 WIB. Sebelum itu pengguna tetap melihat ${status.effective_set}.`}
                              confirmLabel="Ya, jadwalkan"
                              variant="primary"
                              triggerVariant="secondary"
                            />
                          )}
                          <form action={scheduleSwitch} className="flex flex-wrap items-center gap-2">
                            <input type="hidden" name="schedule_set" value={set.schedule_set} />
                            <label className="sr-only" htmlFor={`at-${set.schedule_set}`}>
                              Waktu pergantian (WIB) untuk {set.schedule_set}
                            </label>
                            <input
                              id={`at-${set.schedule_set}`}
                              type="datetime-local"
                              name="at"
                              required
                              className="min-h-11 rounded-control border border-line-strong bg-surface px-3 text-sm md:min-h-9"
                            />
                            <Button type="submit" variant="secondary" size="sm">
                              Jadwalkan (WIB)
                            </Button>
                          </form>
                        </div>
                      )
                    }
                  />
                );
              })}
            </RecordList>
          </Section>

          <Notice tone="info" title="Urutan yang aman untuk GAPEKA 2026">
            <p>
              1) Import GAPEKA dengan set <code>gapeka2026</code> (jendela mulai 2026-12-01).
              2) Periksa jumlah perjalanan dan rentang tanggal di atas.
              3) Jadwalkan 1 Desember 00:00 WIB, atau aktifkan sekarang.
              4) Kalau ada masalah, aktifkan set <code>lama</code> lagi: seketika dan tanpa kehilangan data.
            </p>
            <p>
              Aplikasi menyimpan rentang jadwal sampai 1 jam, jadi sebagian pengguna baru
              melihat pergantian dalam waktu itu. Lini baru (mis. Bandara, Bandung Raya) ikut
              terlihat sejak diimpor tetapi tanpa keberangkatan sampai set aktif.
            </p>
          </Notice>

          <Section title="Riwayat pergantian">
            {status.log.length === 0 ? (
              <p className="text-sm text-ink-muted">Belum ada.</p>
            ) : (
              <ul className="flex flex-col gap-2 text-sm">
                {status.log.map((entry, index) => (
                  <li key={`${entry.at}-${index}`} className="rounded-control border border-line bg-surface px-4 py-2">
                    <span className="font-semibold">{ACTION_LABEL[entry.action]}</span>{" "}
                    {entry.from_set ?? "-"} &rarr; {entry.to_set ?? "-"}
                    {entry.effective_at ? ` (berlaku ${wib(entry.effective_at)} WIB)` : ""}
                    <span className="text-ink-muted">
                      {" "}· {wib(entry.at)} WIB{entry.actor ? ` · ${entry.actor}` : ""}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </Section>
        </>
      )}
    </div>
  );
}
