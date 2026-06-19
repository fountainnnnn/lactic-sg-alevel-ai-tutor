// POST /functions/v1/delete-account — permanently delete the caller's account
// and ALL associated data. Required by the App Store / Play Store for any app
// with accounts. Auth required (no anon — there's nothing to delete).
//
// Order: purge data the FK cascade can't reach (storage objects + usage_log,
// which has no FK to auth.users), THEN delete the auth user, which cascades
// conversations -> messages and subscriptions.
import { corsHeaders, serviceClient, userClient } from "../_shared/db.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return json({ error: "sign in required" }, 401);
  const { data: u } = await userClient(auth).auth.getUser();
  const userId = u?.user?.id;
  if (!userId) return json({ error: "sign in required" }, 401);

  const sb = serviceClient();
  try {
    // 1. uploaded images live under the user's own {uid}/ prefix (flat).
    const { data: files } = await sb.storage.from("uploads").list(userId, { limit: 1000 });
    if (files && files.length) {
      await sb.storage.from("uploads").remove(files.map((f) => `${userId}/${f.name}`));
    }
    // 2. usage_log has no FK cascade — delete the rows explicitly.
    await sb.from("usage_log").delete().eq("user_id", userId);
    // 3. delete the auth user; cascades conversations -> messages, subscriptions.
    const { error } = await sb.auth.admin.deleteUser(userId);
    if (error) throw error;
    return json({ ok: true }, 200);
  } catch (e) {
    console.error("delete-account failed:", e); // detail stays server-side
    return json({
      error: "delete_failed",
      message: "We couldn't delete your account just now. Please try again.",
    }, 500);
  }
});

const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
