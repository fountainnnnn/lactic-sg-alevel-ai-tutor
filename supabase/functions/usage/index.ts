// GET /functions/v1/usage — the caller's daily allowance usage, as a percentage.
// Powers the in-app usage indicator. We intentionally return a PERCENTAGE (not a
// raw "X of Y messages") so the UI stays non-distracting — students see how full
// today's allowance is, not a number to grind against. Auth required.
import {
  corsHeaders, dailyTokenCap, serviceClient, subscriptionRank, userClient,
} from "../_shared/db.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return json({ error: "sign in required" }, 401);
  const { data: u } = await userClient(auth).auth.getUser();
  const userId = u?.user?.id;
  if (!userId) return json({ error: "sign in required" }, 401);

  const sb = serviceClient();
  const [{ data: lim }, rank] = await Promise.all([
    sb.rpc("usage_limits", { p_user: userId, p_device: null, p_ip: null }).single(),
    subscriptionRank(sb, userId),
  ]);

  const used = Number((lim as { day_tokens?: number } | null)?.day_tokens ?? 0);
  const cap = dailyTokenCap(rank);
  // 0–100, rounded; clamp so a slight overage from the last turn still reads 100.
  const pct = cap > 0 ? Math.min(100, Math.round((used / cap) * 100)) : 0;
  return json({ pct, rank, resets_in: "24h" });
});

const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
