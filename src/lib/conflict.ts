import { getDb, schema } from "@/db";
import { eq, and, ne } from "drizzle-orm";
import type { CalendarEvent } from "@/db/schema";

export interface ConflictResult {
  hasConflict: boolean;
  conflicts: CalendarEvent[];
  isAllDayConflict: boolean;
}

function timeToMinutes(t: string): number {
  const [h, m] = t.split(":").map(Number);
  return h * 60 + m;
}

export function checkConflict(
  date: string,
  startTime: string,
  endTime: string,
  excludeId?: string
): ConflictResult {
  const db = getDb();
  const allEvents = db
    .select()
    .from(schema.calendarEvents)
    .where(
      and(
        eq(schema.calendarEvents.date, date),
        eq(schema.calendarEvents.status, "confirmed"),
        ...(excludeId ? [ne(schema.calendarEvents.id, excludeId)] : [])
      )
    )
    .all();

  const newStart = timeToMinutes(startTime);
  const newEnd = timeToMinutes(endTime);

  const conflicts: CalendarEvent[] = [];
  let isAllDayConflict = false;

  for (const event of allEvents) {
    const evStart = timeToMinutes(event.startTime);
    const evEnd = timeToMinutes(event.endTime);

    // All-day events (00:00–23:59) — soft warning
    if (evStart === 0 && evEnd >= 23 * 60 + 59) {
      isAllDayConflict = true;
      conflicts.push(event);
      continue;
    }

    if (newStart < evEnd && newEnd > evStart) {
      conflicts.push(event);
    }
  }

  return {
    hasConflict: conflicts.length > 0,
    conflicts,
    isAllDayConflict,
  };
}
