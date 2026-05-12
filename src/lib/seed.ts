/**
 * Seed script — populates the simulated inbox with 20 test messages.
 * Run with: npx tsx src/lib/seed.ts
 */
import { getDb, schema } from "@/db";
import { v4 as uuid } from "uuid";

const now = new Date();
const ts = (offsetMinutes: number) =>
  new Date(now.getTime() - offsetMinutes * 60 * 1000).toISOString();

const SEED_MESSAGES = [
  // High-confidence confirmed plans
  { sender: "Alex", body: "sounds good, see you at 7", offset: 5 },
  { sender: "Jordan", body: "yes let's do lunch Friday at noon", offset: 10 },
  { sender: "Sam", body: "confirmed for tomorrow at 3pm", offset: 15 },
  { sender: "Morgan", body: "I can make dinner next Thursday at 8", offset: 20 },
  { sender: "Casey", body: "works for me! coffee at 10am Saturday", offset: 25 },
  { sender: "Riley", body: "perfect, see you at the office Tuesday at 9", offset: 30 },
  { sender: "Taylor", body: "locked in! dinner at Nobu, Friday 7:30pm", offset: 35 },

  // Medium-confidence (ambiguous)
  { sender: "Drew", body: "maybe Thursday works? let me check my calendar", offset: 40 },
  { sender: "Quinn", body: "probably free Sunday, let's tentatively say brunch", offset: 45 },
  { sender: "Blake", body: "think I can make it to the party Saturday", offset: 50 },

  // Low-confidence non-plans
  { sender: "Jamie", body: "haha that's so funny", offset: 55 },
  { sender: "Pat", body: "we should hang out sometime soon!", offset: 60 },
  { sender: "Chris", body: "thanks for letting me know", offset: 65 },
  { sender: "Avery", body: "lol same", offset: 70 },
  { sender: "Dana", body: "have you seen the new season?", offset: 75 },

  // Mixed context
  { sender: "Lee", body: "can't make it tonight, but let's reschedule to next week", offset: 80 },
  { sender: "Reese", body: "definitely! book the reservation for 6:30", offset: 85 },
  { sender: "Skyler", body: "meeting confirmed — 2pm Monday, Zoom link incoming", offset: 90 },
  { sender: "Harley", body: "yep yep, brunch Sunday 11am works great", offset: 95 },
  { sender: "Rowan", body: "Friday is great for the team standup, 10am it is", offset: 100 },
];

async function seed() {
  const db = getDb();
  let inserted = 0;
  for (const m of SEED_MESSAGES) {
    db.insert(schema.messages)
      .values({
        id: uuid(),
        sender: m.sender,
        recipient: "You",
        body: m.body,
        source: "simulated",
        receivedAt: ts(m.offset),
        status: "pending",
      })
      .run();
    inserted++;
  }
  console.log(`✓ Seeded ${inserted} messages`);
}

seed().catch(console.error);
