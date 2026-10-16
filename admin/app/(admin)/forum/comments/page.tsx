import type { Metadata } from "next";
import { StatusBadge } from "@/components/ui/badge";
import { PageHeader } from "@/components/ui/page-header";
import { FilterTabs, RecordCard, RecordList } from "@/components/ui/record-card";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { moderateComment } from "../actions";
import { ModerationButtons, STATUS_LABELS } from "../moderation-buttons";

export const metadata: Metadata = { title: "Komentar forum" };

const FILTERS = ["all", "visible", "hidden", "removed"] as const;
type Filter = (typeof FILTERS)[number];

function formatDate(value: string) {
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export default async function ForumCommentsPage({
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
    .from("forum_comments")
    .select(
      "id, body, status, created_at, users(display_name, email), forum_posts(id, body)"
    )
    .order("created_at", { ascending: false })
    .limit(100);

  if (filter !== "all") {
    query = query.eq("status", filter);
  }

  const { data: comments } = await query;

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Komentar forum"
        description="Moderasi komentar pada postingan forum. Menampilkan 100 komentar terbaru."
        back={{ href: "/forum", label: "Kembali ke postingan" }}
      />

      <FilterTabs
        label="Filter status komentar"
        items={FILTERS.map((f) => ({
          href: f === "all" ? "/forum/comments" : `/forum/comments?status=${f}`,
          label: STATUS_LABELS[f],
          active: filter === f,
        }))}
      />

      <RecordList
        isEmpty={(comments ?? []).length === 0}
        empty={{
          title: "Tidak ada komentar",
          description:
            filter === "all"
              ? "Komentar dari pengguna akan muncul di sini."
              : "Tidak ada komentar dengan status ini.",
        }}
      >
        {(comments ?? []).map((comment) => {
          const author = comment.users as unknown as
            | { display_name: string | null; email: string | null }
            | null;
          const post = comment.forum_posts as unknown as
            | { id: string; body: string }
            | null;

          return (
            <RecordCard
              key={comment.id}
              title={author?.display_name ?? "Pengguna"}
              badges={<StatusBadge status={comment.status} />}
              meta={`${author?.email ? `${author.email} · ` : ""}${formatDate(
                comment.created_at
              )}`}
              actions={
                <ModerationButtons
                  current={comment.status}
                  noun="komentar"
                  bindAction={(next) =>
                    moderateComment.bind(null, comment.id, next)
                  }
                />
              }
            >
              <p className="whitespace-pre-wrap text-ink-muted">
                {comment.body}
              </p>
              {post && (
                <p className="mt-2 rounded-[10px] bg-surface-alt px-3 py-2 text-xs text-ink-muted">
                  Pada postingan: &ldquo;
                  {post.body.length > 80
                    ? `${post.body.slice(0, 80)}…`
                    : post.body}
                  &rdquo;
                </p>
              )}
            </RecordCard>
          );
        })}
      </RecordList>
    </div>
  );
}
