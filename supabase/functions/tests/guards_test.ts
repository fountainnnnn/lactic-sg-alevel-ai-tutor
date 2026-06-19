// Unit tests for the pure request guards. Run: `deno test supabase/functions/tests/`
import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { invalidMessage, MAX_MESSAGE_CHARS, ownedPath } from "../_shared/guards.ts";

Deno.test("invalidMessage: accepts a normal message", () => {
  assertEquals(invalidMessage("Explain SHM"), false);
});

Deno.test("invalidMessage: rejects empty / whitespace / non-string", () => {
  assertEquals(invalidMessage(""), true);
  assertEquals(invalidMessage("   "), true);
  assertEquals(invalidMessage(undefined), true);
  assertEquals(invalidMessage(123), true);
});

Deno.test("invalidMessage: rejects over the length cap", () => {
  assertEquals(invalidMessage("x".repeat(MAX_MESSAGE_CHARS)), false);
  assertEquals(invalidMessage("x".repeat(MAX_MESSAGE_CHARS + 1)), true);
});

Deno.test("ownedPath: allows the caller's own folder", () => {
  assertEquals(ownedPath("user-1/note.jpg", "user-1"), "user-1/note.jpg");
});

Deno.test("ownedPath: blocks traversal", () => {
  assertThrows(() => ownedPath("user-1/../user-2/note.jpg", "user-1"), Error, "bad path");
});

Deno.test("ownedPath: blocks a foreign prefix", () => {
  assertThrows(() => ownedPath("user-2/note.jpg", "user-1"), Error, "foreign path");
});

Deno.test("ownedPath: rejects empty / non-string", () => {
  assertThrows(() => ownedPath("", "user-1"), Error, "bad path");
  assertThrows(() => ownedPath(undefined, "user-1"), Error, "bad path");
});

Deno.test("ownedPath: anon (no userId) only blocks traversal", () => {
  assertEquals(ownedPath("anything/note.jpg", null), "anything/note.jpg");
  assertThrows(() => ownedPath("../escape.jpg", null), Error, "bad path");
});
