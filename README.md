# Atlas — AI Chief of Staff

Atlas monitors your messages, detects confirmed plans using the Gemini API, adds them to your calendar, and warns you before you double-book yourself. It also tracks deadlines and surfaces everything you've committed to in one place.

## Quick start

```bash
# 1. Install dependencies
npm install

# 2. Configure environment
cp .env.example .env.local
# Add your GEMINI_API_KEY to .env.local

# 3. (Optional) Seed the inbox with 20 test messages
npm run seed

# 4. Start the dev server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GEMINI_API_KEY` | Yes | Gemini API key from [Google AI Studio](https://aistudio.google.com) |
| `GOOGLE_CLIENT_ID` | No | Google OAuth client ID for Calendar sync |
| `GOOGLE_CLIENT_SECRET` | No | Google OAuth client secret |
| `GOOGLE_REDIRECT_URI` | No | OAuth redirect URI (default: `http://localhost:3000/api/auth/google/callback`) |
| `GOOGLE_REFRESH_TOKEN` | No | OAuth refresh token for Google Calendar |
| `USER_TIMEZONE` | No | IANA timezone string (default: `America/Los_Angeles`) |
| `DATABASE_URL` | No | Path to SQLite file (default: `./atlas.db`) |

The app runs fully without Google Calendar credentials — confirmed events are stored locally only.

## How it works

1. **Submit a message** in the Inbox tab (or run `npm run seed` for a batch of 20 test messages).
2. **Gemini classifies** the message and returns structured JSON: confidence score, event title, date, time, participants, and location.
3. **Confidence routing:**
   - ≥ 0.85 → auto-added to your calendar (after conflict check)
   - 0.50–0.84 → placed in the Review Queue for your approval
   - < 0.50 → ignored
4. **Conflict detection** checks every new event against existing calendar entries before committing. If there's an overlap, you see a named warning.
5. **Notifications** surface in-app as toasts and in the Alerts tab.

## Project structure

```
src/
  app/
    api/                  API routes (messages, calendar-events, pending-events, deadlines, notifications)
    page.tsx              Main UI — tabbed dashboard
    layout.tsx
    globals.css
  components/
    InboxPanel.tsx        Simulated inbox + message compose form
    CalendarPanel.tsx     Confirmed events list
    PendingReviewPanel.tsx  Medium-confidence event review cards
    DeadlinesPanel.tsx    Manual deadline CRUD
    NotificationsPanel.tsx  Notification log
    Toast.tsx             In-app toast system
  db/
    index.ts              SQLite connection + auto-migration
    schema.ts             Drizzle ORM table definitions
  lib/
    gemini.ts             Gemini API client (prompt builder, retry, validation)
    conflict.ts           Overlap detection engine
    notifications.ts      Notification creation helpers
    processor.ts          Message → event pipeline (classification + routing)
    seed.ts               Test message seed script
```

## Available scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server |
| `npm run build` | Production build |
| `npm run seed` | Seed inbox with 20 test messages |
| `npm run typecheck` | Run TypeScript type check |
| `npm run lint` | Run ESLint |

## Tech stack

- **Next.js 16** (App Router) + TypeScript
- **Tailwind CSS v4**
- **SQLite** via `better-sqlite3` with WAL mode
- **Drizzle ORM** for schema and queries
- **Gemini 1.5 Flash** via `@google/generative-ai`
- `date-fns` for date math, `uuid` for IDs, `zod` for validation

## Database

The SQLite database (`atlas.db`) is created and migrated automatically on first run. It is excluded from version control. Tables: `messages`, `extracted_events`, `calendar_events`, `pending_events`, `deadlines`, `notifications`, `contacts`, `extracted_event_participants`.
