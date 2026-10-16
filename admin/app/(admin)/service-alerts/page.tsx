import type { Metadata } from "next";
import { Badge } from "@/components/ui/badge";
import { StatusBadge } from "@/components/ui/badge";
import { ConfirmButton } from "@/components/ui/confirm-button";
import { LoadError } from "@/components/ui/load-error";
import { PageHeader } from "@/components/ui/page-header";
import { RecordCard, RecordList } from "@/components/ui/record-card";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { CreateServiceAlertForm } from "./create-form";
import { resolveServiceAlert } from "./actions";

export const metadata: Metadata = { title: "Peringatan layanan" };

function formatDate(value: string) {
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export default async function ServiceAlertsPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();

  const [{ data: alerts, error }, { data: operators }] = await Promise.all([
    supabase
      .from("service_alerts")
      .select("id, title, description, severity, starts_at, ends_at, operators(name)")
      .order("starts_at", { ascending: false })
      .limit(50),
    supabase.from("operators").select("id, name").order("name"),
  ]);

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title="Peringatan layanan"
        description="Pengumuman gangguan atau perubahan layanan yang tampil di aplikasi."
      />

      <CreateServiceAlertForm operators={operators ?? []} />

      {error ? (
        <LoadError what="Daftar peringatan" error={error} />
      ) : (
        <RecordList
          isEmpty={(alerts ?? []).length === 0}
          empty={{
            title: "Belum ada peringatan layanan",
            description: "Peringatan yang diterbitkan akan muncul di sini.",
          }}
        >
          {(alerts ?? []).map((alert) => {
            const isActive =
              !alert.ends_at || new Date(alert.ends_at) > new Date();
            const operatorName =
              (alert.operators as unknown as { name: string } | null)?.name ??
              "-";
            return (
              <RecordCard
                key={alert.id}
                title={alert.title}
                badges={
                  <>
                    <StatusBadge status={alert.severity} />
                    <Badge tone={isActive ? "warn" : "neutral"}>
                      {isActive ? "Aktif" : "Selesai"}
                    </Badge>
                  </>
                }
                meta={`${operatorName} · Mulai ${formatDate(alert.starts_at)}${
                  alert.ends_at ? ` · Berakhir ${formatDate(alert.ends_at)}` : ""
                }`}
                actions={
                  isActive ? (
                    <ConfirmButton
                      action={resolveServiceAlert}
                      fields={{ id: alert.id }}
                      label="Tandai selesai"
                      ariaLabel={`Tandai selesai: ${alert.title}`}
                      triggerVariant="secondary"
                      variant="primary"
                      title="Tandai peringatan selesai?"
                      description="Peringatan ini berhenti tampil di aplikasi mulai sekarang."
                      confirmLabel="Ya, tandai selesai"
                    />
                  ) : undefined
                }
              >
                <p className="text-ink-muted">{alert.description}</p>
              </RecordCard>
            );
          })}
        </RecordList>
      )}
    </div>
  );
}
