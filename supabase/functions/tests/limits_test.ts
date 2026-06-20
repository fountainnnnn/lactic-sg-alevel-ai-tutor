// Unit tests for the per-tier daily TOKEN allowance. Defaults must hold when no
// *_TOKENS_PER_DAY env overrides are set. Run: `deno test supabase/functions/tests/`
import { assertEquals } from "jsr:@std/assert@1";
import { dailyTokenCap } from "../_shared/db.ts";

Deno.test("dailyTokenCap: tier defaults", () => {
  assertEquals(dailyTokenCap(0), 300000); // free
  assertEquals(dailyTokenCap(1), 490000); // lite
  assertEquals(dailyTokenCap(2), 980000); // plus = 2× lite
  assertEquals(dailyTokenCap(3), 2450000); // max  = 5× lite
});

Deno.test("dailyTokenCap: ranks above max clamp to the max allowance", () => {
  assertEquals(dailyTokenCap(99), 2450000);
});

Deno.test("dailyTokenCap: caps increase strictly with tier", () => {
  const caps = [0, 1, 2, 3].map(dailyTokenCap);
  for (let i = 1; i < caps.length; i++) {
    if (caps[i] <= caps[i - 1]) throw new Error(`tier ${i} cap not greater than ${i - 1}`);
  }
});
