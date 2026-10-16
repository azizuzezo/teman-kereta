import type { Metadata } from "next";
import { Badge } from "@/components/ui/badge";
import { SubmitButton } from "@/components/ui/button";
import { CheckboxField } from "@/components/ui/fields";
import { FormCard, FormFooter } from "@/components/ui/form";
import { Notice } from "@/components/ui/notice";
import { PageHeader } from "@/components/ui/page-header";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { updateMaintenanceMode } from "./actions";
import { RemoteConfigForm } from "./remote-config-form";

export const metadata: Metadata = { title: "Pengaturan" };

export default async function SettingsPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();
  const { data: rows } = await supabase
    .from("app_config")
    .select("key, value")
    .in("key", ["maintenance_mode", "remote_config"]);

  const maintenanceMode = Boolean(
    rows?.find((r) => r.key === "maintenance_mode")?.value
  );
  const remoteConfig = rows?.find((r) => r.key === "remote_config")?.value ?? {};

  return (
    <div className="flex max-w-3xl flex-col gap-6">
      <PageHeader
        title="Pengaturan"
        description="Mode maintenance dan konfigurasi jarak jauh untuk aplikasi."
      />
      <Notice tone="warn" title="Belum terbaca oleh aplikasi mobile">
        <p>
          Aplikasi Flutter belum membaca tabel <code>app_config</code>.
          Perubahan di bawah tersimpan di database, tetapi belum berefek ke
          aplikasi sampai jalur pembacaannya dibangun di sisi Flutter.
        </p>
      </Notice>

      <FormCard
        action={updateMaintenanceMode}
        title="Mode maintenance"
        description={
          <>
            Status saat ini:{" "}
            <Badge tone={maintenanceMode ? "warn" : "ok"}>
              {maintenanceMode ? "Aktif" : "Nonaktif"}
            </Badge>
          </>
        }
      >
        <CheckboxField
          label="Aktifkan mode maintenance"
          name="maintenance_mode"
          defaultChecked={maintenanceMode}
        />
        <FormFooter>
          <SubmitButton loadingLabel="Menyimpan…">Simpan</SubmitButton>
        </FormFooter>
      </FormCard>

      <RemoteConfigForm value={remoteConfig} />
    </div>
  );
}
