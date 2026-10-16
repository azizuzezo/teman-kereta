import type { Metadata } from "next";
import { Badge, StatusBadge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";
import { PageHeader } from "@/components/ui/page-header";
import { FilterTabs, RecordCard, RecordList } from "@/components/ui/record-card";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { moderatePost } from "./actions";
import { ModerationButtons, STATUS_LABELS } from "./moderation-buttons";

export const metadata: Metadata = { title: "Forum" };

const FILTERS = ["all", "visible", "hidden", "removed"] as const;
type Filter = (typeof FILTERS)[number];

function formatDate(value: string) {
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export default async function ForumPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  await verifyAdminSession();
  const { status } = await searchParams;
  const filter: Filter = (FILTERS as readonly string[]).includes(status ?? "")
    ? (status as Filter)
    : "all";

  const supabase = createServiceClient();
  let query = supabase
    .from("forum_posts")
    .select(
      "id, body, image_url, like_count, comment_count, status, created_at, users(display_name, email)"
    )
    .order("created_at", { ascending: false })
    .limit(100);

  if (filter !== "all") {
    query = query.eq("status", filter);
  }

  const { data: posts } = await query;

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Forum"
        description="Moderasi postingan forum komunitas. Menampilkan 100 postingan terbaru."
        actions={
          <>
            <ButtonLink href="/forum/reports">Laporan forum</ButtonLink>
            <ButtonLink href="/forum/comments">Lihat komentar</ButtonLink>
          </>
        }
      />

      <FilterTabs
        label="Filter status postingan"
        items={FILTERS.map((f) => ({
          href: f === "all" ? "/forum" : `/forum?status=${f}`,
          label: STATUS_LABELS[f],
          active: filter === f,
        }))}
      />

      <RecordList
        isEmpty={(posts ?? []).length === 0}
        empty={{
          title: "Tidak ada postingan",
          description:
            filter === "all"
              ? "Postingan dari pengguna akan muncul di sini."
              : "Tidak ada postingan dengan status ini.",
        }}
      >
        {(posts ?? []).map((post) => {
          const author = post.users as unknown as
            | { display_name: string | null; email: string | null }
            | null;
          const truncatedBody =
            post.body.length > 240 ? `${post.body.slice(0, 240)}…` : post.body;

          return (
            <RecordCard
              key={post.id}
              title={author?.display_name ?? "Pengguna"}
              badges={
                <>
                  <StatusBadge status={post.status} />
                  {post.image_url && <Badge tone="neutral">Ada gambar</Badge>}
                </>
              }
              meta={`${author?.email ? `${author.email} · ` : ""}${formatDate(
                post.created_at
              )} · ${post.like_count} suka · ${post.comment_count} komentar`}
              actions={
                <ModerationButtons
                  current={post.status}
                  noun="postingan"
                  bindAction={(next) => moderatePost.bind(null, post.id, next)}
                />
              }
            >
              <p className="whitespace-pre-wrap text-ink-muted">
                {truncatedBody}
              </p>
            </RecordCard>
          );
        })}
      </RecordList>
    </div>
  );
}
