import { GoogleGenerativeAI } from "@google/generative-ai";
import { addHours, format, parse, parseISO } from "date-fns";

export interface GeminiExtractionResult {
  isConfirmedPlan: boolean;
  confidence: number;
  eventTitle: string | null;
  date: string | null;
  startTime: string | null;
  endTime: string | null;
  participants: string[];
  location: string | null;
  needsUserConfirmation: boolean;
  reasoningSummary: string;
}

const SYSTEM_INSTRUCTION = `You are a scheduling assistant. Your job is to read a single message and determine
whether it represents a confirmed real-world plan (meeting, meal, call, event, etc.).

Rules:
- A confirmed plan requires that the sender has agreed to something specific.
- Vague social phrases like "we should hang out sometime" are NOT confirmed plans.
- Phrases like "sounds good, see you at 7" ARE confirmed plans.
- Resolve any relative date references (tomorrow, Friday, next week) relative to the
  message timestamp provided. Return absolute ISO 8601 dates.
- If end time is not stated, leave endTime null.
- Return ONLY valid JSON matching the schema below. No markdown, no explanation text.`;

function buildPrompt(
  body: string,
  sender: string,
  recipient: string,
  timestamp: string
): string {
  return `Message timestamp: ${timestamp}
Message sender: ${sender}
Message recipient: ${recipient}
Message body:
"""
${body}
"""

Return JSON in exactly this schema:
{
  "isConfirmedPlan": boolean,
  "confidence": number (0.0 to 1.0),
  "eventTitle": string | null,
  "date": string | null,
  "startTime": string | null,
  "endTime": string | null,
  "participants": string[],
  "location": string | null,
  "needsUserConfirmation": boolean,
  "reasoningSummary": string
}`;
}

function validateAndCoerce(raw: unknown): GeminiExtractionResult {
  if (typeof raw !== "object" || raw === null) throw new Error("Not an object");
  const r = raw as Record<string, unknown>;

  const confidence = Math.min(1, Math.max(0, Number(r.confidence ?? 0)));
  let endTime = typeof r.endTime === "string" ? r.endTime : null;
  const startTime = typeof r.startTime === "string" ? r.startTime : null;

  if (!endTime && startTime) {
    try {
      const base = parse(startTime, "HH:mm", new Date());
      endTime = format(addHours(base, 1), "HH:mm");
    } catch {
      endTime = null;
    }
  }

  const timeRe = /^\d{2}:\d{2}$/;
  const dateRe = /^\d{4}-\d{2}-\d{2}$/;

  return {
    isConfirmedPlan: Boolean(r.isConfirmedPlan),
    confidence,
    eventTitle: typeof r.eventTitle === "string" ? r.eventTitle : null,
    date:
      typeof r.date === "string" && dateRe.test(r.date) ? r.date : null,
    startTime: startTime && timeRe.test(startTime) ? startTime : null,
    endTime: endTime && timeRe.test(endTime) ? endTime : null,
    participants: Array.isArray(r.participants)
      ? (r.participants as string[]).filter((p) => typeof p === "string")
      : [],
    location: typeof r.location === "string" ? r.location : null,
    needsUserConfirmation: Boolean(r.needsUserConfirmation),
    reasoningSummary:
      typeof r.reasoningSummary === "string" ? r.reasoningSummary : "",
  };
}

async function callWithRetry(
  model: ReturnType<InstanceType<typeof GoogleGenerativeAI>["getGenerativeModel"]>,
  prompt: string,
  maxRetries = 3
): Promise<string> {
  let lastError: Error | null = null;
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const result = await model.generateContent(prompt);
      return result.response.text();
    } catch (err) {
      lastError = err as Error;
      const delay = Math.pow(2, attempt) * 500;
      await new Promise((r) => setTimeout(r, delay));
    }
  }
  throw lastError ?? new Error("Gemini call failed");
}

export async function classifyMessage(
  body: string,
  sender: string,
  recipient: string,
  timestamp: string
): Promise<{ result: GeminiExtractionResult; rawJson: string }> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error("GEMINI_API_KEY not set");

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: "gemini-1.5-flash",
    systemInstruction: SYSTEM_INSTRUCTION,
  });

  const prompt = buildPrompt(body, sender, recipient, timestamp);
  const rawText = await callWithRetry(model, prompt);

  // Strip any accidental markdown fences
  const cleaned = rawText.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim();

  let parsed: unknown;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    throw new Error(`Gemini returned non-JSON: ${cleaned.slice(0, 200)}`);
  }

  const result = validateAndCoerce(parsed);
  return { result, rawJson: cleaned };
}
