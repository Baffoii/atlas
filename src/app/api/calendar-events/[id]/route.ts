import { NextRequest, NextResponse } from "next/server";
import { getDb, schema } from "@/db";
import { eq } from "drizzle-orm";

export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const db = getDb();
  db.update(schema.calendarEvents)
    .set({ status: "cancelled", updatedAt: new Date().toISOString() })
    .where(eq(schema.calendarEvents.id, id))
    .run();
  return NextResponse.json({ ok: true });
}
