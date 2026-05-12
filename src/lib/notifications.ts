import { getDb, schema } from "@/db";
import { v4 as uuid } from "uuid";
import type { CalendarEvent } from "@/db/schema";

export type NotificationType =
  | "conflict"
  | "pending_review"
  | "event_added"
  | "deadline_reminder"
  | "extraction_error";

export function createNotification(
  type: NotificationType,
  title: string,
  body: string,
  relatedId?: string
) {
  const db = getDb();
  const now = new Date().toISOString();
  db.insert(schema.notifications)
    .values({ id: uuid(), type, title, body, relatedId, read: 0, createdAt: now })
    .run();
}

export function notifyEventAdded(title: string, date: string, startTime: string, id: string) {
  createNotification(
    "event_added",
    "Event added",
    `Added: ${title} on ${date} at ${startTime}`,
    id
  );
}

export function notifyConflict(
  newTitle: string,
  newStart: string,
  conflicts: CalendarEvent[],
  relatedId?: string
) {
  for (const c of conflicts) {
    createNotification(
      "conflict",
      "Scheduling conflict",
      `Heads up — ${newTitle} at ${newStart} overlaps with ${c.title} from ${c.startTime}–${c.endTime}.`,
      relatedId
    );
  }
}

export function notifyPendingReview(title: string, date: string | null, id: string) {
  createNotification(
    "pending_review",
    "Review needed",
    `Atlas isn't sure about this one: "${title}"${date ? ` on ${date}` : ""}. Review it below.`,
    id
  );
}

export function notifyExtractionError(sender: string, messageId: string) {
  createNotification(
    "extraction_error",
    "Extraction failed",
    `Atlas couldn't parse a message from ${sender}. Review it manually.`,
    messageId
  );
}

export function notifyDeadlineReminder(title: string, dueDate: string, id: string, urgent: boolean) {
  createNotification(
    "deadline_reminder",
    urgent ? "Deadline today" : "Upcoming deadline",
    urgent
      ? `Deadline today: "${title}" is due at ${dueDate}.`
      : `Upcoming deadline: "${title}" is due ${dueDate}.`,
    id
  );
}
