import { NextResponse } from "next/server";
import { getDb, schema } from "@/db";
import { desc, eq } from "drizzle-orm";

export async function GET() {
  const db = getDb();
  const rows = db
    .select()
    .from(schema.notifications)
    .orderBy(desc(schema.notifications.createdAt))
    .limit(50)
    .all();
  return NextResponse.json(rows);
}
