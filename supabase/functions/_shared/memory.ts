// Parse and apply the on-device memory.md the app sends each turn.

export interface ParsedMemory {
  name?: string;
  subjects: string[];
  level?: string;
  prelimDate?: string;
  preferences: string[];
  struggling: string[];   // raw bullet lines
  mastered: string[];
  recentQuestions: string[];
  tutorNotes: string[];
  answerStyle?: "coach" | "direct"; // persisted answer-style preference
}

export interface MemoryDelta {
  struggling_add?: { date: string; topic: string; why: string }[];
  mastered_add?: { date: string; topic: string }[];
  recent_question_add?: string;
  tutor_note_add?: string;
}

const SECTION = /^##\s+(.+?)\s*$/;

function sectionLines(md: string): Record<string, string[]> {
  const out: Record<string, string[]> = {};
  let cur = "";
  for (const raw of md.split("\n")) {
    const m = raw.match(SECTION);
    if (m) { cur = m[1].toLowerCase(); out[cur] = []; continue; }
    if (cur && raw.trim()) out[cur].push(raw.trim());
  }
  return out;
}

// cap bullet length + strip line breaks: memory.md is user-editable text that
// gets injected into prompts, so keep each item short and single-line
const bullets = (lines: string[]) =>
  (lines ?? []).map((l) => l.replace(/^[-*]\s*/, "").replace(/\s+/g, " ").trim().slice(0, 200))
    .filter(Boolean);

export function parseMemory(md: string): ParsedMemory {
  const s = sectionLines(md || "");
  const profile = bullets(s["profile"]);
  const get = (k: string) =>
    profile.find((l) => l.toLowerCase().startsWith(k))?.split(":").slice(1).join(":").trim();
  const subjectsLine = get("subjects") ?? "";
  // memory.md is user-editable and gets injected into prompts (including the
  // preflight classifier) — strip preference lines that read as instructions
  // to the agent rather than teaching preferences. Legit prefs ("worked
  // examples first", "football analogies") never match these.
  const INJECTION = /(ignore|override|system prompt|instruction|restriction|jailbreak|unrestricted|answer (any|every|all|non-stud)|no (limits|rules))/i;
  const prefs = bullets(s["explanation preferences"]).filter((l) => !INJECTION.test(l));
  // a stored preference like "- prefers direct answers" sets the default style
  const prefText = prefs.join(" ").toLowerCase();
  const answerStyle: "coach" | "direct" | undefined =
    /\b(direct answer|just (the )?answer|don'?t guide|stop asking|no check question)/.test(prefText)
      ? "direct"
      : /\b(guide me|walk me through|coach|socratic|step by step)/.test(prefText)
      ? "coach"
      : undefined;
  return {
    name: get("name"),
    subjects: subjectsLine.split(",").map((x) => x.trim()).filter(Boolean),
    level: get("jc year") ?? get("level"),
    prelimDate: get("prelim date"),
    preferences: prefs,
    struggling: bullets(s["struggling topics"]),
    mastered: bullets(s["mastered (recent)"] ?? s["mastered"]),
    recentQuestions: bullets(s["recent questions (last 20, agent-managed)"] ?? s["recent questions"]),
    tutorNotes: bullets(s["notes from tutor"]),
    answerStyle,
  };
}

/** Compact memory into a short brief for prompt injection. Caps every list so
 * an oversized (or adversarial) memory.md can't balloon the prompt on every
 * pipeline call. */
export function memoryBrief(m: ParsedMemory): string {
  const parts: string[] = [];
  if (m.name) parts.push(`Student name: ${m.name.slice(0, 60)}`);
  if (m.subjects.length) parts.push(`Subjects: ${m.subjects.slice(0, 12).join(", ")}`);
  if (m.level) parts.push(`Level: ${m.level.slice(0, 20)}`);
  if (m.prelimDate) parts.push(`Prelim date: ${m.prelimDate.slice(0, 20)}`);
  if (m.preferences.length) parts.push(`Prefers: ${m.preferences.slice(0, 6).join("; ")}`);
  if (m.struggling.length) parts.push(`Struggling with:\n  - ${m.struggling.slice(0, 12).join("\n  - ")}`);
  if (m.mastered.length) parts.push(`Recently mastered: ${m.mastered.slice(0, 6).join("; ")}`);
  return parts.join("\n").slice(0, 2000) || "(no memory yet — new student)";
}

/** Apply a delta to raw memory.md, returning updated markdown (8KB-capped). */
export function applyDelta(md: string, delta: MemoryDelta): string {
  let out = md || "# Lactic Memory\n";
  const ensure = (h: string) => {
    if (!out.includes(`## ${h}`)) out += `\n\n## ${h}\n`;
  };
  const appendTo = (h: string, line: string) => {
    ensure(h);
    const re = new RegExp(`(## ${h}\\n)`);
    out = out.replace(re, `$1${line}\n`);
  };
  for (const s of delta.struggling_add ?? [])
    appendTo("Struggling topics", `- ${s.date}  ${s.topic} (${s.why})`);
  for (const m of delta.mastered_add ?? [])
    appendTo("Mastered (recent)", `- ${m.date}  ${m.topic}`);
  if (delta.recent_question_add)
    appendTo("Recent questions", `- ${delta.recent_question_add}`);
  if (delta.tutor_note_add)
    appendTo("Notes from tutor", `- ${delta.tutor_note_add}`);
  // 8KB cap — drop oldest "Recent questions" bullets (they sit at the bottom of
  // the section since new ones are prepended), never amputate other sections
  while (out.length > 8192) {
    const sec = out.match(/## Recent questions[^\n]*\n((?:- [^\n]*\n?)+)/);
    if (!sec) { out = out.slice(0, 8192); break; }
    const lines = sec[1].trimEnd().split("\n");
    if (lines.length <= 1) { out = out.slice(0, 8192); break; }
    out = out.replace(sec[1], lines.slice(0, -1).join("\n") + "\n");
  }
  return out;
}
