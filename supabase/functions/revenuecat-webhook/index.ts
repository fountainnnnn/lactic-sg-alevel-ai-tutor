// POST /functions/v1/revenuecat-webhook — RevenueCat server notifications.
//
// Updates public.subscriptions so premium is verified SERVER-SIDE. The app's
// client `premium` flag is advisory only; the chat function trusts this table.
//
// Deploy with verify_jwt = false (RevenueCat sends no Supabase JWT). Auth is a
// shared secret: set REVENUECAT_WEBHOOK_SECRET and paste the same value into the
// RevenueCat dashboard webhook's Authorization header.
import { createClient } from "jsr:@supabase/supabase-js@2";

// Map the active (stacked) entitlement set to the highest tier label.
function tierOf(ents: string[]): string | null {
  if (ents.includes("max")) return "max";
  if (ents.includes("plus")) return "plus";
  if (ents.includes("lite")) return "lite";
  return null;
}

const isUuid = (s: string) =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  // Shared-secret auth, FAIL CLOSED: reject if the secret is unset OR mismatched.
  // (Previously failed open when unset — that let anyone POST a fake purchase and
  // grant any account any tier. Never weaken this.) Set REVENUECAT_WEBHOOK_SECRET
  // here AND paste the same value into the RevenueCat dashboard webhook's
  // Authorization header.
  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (!secret || req.headers.get("Authorization") !== secret) {
    return new Response("unauthorized", { status: 401 });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response("bad json", { status: 400 });
  }

  // deno-lint-ignore no-explicit-any
  const e: any = (body as any)?.event;
  if (!e) return json({ error: "no event" }, 400);

  // app_user_id is the Supabase user id (set as appUserID at configure/login).
  // Anonymous RC ids ($RCAnonymousID:…) can't be attributed — ack and skip so
  // RevenueCat doesn't retry forever.
  const appUserId: string = e.app_user_id ?? "";
  if (!isUuid(appUserId)) return json({ ok: true, skipped: "non-uuid app_user_id" });

  const type: string = e.type ?? "";
  const ents: string[] = Array.isArray(e.entitlement_ids) ? e.entitlement_ids : [];
  const expiresAt = e.expiration_at_ms
    ? new Date(Number(e.expiration_at_ms)).toISOString()
    : null;
  // EXPIRATION/PAUSE are terminal; everything else (purchase, renewal, change,
  // uncancel, cancel-but-still-in-period) is active until expires_at passes.
  const terminal = type === "EXPIRATION" || type === "SUBSCRIPTION_PAUSED";
  const active = !terminal && (expiresAt === null || Date.parse(expiresAt) > Date.now());

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { error } = await sb.from("subscriptions").upsert({
    user_id: appUserId,
    rc_app_user_id: appUserId,
    entitlements: active ? ents : [],
    tier: active ? tierOf(ents) : null,
    product_id: e.product_id ?? null,
    store: e.store ?? null,
    expires_at: expiresAt,
    is_active: active,
    updated_at: new Date().toISOString(),
    raw: body,
  }, { onConflict: "user_id" });

  if (error) {
    console.error("subscriptions upsert failed:", error);
    return json({ error: "db" }, 500);
  }
  return json({ ok: true, active, tier: active ? tierOf(ents) : null });
});
