import Link from "next/link";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { moderateComment, type ModerationStatus } from "../actions";

const FILTERS = ["all", "visible", "hidden", "removed"] as const;
type Filter = (typeof FILTERS)[number];

const MODERATION_STATUSES: ModerationStatus[] = ["visible", "hidden", "removed"];

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
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-lg font-semibold">Komentar Forum</h1>
          <p className="text-sm text-black/60 dark:text-white/60">
            Moderasi komentar pada postingan forum komunitas.
          </p>
        </div>
        <Link
          href="/forum"
          className="shrink-0 rounded-md border border-black/15 px-3 py-1.5 text-xs dark:border-white/20"
        >
          ← Kembali ke postingan
        </Link>
      </div>

      <div className="flex gap-2">
        {FILTERS.map((f) => (
          <Link
            key={f}
            href={f === "all" ? "/forum/comments" : `/forum/comments?status=${f}`}
            className={`rounded-md border px-3 py-1 text-xs ${
              filter === f
                ? "border-black bg-black text-white dark:border-white dark:bg-white dark:text-black"
                : "border-black/15 dark:border-white/20"
            }`}
          >
            {f}
          </Link>
        ))}
      </div>

      <div className="flex flex-col gap-3">
        {(comments ?? []).map((comment) => {
          const author = comment.users as unknown as
            | { display_name: string | null; email: string | null }
            | null;
          const post = comment.forum_posts as unknown as
            | { id: string; body: string }
            | null;

          return (
            <div
              key={comment.id}
              className="rounded-lg border border-black/10 p-4 dark:border-white/10"
            >
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="font-medium">
                    {author?.display_name ?? "Pengguna"}{" "}
                    <span className="text-xs font-normal text-black/50 dark:text-white/50">
                      {author?.email && `· ${author.email} `}· {comment.status}
                    </span>
                  </p>
                  <p className="mt-1 text-sm text-black/70 dark:text-white/70">
                    {comment.body}
                  </p>
                  {post && (
                    <p className="mt-1 text-xs text-black/50 dark:text-white/50">
                      Pada postingan: “
                      {post.body.length > 80 ? `${post.body.slice(0, 80)}…` : post.body}
                      ”
                    </p>
                  )}
                  <p className="mt-1 text-xs text-black/50 dark:text-white/50">
                    {formatDate(comment.created_at)}
                  </p>
                </div>
                <div className="flex shrink-0 gap-2">
                  {MODERATION_STATUSES.filter((s) => s !== comment.status).map(
                    (s) => (
                      <form
                        key={s}
                        action={moderateComment.bind(null, comment.id, s)}
                      >
                        <button
                          type="submit"
                          className="rounded-md border border-black/15 px-2 py-1 text-xs dark:border-white/20"
                        >
                          {s}
                        </button>
                      </form>
                    )
                  )}
                </div>
              </div>
            </div>
          );
        })}
        {(comments ?? []).length === 0 && (
          <p className="text-sm text-black/50 dark:text-white/50">
            Tidak ada komentar.
          </p>
        )}
      </div>
    </div>
  );
}
