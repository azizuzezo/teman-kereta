import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { CreateReleaseForm } from "./create-form";

function formatDate(value: string) {
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export default async function ReleasesPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();

  const { data: releases } = await supabase
    .from("app_releases")
    .select(
      "id, version_code, version_name, apk_url, changelog, min_supported_version_code, published_at"
    )
    .order("version_code", { ascending: false });

  return (
    <div className="flex flex-col gap-8">
      <div>
        <h1 className="text-lg font-semibold">Rilis Aplikasi</h1>
        <p className="text-sm text-black/60 dark:text-white/60">
          Kelola berkas APK yang dibagikan langsung ke pengguna (sideload,
          tanpa Play Store) dan dicek otomatis oleh aplikasi saat dibuka.
        </p>
      </div>

      <CreateReleaseForm />

      <div className="flex flex-col gap-3">
        {(releases ?? []).map((release) => (
          <div
            key={release.id}
            className="rounded-lg border border-black/10 p-4 dark:border-white/10"
          >
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="font-medium">
                  {release.version_name}{" "}
                  <span className="text-xs font-normal text-black/50 dark:text-white/50">
                    (build {release.version_code})
                  </span>
                </p>
                {release.changelog && (
                  <p className="mt-1 text-sm text-black/70 dark:text-white/70">
                    {release.changelog}
                  </p>
                )}
                <p className="mt-1 text-xs text-black/50 dark:text-white/50">
                  Dipublikasikan {formatDate(release.published_at)}
                  {release.min_supported_version_code &&
                    ` · Minimum versi didukung: build ${release.min_supported_version_code}`}
                </p>
              </div>
              <a
                href={release.apk_url}
                target="_blank"
                rel="noreferrer"
                className="shrink-0 rounded-md border border-black/15 px-3 py-1 text-xs dark:border-white/20"
              >
                Unduh APK
              </a>
            </div>
          </div>
        ))}
        {(releases ?? []).length === 0 && (
          <p className="text-sm text-black/50 dark:text-white/50">
            Belum ada rilis.
          </p>
        )}
      </div>
    </div>
  );
}
