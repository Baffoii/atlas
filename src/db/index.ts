import Database from "better-sqlite3";
import { drizzle } from "drizzle-orm/better-sqlite3";
import * as schema from "./schema";
import path from "path";

const DB_PATH = process.env.DATABASE_URL
  ? path.resolve(process.cwd(), process.env.DATABASE_URL)
  : path.resolve(process.cwd(), "atlas.db");

let _db: ReturnType<typeof drizzle> | null = null;

export function getDb() {
  if (!_db) {
    const sqlite = new Database(DB_PATH);
    sqlite.pragma("journal_mode = WAL");
    sqlite.pragma("foreign_keys = ON");
    _db = drizzle(sqlite, { schema });
    migrate(sqlite);
  }
  return _db;
}

function migrate(sqlite: Database.Database) {
  sqlite.exec(`
    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      sender TEXT NOT NULL,
      recipient TEXT NOT NULL,
      body TEXT NOT NULL,
      source TEXT NOT NULL DEFAULT 'simulated',
      received_at TEXT NOT NULL,
      processed_at TEXT,
      status TEXT NOT NULL DEFAULT 'pending'
        CHECK(status IN ('pending','classified','classification_failed','ignored'))
    );

    CREATE TABLE IF NOT EXISTS extracted_events (
      id TEXT PRIMARY KEY,
      message_id TEXT NOT NULL REFERENCES messages(id),
      is_confirmed_plan INTEGER NOT NULL,
      confidence REAL NOT NULL,
      event_title TEXT,
      event_date TEXT,
      start_time TEXT,
      end_time TEXT,
      location TEXT,
      needs_confirmation INTEGER NOT NULL DEFAULT 0,
      reasoning_summary TEXT,
      raw_gemini_json TEXT NOT NULL,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS contacts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT,
      phone TEXT,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS extracted_event_participants (
      event_id TEXT NOT NULL REFERENCES extracted_events(id),
      contact_id TEXT NOT NULL REFERENCES contacts(id),
      name_raw TEXT,
      PRIMARY KEY (event_id, contact_id)
    );

    CREATE TABLE IF NOT EXISTS calendar_events (
      id TEXT PRIMARY KEY,
      extracted_event_id TEXT REFERENCES extracted_events(id),
      title TEXT NOT NULL,
      date TEXT NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL,
      location TEXT,
      google_event_id TEXT,
      timezone TEXT NOT NULL DEFAULT 'America/Los_Angeles',
      status TEXT NOT NULL DEFAULT 'confirmed'
        CHECK(status IN ('confirmed','cancelled')),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS pending_events (
      id TEXT PRIMARY KEY,
      extracted_event_id TEXT NOT NULL REFERENCES extracted_events(id),
      title TEXT NOT NULL,
      date TEXT,
      start_time TEXT,
      end_time TEXT,
      location TEXT,
      confidence REAL NOT NULL,
      reasoning_summary TEXT,
      status TEXT NOT NULL DEFAULT 'awaiting_review'
        CHECK(status IN ('awaiting_review','approved','dismissed')),
      created_at TEXT NOT NULL,
      reviewed_at TEXT
    );

    CREATE TABLE IF NOT EXISTS deadlines (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      due_date TEXT NOT NULL,
      description TEXT,
      priority TEXT DEFAULT 'medium'
        CHECK(priority IN ('low','medium','high')),
      completed INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS notifications (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL
        CHECK(type IN ('conflict','pending_review','event_added','deadline_reminder','extraction_error')),
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      related_id TEXT,
      read INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
  `);
}

export { schema };
