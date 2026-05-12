import { sqliteTable, text, real, integer } from "drizzle-orm/sqlite-core";

export const messages = sqliteTable("messages", {
  id: text("id").primaryKey(),
  sender: text("sender").notNull(),
  recipient: text("recipient").notNull(),
  body: text("body").notNull(),
  source: text("source").notNull().default("simulated"),
  receivedAt: text("received_at").notNull(),
  processedAt: text("processed_at"),
  status: text("status").notNull().default("pending"),
});

export const extractedEvents = sqliteTable("extracted_events", {
  id: text("id").primaryKey(),
  messageId: text("message_id")
    .notNull()
    .references(() => messages.id),
  isConfirmedPlan: integer("is_confirmed_plan").notNull(),
  confidence: real("confidence").notNull(),
  eventTitle: text("event_title"),
  eventDate: text("event_date"),
  startTime: text("start_time"),
  endTime: text("end_time"),
  location: text("location"),
  needsConfirmation: integer("needs_confirmation").notNull().default(0),
  reasoningSummary: text("reasoning_summary"),
  rawGeminiJson: text("raw_gemini_json").notNull(),
  createdAt: text("created_at").notNull(),
});

export const contacts = sqliteTable("contacts", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  email: text("email"),
  phone: text("phone"),
  createdAt: text("created_at").notNull(),
});

export const extractedEventParticipants = sqliteTable(
  "extracted_event_participants",
  {
    eventId: text("event_id")
      .notNull()
      .references(() => extractedEvents.id),
    contactId: text("contact_id")
      .notNull()
      .references(() => contacts.id),
    nameRaw: text("name_raw"),
  }
);

export const calendarEvents = sqliteTable("calendar_events", {
  id: text("id").primaryKey(),
  extractedEventId: text("extracted_event_id").references(
    () => extractedEvents.id
  ),
  title: text("title").notNull(),
  date: text("date").notNull(),
  startTime: text("start_time").notNull(),
  endTime: text("end_time").notNull(),
  location: text("location"),
  googleEventId: text("google_event_id"),
  timezone: text("timezone").notNull().default("America/Los_Angeles"),
  status: text("status").notNull().default("confirmed"),
  createdAt: text("created_at").notNull(),
  updatedAt: text("updated_at").notNull(),
});

export const pendingEvents = sqliteTable("pending_events", {
  id: text("id").primaryKey(),
  extractedEventId: text("extracted_event_id")
    .notNull()
    .references(() => extractedEvents.id),
  title: text("title").notNull(),
  date: text("date"),
  startTime: text("start_time"),
  endTime: text("end_time"),
  location: text("location"),
  confidence: real("confidence").notNull(),
  reasoningSummary: text("reasoning_summary"),
  status: text("status").notNull().default("awaiting_review"),
  createdAt: text("created_at").notNull(),
  reviewedAt: text("reviewed_at"),
});

export const deadlines = sqliteTable("deadlines", {
  id: text("id").primaryKey(),
  title: text("title").notNull(),
  dueDate: text("due_date").notNull(),
  description: text("description"),
  priority: text("priority").notNull().default("medium"),
  completed: integer("completed").notNull().default(0),
  createdAt: text("created_at").notNull(),
  updatedAt: text("updated_at").notNull(),
});

export const notifications = sqliteTable("notifications", {
  id: text("id").primaryKey(),
  type: text("type").notNull(),
  title: text("title").notNull(),
  body: text("body").notNull(),
  relatedId: text("related_id"),
  read: integer("read").notNull().default(0),
  createdAt: text("created_at").notNull(),
});

export type Message = typeof messages.$inferSelect;
export type NewMessage = typeof messages.$inferInsert;
export type ExtractedEvent = typeof extractedEvents.$inferSelect;
export type CalendarEvent = typeof calendarEvents.$inferSelect;
export type PendingEvent = typeof pendingEvents.$inferSelect;
export type Deadline = typeof deadlines.$inferSelect;
export type Notification = typeof notifications.$inferSelect;
