// Creates (or re-uses) a Supabase Auth user and adds it to `admin_users`, so
// there's a real account that can sign in to this admin panel. Local-dev
// convenience only — reads admin/.env.local itself (no dotenv dependency).
//
// Usage: node scripts/bootstrap-admin.mjs <email> <password> [display_name]
import { readFileSync } from "node:fs";
import { createClient } from "@supabase/supabase-js";

function loadEnvLocal() {
  const text = readFileSync(new URL("../.env.local", import.meta.url), "utf8");
  const env = {};
  for (const line of text.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    env[trimmed.slice(0, eq)] = trimmed.slice(eq + 1);
  }
  return env;
}

async function main() {
  const [email, password, displayName] = process.argv.slice(2);
  if (!email || !password) {
    console.error("Usage: node scripts/bootstrap-admin.mjs <email> <password> [display_name]");
    process.exit(1);
  }

  const env = loadEnvLocal();
  const supabase = createClient(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );

  const { data: created, error: createError } =
    await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

  let userId = created?.user?.id;

  if (createError) {
    if (!createError.message.includes("already been registered")) {
      throw createError;
    }
    const { data: list, error: listError } = await supabase.auth.admin.listUsers();
    if (listError) throw listError;
    userId = list.users.find((u) => u.email === email)?.id;
    if (!userId) throw new Error("User exists but could not be found via listUsers().");
    console.log(`User ${email} already existed — reusing it.`);
  } else {
    console.log(`Created auth user ${email}.`);
  }

  const { error: adminError } = await supabase
    .from("admin_users")
    .upsert({ user_id: userId, display_name: displayName ?? null });

  if (adminError) throw adminError;

  console.log(`${email} is now an admin_users member (user_id=${userId}).`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
