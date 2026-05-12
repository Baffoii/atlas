import { NextResponse } from "next/server";
import { getDb, schema } from "@/db";
import { eq, asc } from "drizzle-orm";

export async function GET() {
  const db = getDb();
  const rows = db
    .select()
    .from(schema.calendarEvents)
    .where(eq(schema.calendarEvents.status, "confirmed"))
    .orderBy(asc(schema.calendarEvents.date), asc(schema.calendarEvents.startTime))
    .all();
  return NextResponse.json(rows);
}
