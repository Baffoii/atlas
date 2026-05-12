import { NextRequest, NextResponse } from "next/server";
import { getDb, schema } from "@/db";
import { eq } from "drizzle-orm";

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const body = await req.json();
  const db = getDb();
  const now = new Date().toISOString();

  db.update(schema.deadlines)
    .set({ ...body, updatedAt: now })
    .where(eq(schema.deadlines.id, id))
    .run();

  return NextResponse.json({ ok: true });
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const db = getDb();
  db.update(schema.deadlines)
    .set({ completed: 1, updatedAt: new Date().toISOString() })
    .where(eq(schema.deadlines.id, id))
    .run();
  return NextResponse.json({ ok: true });
}
