// Pure request-validation guards shared across Edge Functions. No I/O, so these
// are unit-testable without a live backend (see ../tests/guards_test.ts).

// Hard cap on a user-supplied chat message. ~12k chars ≈ a few thousand tokens —
// generous for a pasted question, but blocks a multi-MB prompt that would burn
// embedding + generation tokens before any rate limit applies.
export const MAX_MESSAGE_CHARS = 12000;

/** True when a user-supplied message is missing, empty, or over the length cap. */
export function invalidMessage(m: unknown): boolean {
  return typeof m !== "string" || m.trim().length === 0 || m.length > MAX_MESSAGE_CHARS;
}

/** Restrict an upload path to the caller's own `{uid}/` folder. Throws on a
 * missing path, traversal (`..`), or a cross-user prefix. Shared by chat + ocr;
 * service-role storage access bypasses RLS, so this IS the access control. When
 * anon (no userId, dev only) the path is used as-is apart from the traversal check. */
export function ownedPath(path: unknown, userId: string | null): string {
  if (typeof path !== "string" || path.length === 0) throw new Error("bad path");
  if (path.includes("..")) throw new Error("bad path");
  if (userId && !path.startsWith(`${userId}/`)) throw new Error("foreign path");
  return path;
}
