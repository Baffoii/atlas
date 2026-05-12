import { NextRequest, NextResponse } from "next/server";
import { getDb, schema } from "@/db";
import { eq } from "drizzle-orm";
import { v4 as uuid } from "uuid";
import { checkConflict } from "@/lib/conflict";
import { notifyEventAdded, notifyConflict } from "@/lib/notifications";

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const { action } = await req.json();

  if (action !== "approve" && action !== "dismiss") {
    return NextResponse.json({ error: "action must be approve or dismiss" }, { status: 400 });
  }

  const db = getDb();
  const [pending] = db
    .select()
    .from(schema.pendingEvents)
    .where(eq(schema.pendingEvents.id, id))
    .all();

  if (!pending) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }

  const now = new Date().toISOString();

  if (action === "dismiss") {
    db.update(schema.pendingEvents)
      .set({ status: "dismissed", reviewedAt: now })
      .where(eq(schema.pendingEvents.id, id))
      .run();
    return NextResponse.json({ status: "dismissed" });
  }

  // approve
  if (!pending.date || !pending.startTime || !pending.endTime) {
    return NextResponse.json(
      { error: "Cannot approve event with missing date/time" },
      { status: 422 }
    );
  }

  const conflicts = checkConflict(pending.date, pending.startTime, pending.endTime);
  if (conflicts.hasConflict) {
    notifyConflict(pending.title, pending.startTime, conflicts.conflicts, id);
    return NextResponse.json({
      status: "conflict",
      conflicts: conflicts.conflicts,
      isAllDay: conflicts.isAllDayConflict,
    }, { status: 409 });
  }

  const calId = uuid();
  db.insert(schema.calendarEvents)
    .values({
      id: calId,
      extractedEventId: pending.extractedEventId,
      title: pending.title,
      date: pending.date,
      startTime: pending.startTime,
      endTime: pending.endTime,
      location: pending.location,
      timezone: process.env.USER_TIMEZONE ?? "America/Los_Angeles",
      status: "confirmed",
      createdAt: now,
      updatedAt: now,
    })
    .run();

  db.update(schema.pendingEvents)
    .set({ status: "approved", reviewedAt: now })
    .where(eq(schema.pendingEvents.id, id))
    .run();

  notifyEventAdded(pending.title, pending.date, pending.startTime!, calId);

  return NextResponse.json({ status: "approved", calendarEventId: calId });
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const db = getDb();
  const now = new Date().toISOString();
  db.update(schema.pendingEvents)
    .set({ status: "dismissed", reviewedAt: now })
    .where(eq(schema.pendingEvents.id, id))
    .run();
  return NextResponse.json({ status: "dismissed" });
}
