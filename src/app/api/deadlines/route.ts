import { NextRequest, NextResponse } from "next/server";
import { getDb, schema } from "@/db";
import { asc, eq } from "drizzle-orm";
import { v4 as uuid } from "uuid";

export async function GET() {
  const db = getDb();
  const rows = db
    .select()
    .from(schema.deadlines)
    .where(eq(schema.deadlines.completed, 0))
    .orderBy(asc(schema.deadlines.dueDate))
    .all();
  return NextResponse.json(rows);
}

export async function POST(req: NextRequest) {
  const body = await req.json();
  const { title, dueDate, description, priority } = body;

  if (!title || !dueDate) {
    return NextResponse.json({ error: "title and dueDate required" }, { status: 400 });
  }

  const db = getDb();
  const id = uuid();
  const now = new Date().toISOString();

  db.insert(schema.deadlines)
    .values({
      id,
      title,
      dueDate,
      description: description ?? null,
      priority: priority ?? "medium",
      completed: 0,
      createdAt: now,
      updatedAt: now,
    })
    .run();

  return NextResponse.json({ id }, { status: 201 });
}
