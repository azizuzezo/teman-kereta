import type { Metadata } from "next";
import { ButtonLink } from "@/components/ui/button";
import { LoadError } from "@/components/ui/load-error";
import { PageHeader } from "@/components/ui/page-header";
import { RecordCard, RecordList } from "@/components/ui/record-card";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { CreateReleaseForm } from "./create-form";

export const metadata: Metadata = { title: "Rilis" };

function formatDate(value: string) {
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export default async function ReleasesPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();

  const { data: releases, error } = await supabase
    .from("app_releases")
    .select(
      "id, version_code, version_name, apk_url, changelog, min_supported_version_code, published_at"
    )
    .order("version_code", { ascending: false });

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title="Rilis"
        description="Berkas APK yang dibagikan langsung ke pengguna (tanpa Play Store). Aplikasi mengeceknya otomatis saat dibuka."
      />

      <CreateReleaseForm />

      {error ? (
        <LoadError what="Daftar rilis" error={error} />
      ) : (
        <RecordList
          isEmpty={(releases ?? []).length === 0}
          empty={{
            title: "Belum ada rilis",
            description: "Unggah APK pertama lewat formulir di atas.",
          }}
        >
          {(releases ?? []).map((release) => (
            <RecordCard
              key={release.id}
              title={
                <>
                  {release.version_name}{" "}
                  <span className="tabular text-sm font-medium text-ink-muted">
                    build {release.version_code}
                  </span>
                </>
              }
              meta={`Dipublikasikan ${formatDate(release.published_at)}${
                release.min_supported_version_code
                  ? ` · Versi minimum yang didukung: build ${release.min_supported_version_code}`
                  : ""
              }`}
              actions={
                <ButtonLink
                  href={release.apk_url}
                  target="_blank"
                  rel="noreferrer"
                  size="sm"
                  aria-label={`Unduh APK ${release.version_name}`}
                >
                  Unduh APK
                </ButtonLink>
              }
            >
              {release.changelog && (
                <p className="text-ink-muted">{release.changelog}</p>
              )}
            </RecordCard>
          ))}
        </RecordList>
      )}
    </div>
  );
}
