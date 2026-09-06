"use server";

import { revalidatePath } from "next/cache";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { recordAudit } from "@/lib/audit";

export type ModerationStatus = "visible" | "hidden" | "removed";

const STATUSES: ModerationStatus[] = ["visible", "hidden", "removed"];

/**
 * Sets a forum post's status. Only `service_role` may write `status` on
 * `forum_posts` (the authenticated-role column grant excludes it, see
 * supabase/migrations/20260822100000_forum_follow_storage.sql), so this
 * admin-only action is the only legitimate way to moderate a post.
 */
export async function moderatePost(
  postId: string,
  status: ModerationStatus,
  // Unused: present only because .bind(null, postId, status) leaves this as
  // the form's FormData argument.
  _formData: FormData
) {
  void _formData;
  const session = await verifyAdminSession();
  if (!STATUSES.includes(status)) return;

  const supabase = createServiceClient();
  const { error } = await supabase
    .from("forum_posts")
    .update({ status })
    .eq("id", postId);

  if (!error) {
    await recordAudit({
      adminUserId: session.userId,
      action: "update",
      tableName: "forum_posts",
      recordId: postId,
      changes: { status },
    });
  }

  revalidatePath("/forum");
}

/** Same idea as moderatePost, but for `forum_comments`. */
export async function moderateComment(
  commentId: string,
  status: ModerationStatus,
  _formData: FormData
) {
  void _formData;
  const session = await verifyAdminSession();
  if (!STATUSES.includes(status)) return;

  const supabase = createServiceClient();
  const { error } = await supabase
    .from("forum_comments")
    .update({ status })
    .eq("id", commentId);

  if (!error) {
    await recordAudit({
      adminUserId: session.userId,
      action: "update",
      tableName: "forum_comments",
      recordId: commentId,
      changes: { status },
    });
  }

  // A comment's status change also moves its post's comment_count (via
  // forum_comments_bump_count trigger), so refresh both pages.
  revalidatePath("/forum/comments");
  revalidatePath("/forum");
}
