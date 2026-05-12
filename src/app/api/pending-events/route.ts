import { NextResponse } from "next/server";
import { getDb, schema } from "@/db";
import { eq, asc } from "drizzle-orm";

export async function GET() {
  const db = getDb();
  const rows = db
    .select()
    .from(schema.pendingEvents)
    .where(eq(schema.pendingEvents.status, "awaiting_review"))
    .orderBy(asc(schema.pendingEvents.createdAt))
    .all();
  return NextResponse.json(rows);
}
