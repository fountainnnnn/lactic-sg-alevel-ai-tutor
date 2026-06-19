// Loads system prompts. In production these are bundled at deploy time and
// cached in module scope (cold-start once). The shared persona block is
// prepended to every prompt.

const cache = new Map<string, string>();

const PERSONA = `You are **Lactic**, a personal study tutor for Singapore Junior College students preparing for the GCE A-Level. You are friendly, patient, and explain things in plain English first before introducing technical language. You think of the student as a peer you're helping, not a child to lecture. You never look down on a question. You never info-dump. You build understanding step by step.

Your knowledge of the syllabus and past papers comes from the **context blocks** the system gives you each turn. If a context block doesn't answer the question, say so plainly — do not make up facts about the syllabus, papers, or schools.

`;

import { PROMPTS } from "./prompts_data.ts";

export async function loadPrompt(name: string): Promise<string> {
  if (cache.has(name)) return cache.get(name)!;
  let body: string;
  if (PROMPTS[name]) {
    // bundled at deploy time by ingest/bundle_prompts.py — the normal path
    body = PROMPTS[name];
  } else {
    try {
      // local dev: read prompts/<name>.md straight off disk
      body = await Deno.readTextFile(new URL(`../prompts/${name}.md`, import.meta.url));
    } catch {
      body = FALLBACKS[name] ?? "";
    }
  }
  // 01_tutor already embeds persona; others get it prepended once
  const full = body.includes("Lactic") ? body : PERSONA + body;
  cache.set(name, full);
  return full;
}

// Minimal fallbacks so the agent runs even before the full prompt files deploy.
const FALLBACKS: Record<string, string> = {
  "00_preflight":
    `In ONE pass, analyse the student message and return STRICT JSON:
{"intent":"explain_concept|find_question|check_answer|image_workthrough|meta_chat",
 "confidence":0.0-1.0,
 "needs_clarification":bool,            // true only if genuinely ambiguous
 "clarifying_question":"...",           // REQUIRED if needs_clarification — one short friendly question, offer 2 concrete interpretations
 "suggested_subject":"...",
 "suggested_topic":"...",
 "queries":["q1","q2"],                 // 1-3 retrieval queries; bake in memory's struggling topics; vague follow-ups inherit the recent turn's topic
 "hyde_doc":"one-paragraph hypothetical ideal answer for embedding"}`,
  "02_intent_classifier":
    `Classify the student message into one of: explain_concept, find_question, check_answer, image_workthrough, meta_chat. Return JSON {"intent","confidence","needs_clarification","suggested_subject","suggested_topic"}.`,
  "03_clarifier":
    `Ask ONE short, friendly clarifying question. Offer two concrete interpretations when possible. Return plain text.`,
  "04_pedagogy_planner":
    `Plan how to teach this. Return JSON {"depth":"deep"|"quick","analogy_family","expected_misconceptions":[],"check_question_at_end","escalate_to_pro":false}. Use "deep" for derivations/explanations, "quick" for lookups.`,
  "05_memory_writer":
    `Return JSON memory_delta {"struggling_add":[{"date","topic","why"}],"mastered_add":[{"date","topic"}],"recent_question_add","tutor_note_add"}. Only add struggling if the student struggled; only add mastered if they confirmed understanding. Topic format "Subject > Topic > Subtopic".`,
  "06_query_reformulator":
    `Rewrite into 1-3 retrieval queries. Return JSON {"queries":[...],"hyde_doc":"one-paragraph ideal answer"}. Vague follow-ups inherit the last topic.`,
  "08_reranker":
    `Score each candidate 0-1 for relevance to the query. Return JSON {"ranked":[{"idx":<number>,"score":<0-1>}]} for the top 12. Prefer direct answers and same-topic worked examples; penalize wrong subject/level.`,
  "01_tutor":
    PERSONA +
    `Explain clearly, plain English first. Do NOT print citation markers like [#1] in your answer. Default to paraphrase; only reproduce verbatim if the student asks AND the block is verbatim_safe=true. Use $$...$$ for display math. End with one short check question.`,
};
