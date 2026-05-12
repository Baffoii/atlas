import { NextRequest, NextResponse } from "next/server";
import { getDb, schema } from "@/db";
import { eq } from "drizzle-orm";

export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const db = getDb();
  db.update(schema.notifications)
    .set({ read: 1 })
    .where(eq(schema.notifications.id, id))
    .run();
  return NextResponse.json({ ok: true });
}
