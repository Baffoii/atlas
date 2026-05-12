import { NextRequest, NextResponse } from "next/server";
import { getDb, schema } from "@/db";
import { desc } from "drizzle-orm";
import { v4 as uuid } from "uuid";
import { processMessage } from "@/lib/processor";

export async function GET() {
  const db = getDb();
  const rows = db
    .select()
    .from(schema.messages)
    .orderBy(desc(schema.messages.receivedAt))
    .all();
  return NextResponse.json(rows);
}

export async function POST(req: NextRequest) {
  const body = await req.json();
  const { sender, recipient, messageBody, source } = body;

  if (!sender || !recipient || !messageBody) {
    return NextResponse.json({ error: "sender, recipient, messageBody required" }, { status: 400 });
  }

  const db = getDb();
  const id = uuid();
  const now = new Date().toISOString();

  db.insert(schema.messages)
    .values({
      id,
      sender,
      recipient,
      body: messageBody,
      source: source ?? "simulated",
      receivedAt: now,
      status: "pending",
    })
    .run();

  // Process asynchronously — don't block the response
  processMessage(id).catch((err) =>
    console.error(`Failed to process message ${id}:`, err)
  );

  return NextResponse.json({ id, status: "pending" }, { status: 201 });
}
