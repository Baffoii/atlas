import { getDb, schema } from "@/db";
import { eq } from "drizzle-orm";
import { v4 as uuid } from "uuid";
import { classifyMessage } from "./gemini";
import { checkConflict } from "./conflict";
import {
  notifyEventAdded,
  notifyConflict,
  notifyPendingReview,
  notifyExtractionError,
} from "./notifications";

export async function processMessage(messageId: string) {
  const db = getDb();
  const [msg] = db
    .select()
    .from(schema.messages)
    .where(eq(schema.messages.id, messageId))
    .all();

  if (!msg) throw new Error(`Message ${messageId} not found`);

  let geminiResult: Awaited<ReturnType<typeof classifyMessage>>;
  try {
    geminiResult = await classifyMessage(
      msg.body,
      msg.sender,
      msg.recipient,
      msg.receivedAt
    );
  } catch (err) {
    db.update(schema.messages)
      .set({ status: "classification_failed", processedAt: new Date().toISOString() })
      .where(eq(schema.messages.id, messageId))
      .run();
    notifyExtractionError(msg.sender, messageId);
    throw err;
  }

  const { result, rawJson } = geminiResult;
  const now = new Date().toISOString();

  const extractedId = uuid();
  db.insert(schema.extractedEvents)
    .values({
      id: extractedId,
      messageId,
      isConfirmedPlan: result.isConfirmedPlan ? 1 : 0,
      confidence: result.confidence,
      eventTitle: result.eventTitle,
      eventDate: result.date,
      startTime: result.startTime,
      endTime: result.endTime,
      location: result.location,
      needsConfirmation: result.needsUserConfirmation ? 1 : 0,
      reasoningSummary: result.reasoningSummary,
      rawGeminiJson: rawJson,
      createdAt: now,
    })
    .run();

  // Persist participants as contacts
  for (const name of result.participants) {
    const existing = db
      .select()
      .from(schema.contacts)
      .where(eq(schema.contacts.name, name))
      .all();
    let contactId: string;
    if (existing.length > 0) {
      contactId = existing[0].id;
    } else {
      contactId = uuid();
      db.insert(schema.contacts)
        .values({ id: contactId, name, createdAt: now })
        .run();
    }
    db.insert(schema.extractedEventParticipants)
      .values({ eventId: extractedId, contactId, nameRaw: name })
      .run();
  }

  const messageStatus = result.isConfirmedPlan ? "classified" : "ignored";
  db.update(schema.messages)
    .set({ status: messageStatus, processedAt: now })
    .where(eq(schema.messages.id, messageId))
    .run();

  if (!result.isConfirmedPlan || result.confidence < 0.5) {
    return { action: "ignored", extractedId };
  }

  // High confidence — auto add
  if (result.confidence >= 0.85 && result.date && result.startTime) {
    const endTime = result.endTime ?? addOneHour(result.startTime);
    const conflicts = checkConflict(result.date, result.startTime, endTime);

    if (conflicts.hasConflict) {
      notifyConflict(
        result.eventTitle ?? "New event",
        result.startTime,
        conflicts.conflicts
      );
      // Still create a pending event so user can decide
      const pendingId = uuid();
      db.insert(schema.pendingEvents)
        .values({
          id: pendingId,
          extractedEventId: extractedId,
          title: result.eventTitle ?? "Untitled event",
          date: result.date,
          startTime: result.startTime,
          endTime,
          location: result.location,
          confidence: result.confidence,
          reasoningSummary: result.reasoningSummary,
          status: "awaiting_review",
          createdAt: now,
        })
        .run();
      notifyPendingReview(result.eventTitle ?? "Untitled event", result.date, pendingId);
      return { action: "conflict_pending", extractedId, pendingId };
    }

    const calId = uuid();
    db.insert(schema.calendarEvents)
      .values({
        id: calId,
        extractedEventId: extractedId,
        title: result.eventTitle ?? "Untitled event",
        date: result.date,
        startTime: result.startTime,
        endTime,
        location: result.location,
        timezone: process.env.USER_TIMEZONE ?? "America/Los_Angeles",
        status: "confirmed",
        createdAt: now,
        updatedAt: now,
      })
      .run();
    notifyEventAdded(
      result.eventTitle ?? "Untitled event",
      result.date,
      result.startTime,
      calId
    );
    return { action: "added", extractedId, calendarId: calId };
  }

  // Medium confidence — pending review
  const pendingId = uuid();
  const endTime = result.endTime ?? (result.startTime ? addOneHour(result.startTime) : null);
  db.insert(schema.pendingEvents)
    .values({
      id: pendingId,
      extractedEventId: extractedId,
      title: result.eventTitle ?? "Untitled event",
      date: result.date,
      startTime: result.startTime,
      endTime,
      location: result.location,
      confidence: result.confidence,
      reasoningSummary: result.reasoningSummary,
      status: "awaiting_review",
      createdAt: now,
    })
    .run();
  notifyPendingReview(result.eventTitle ?? "Untitled event", result.date, pendingId);
  return { action: "pending", extractedId, pendingId };
}

function addOneHour(time: string): string {
  const [h, m] = time.split(":").map(Number);
  const newH = (h + 1) % 24;
  return `${String(newH).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}
