# Atlas — Technical Requirements Document (TRD)

**Version:** 1.0  
**Status:** Draft — Pending Review  
**Last Updated:** 2026-05-11

---

## Table of Contents

1. [Product Overview](#1-product-overview)
2. [User Stories](#2-user-stories)
3. [Functional Requirements](#3-functional-requirements)
4. [Non-Functional Requirements](#4-non-functional-requirements)
5. [System Architecture](#5-system-architecture)
6. [Data Model](#6-data-model)
7. [Gemini Prompting Strategy](#7-gemini-prompting-strategy)
8. [Conflict Detection Logic](#8-conflict-detection-logic)
9. [Notification Logic](#9-notification-logic)
10. [MVP Implementation Plan](#10-mvp-implementation-plan)
11. [Testing Plan](#11-testing-plan)
12. [Future Scope](#12-future-scope)

---

## 1. Product Overview

### What Atlas Does

Atlas is an AI chief of staff for your life. It monitors your incoming and outgoing messages, detects when you confirm a real-world plan, extracts the event details, adds it to your calendar, and alerts you before you double-book yourself. Atlas also tracks deadlines and upcoming commitments so that everything you have agreed to is visible in one place — without you having to manually enter anything.

### Target User

Busy individuals — professionals, students, or anyone juggling a dense social and work calendar — who regularly confirm plans over text, email, or chat and routinely forget to add them to their calendar or overlook conflicts.

### Core User Problem

When a user replies "sounds good, see you at 7" over iMessage, that confirmation lives only in the conversation thread. Nothing pushes it onto the calendar. Nothing checks whether 7 PM is already blocked. The user either double-books themselves or misses the event entirely.

### MVP Goal

Deliver a locally-runnable web application (Next.js + Node.js) that:

- Accepts messages through a simulated inbox UI
- Uses the Gemini API to classify whether each message confirms a plan and to extract event details
- Writes confirmed events to a local calendar store (SQLite) and optionally to Google Calendar
- Detects and surfaces scheduling conflicts before committing an event
- Allows the user to review medium-confidence events before they are added
- Displays a unified view of calendar events and manual deadlines

The MVP deliberately avoids OS-level integrations (iMessage tap, background daemon, system notifications). Those belong to a later phase described in §12.

---

## 2. User Stories

| ID | Story |
|----|-------|
| US-01 | As a user, I want Atlas to detect when I confirm lunch over text so I do not have to manually add it to my calendar. |
| US-02 | As a user, I want Atlas to warn me before I double-book myself, including the specific events that conflict. |
| US-03 | As a user, I want to review events that Atlas is unsure about before they are added to my calendar. |
| US-04 | As a user, I want to see my upcoming deadlines and commitments in one consolidated view. |
| US-05 | As a user, I want Atlas to extract the title, date, time, location, and participants from a confirmed message so the calendar event is complete. |
| US-06 | As a user, I want to manually add a deadline or task so it appears alongside my calendar events. |
| US-07 | As a user, I want Atlas to tell me why it thinks a message is a confirmed plan so I can correct it when wrong. |
| US-08 | As a user, I want vague time references like "tomorrow" or "Friday" resolved to actual dates automatically. |
| US-09 | As a user, I want to dismiss a pending event if Atlas got it wrong. |
| US-10 | As a user, I want upcoming deadline reminders surfaced proactively so nothing sneaks up on me. |

---

## 3. Functional Requirements

### 3.1 Message Ingestion

- **FR-01** The system must accept messages through a simulated inbox UI for MVP. Each message has: sender, recipient, body text, and timestamp.
- **FR-02** The system must queue each new incoming or outgoing message for classification.
- **FR-03** The system must store the original message in the `messages` table with its raw text and metadata.
- **FR-04** The system must support manual message submission via the UI (paste-in or type) in addition to the simulated feed.

### 3.2 AI Plan Detection

- **FR-05** The system must send each queued message to the Gemini API using the prompt template defined in §7.
- **FR-06** The system must parse the structured JSON response from Gemini.
- **FR-07** If `confidence >= 0.85`, the system must treat the event as confirmed and add it automatically.
- **FR-08** If `0.50 <= confidence < 0.85`, the system must create a pending event and prompt the user to confirm or dismiss.
- **FR-09** If `confidence < 0.50`, the system must ignore the message for calendar purposes but still log the classification result.
- **FR-10** The system must store the raw Gemini response JSON alongside each extracted event for traceability.

### 3.3 Event Extraction

- **FR-11** The system must extract: event title, date (ISO 8601), start time, end time (if inferable), participants, location, confidence score, and reasoning summary.
- **FR-12** The system must resolve relative date references ("tomorrow", "Friday", "next week") to absolute dates using the message timestamp as the anchor.
- **FR-13** If end time is absent, the system must default to start time + 1 hour.
- **FR-14** The system must store extracted events in the `extracted_events` table linked to the originating message.

### 3.4 Calendar Creation

- **FR-15** Confirmed events must be written to the local `calendar_events` table.
- **FR-16** If Google Calendar is configured (OAuth tokens present), confirmed events must also be written to Google Calendar via the Google Calendar API.
- **FR-17** Each calendar event must carry a source reference back to the originating `extracted_events` row.

### 3.5 Conflict Detection

- **FR-18** Before committing any event (confirmed or pending-approval), the system must query existing calendar events for temporal overlap.
- **FR-19** Two events conflict if their time ranges overlap: `event_a.start < event_b.end AND event_a.end > event_b.start`.
- **FR-20** If a conflict is detected, the system must surface a conflict notification (see §3.7) and pause auto-add.
- **FR-21** The user must be able to override a conflict and add the event anyway.

### 3.6 Pending Event Review Flow

- **FR-22** Pending events must appear in a dedicated "Review" section in the UI.
- **FR-23** Each pending event must display: title, date/time, participants, location, confidence score, and reasoning summary.
- **FR-24** The user must be able to approve a pending event (moves to confirmed) or dismiss it (marks as rejected).
- **FR-25** Approved pending events must go through conflict detection before being written to the calendar.

### 3.7 Notification System

- **FR-26** The system must display in-app notifications (toast or banner) for: new confirmed events, conflict warnings, pending events needing review, and upcoming deadline reminders.
- **FR-27** Conflict notifications must name both conflicting events and their times, e.g. "Dinner with Alex at 7 PM overlaps with your CS meeting from 6:30–7:30."
- **FR-28** Notifications must persist in a notification log visible in the UI.
- **FR-29** MVP notifications are in-app only. Twilio SMS is a future feature.

### 3.8 Manual Task / Deadline Entry

- **FR-30** The user must be able to add a deadline or task manually via a form: title, due date, optional description, optional priority.
- **FR-31** Deadlines must be stored in the `deadlines` table, separate from calendar events.
- **FR-32** Deadlines within the next 48 hours must trigger a reminder notification.
- **FR-33** The unified dashboard must surface both calendar events and deadlines ordered chronologically.

---

## 4. Non-Functional Requirements

### 4.1 Privacy

- Message content must never be sent to any third-party service other than the Gemini API for classification.
- No message body or calendar data may be logged to stdout in production mode.
- Google Calendar OAuth tokens must be stored in environment variables or a local secrets file never committed to version control.

### 4.2 Reliability

- The Gemini API call must implement exponential back-off with a maximum of 3 retries on transient errors (5xx, network timeout).
- If Gemini is unavailable, the message must be queued and retried; no events are silently dropped.
- The SQLite database must use WAL mode to prevent data loss on crash.

### 4.3 Latency

- End-to-end processing from message submission to UI update (event added or pending prompt shown) must complete in under 5 seconds under normal conditions.
- The Gemini API round-trip is the primary latency driver; the UI must show a processing indicator while waiting.

### 4.4 Data Security

- All API keys (Gemini, Google) must be loaded from environment variables; they must never appear in source code or logs.
- SQLite database file must be excluded from version control via `.gitignore`.
- Google OAuth refresh tokens must be stored with 0600 file permissions.

### 4.5 Explainability

- Every extracted event must expose the `reasoningSummary` from Gemini to the user in the review UI.
- Confidence scores must be displayed as a human-readable label: High (≥ 0.85), Medium (0.50–0.84), Low (< 0.50).

### 4.6 Failure Handling

- If event extraction returns malformed JSON, the system must log the error, mark the message as `classification_failed`, and surface a notification to the user.
- If Google Calendar write fails, the event must remain in the local store and the failure must be shown to the user with a retry option.
- If a date cannot be resolved (genuinely ambiguous), the event must be placed in the pending review queue with the date field flagged as unresolved.

---

## 5. System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Browser (Next.js)                       │
│                                                                 │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────────┐ │
│  │  Message     │  │  Dashboard /  │  │  Pending Review      │ │
│  │  Inbox UI    │  │  Calendar     │  │  Queue UI            │ │
│  └──────┬───────┘  └───────┬───────┘  └──────────┬───────────┘ │
└─────────┼──────────────────┼─────────────────────┼─────────────┘
          │ HTTP / tRPC      │                      │
┌─────────▼──────────────────▼─────────────────────▼─────────────┐
│                     Node.js API Layer                           │
│                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐ │
│  │  Message         │  │  Event           │  │  Deadline     │ │
│  │  Ingestion       │  │  Controller      │  │  Controller   │ │
│  │  Module          │  │                  │  │               │ │
│  └────────┬─────────┘  └────────┬─────────┘  └───────┬───────┘ │
│           │                     │                     │         │
│  ┌────────▼─────────────────────▼─────────────────────▼───────┐ │
│  │                    Service Layer                            │ │
│  │                                                             │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐ │ │
│  │  │  Gemini      │  │  Calendar    │  │  Conflict        │ │ │
│  │  │  Classification│ │  Module      │  │  Detection       │ │ │
│  │  │  Module      │  │  (Local +    │  │  Engine          │ │ │
│  │  │              │  │  Google API) │  │                  │ │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────────────────┘ │ │
│  │         │                 │                                 │ │
│  │  ┌──────▼───────┐  ┌──────▼───────────────────────────┐   │ │
│  │  │  Notification│  │  Notification Module              │   │ │
│  │  │  Module      │  │                                   │   │ │
│  │  └──────────────┘  └───────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────┬───────────────────────────────────┘
                              │
              ┌───────────────▼───────────────┐
              │         SQLite (WAL)          │
              │                               │
              │  messages · extracted_events  │
              │  calendar_events · deadlines  │
              │  pending_events · contacts    │
              │  notifications                │
              └───────────────────────────────┘
                              │
              ┌───────────────▼───────────────┐
              │       External APIs           │
              │  Gemini API  │  Google        │
              │              │  Calendar API  │
              └───────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **Message Inbox UI** | Simulated feed of messages; manual submit; shows classification status badges |
| **Dashboard / Calendar** | Chronological view of confirmed events + deadlines; inline notification feed |
| **Pending Review Queue** | Cards for medium-confidence events; approve / dismiss actions |
| **Message Ingestion Module** | Validates and persists incoming messages; enqueues for classification |
| **Gemini Classification Module** | Builds prompt, calls Gemini API, parses JSON response, resolves relative dates |
| **Calendar Module** | Writes events to local store; optionally syncs to Google Calendar |
| **Conflict Detection Engine** | Interval overlap query against `calendar_events`; returns conflicting events |
| **Notification Module** | Creates notification records; pushes real-time updates to frontend via SSE or WebSocket |
| **Deadline Controller** | CRUD for manual deadlines; triggers reminders |

---

## 6. Data Model

### `messages`

```sql
CREATE TABLE messages (
  id            TEXT PRIMARY KEY,          -- UUID
  sender        TEXT NOT NULL,
  recipient     TEXT NOT NULL,
  body          TEXT NOT NULL,
  source        TEXT NOT NULL DEFAULT 'simulated', -- simulated | gmail | imessage
  received_at   TEXT NOT NULL,             -- ISO 8601
  processed_at  TEXT,
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK(status IN ('pending','classified','classification_failed','ignored'))
);
```

### `extracted_events`

```sql
CREATE TABLE extracted_events (
  id                 TEXT PRIMARY KEY,
  message_id         TEXT NOT NULL REFERENCES messages(id),
  is_confirmed_plan  INTEGER NOT NULL,     -- 0 | 1
  confidence         REAL NOT NULL,
  event_title        TEXT,
  event_date         TEXT,                 -- ISO 8601 date
  start_time         TEXT,                 -- HH:MM (24h)
  end_time           TEXT,
  location           TEXT,
  needs_confirmation INTEGER NOT NULL DEFAULT 0,
  reasoning_summary  TEXT,
  raw_gemini_json    TEXT NOT NULL,
  created_at         TEXT NOT NULL
);
```

### `contacts`

```sql
CREATE TABLE contacts (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  email       TEXT,
  phone       TEXT,
  created_at  TEXT NOT NULL
);
```

### `extracted_event_participants`

```sql
CREATE TABLE extracted_event_participants (
  event_id    TEXT NOT NULL REFERENCES extracted_events(id),
  contact_id  TEXT NOT NULL REFERENCES contacts(id),
  name_raw    TEXT,                        -- name as extracted from message
  PRIMARY KEY (event_id, contact_id)
);
```

### `calendar_events`

```sql
CREATE TABLE calendar_events (
  id                   TEXT PRIMARY KEY,
  extracted_event_id   TEXT REFERENCES extracted_events(id),
  title                TEXT NOT NULL,
  date                 TEXT NOT NULL,      -- ISO 8601 date
  start_time           TEXT NOT NULL,      -- HH:MM (24h)
  end_time             TEXT NOT NULL,
  location             TEXT,
  google_event_id      TEXT,              -- populated if synced to Google Calendar
  timezone             TEXT NOT NULL DEFAULT 'America/Los_Angeles',
  status               TEXT NOT NULL DEFAULT 'confirmed'
                       CHECK(status IN ('confirmed','cancelled')),
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);
```

### `pending_events`

```sql
CREATE TABLE pending_events (
  id                   TEXT PRIMARY KEY,
  extracted_event_id   TEXT NOT NULL REFERENCES extracted_events(id),
  title                TEXT NOT NULL,
  date                 TEXT,
  start_time           TEXT,
  end_time             TEXT,
  location             TEXT,
  confidence           REAL NOT NULL,
  reasoning_summary    TEXT,
  status               TEXT NOT NULL DEFAULT 'awaiting_review'
                       CHECK(status IN ('awaiting_review','approved','dismissed')),
  created_at           TEXT NOT NULL,
  reviewed_at          TEXT
);
```

### `deadlines`

```sql
CREATE TABLE deadlines (
  id           TEXT PRIMARY KEY,
  title        TEXT NOT NULL,
  due_date     TEXT NOT NULL,             -- ISO 8601 datetime
  description  TEXT,
  priority     TEXT DEFAULT 'medium'
               CHECK(priority IN ('low','medium','high')),
  completed    INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);
```

### `notifications`

```sql
CREATE TABLE notifications (
  id           TEXT PRIMARY KEY,
  type         TEXT NOT NULL
               CHECK(type IN ('conflict','pending_review','event_added','deadline_reminder','extraction_error')),
  title        TEXT NOT NULL,
  body         TEXT NOT NULL,
  related_id   TEXT,                      -- ID of related event, deadline, etc.
  read         INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL
);
```

---

## 7. Gemini Prompting Strategy

### System Instruction

```
You are a scheduling assistant. Your job is to read a single message and determine
whether it represents a confirmed real-world plan (meeting, meal, call, event, etc.).

Rules:
- A confirmed plan requires that the sender has agreed to something specific.
- Vague social phrases like "we should hang out sometime" are NOT confirmed plans.
- Phrases like "sounds good, see you at 7" ARE confirmed plans.
- Resolve any relative date references (tomorrow, Friday, next week) relative to the
  message timestamp provided. Return absolute ISO 8601 dates.
- If end time is not stated, leave endTime null.
- Return ONLY valid JSON matching the schema below. No markdown, no explanation text.
```

### User Message Template

```
Message timestamp: {{ISO_8601_TIMESTAMP}}
Message sender: {{SENDER_NAME}}
Message recipient: {{RECIPIENT_NAME}}
Message body:
"""
{{MESSAGE_BODY}}
"""

Return JSON in exactly this schema:
{
  "isConfirmedPlan": boolean,
  "confidence": number (0.0 to 1.0),
  "eventTitle": string | null,
  "date": string | null,          // ISO 8601: YYYY-MM-DD
  "startTime": string | null,     // 24h HH:MM
  "endTime": string | null,       // 24h HH:MM
  "participants": string[],        // names extracted from message
  "location": string | null,
  "needsUserConfirmation": boolean,
  "reasoningSummary": string
}
```

### Example Response

```json
{
  "isConfirmedPlan": true,
  "confidence": 0.92,
  "eventTitle": "Dinner with Alex",
  "date": "2026-05-15",
  "startTime": "19:00",
  "endTime": "20:30",
  "participants": ["Alex"],
  "location": null,
  "needsUserConfirmation": false,
  "reasoningSummary": "User explicitly agreed to dinner at 7. Friday relative to the message timestamp resolves to 2026-05-15. End time estimated at 90 minutes."
}
```

### Confidence Thresholds

| Range | Label | Action |
|-------|-------|--------|
| 0.85 – 1.00 | High | Auto-add to calendar |
| 0.50 – 0.84 | Medium | Create pending event for user review |
| 0.00 – 0.49 | Low | Ignore; log classification only |

### Validation

After receiving the Gemini response the API layer must:

1. Parse JSON; on parse failure mark message `classification_failed`.
2. Validate all required fields are present and of the correct type.
3. Validate `date` matches `YYYY-MM-DD` format.
4. Validate `startTime` and `endTime` match `HH:MM` format if present.
5. Clamp `confidence` to [0, 1].
6. If `endTime` is null and `startTime` is set, default `endTime` to `startTime + 1 hour`.

---

## 8. Conflict Detection Logic

### Core Algorithm

Before any event is committed to `calendar_events`, run:

```sql
SELECT *
FROM   calendar_events
WHERE  date       = :new_event_date
  AND  status     = 'confirmed'
  AND  start_time < :new_event_end_time
  AND  end_time   > :new_event_start_time;
```

If any rows are returned, a conflict exists. Surface all conflicting events to the user.

For Google Calendar sync, additionally call the Google Calendar `freebusy` endpoint for the same window before writing.

### Edge Cases

| Case | Handling |
|------|----------|
| **Missing end time** | Default to start + 1 hour before conflict check (FR-13). |
| **Vague date ("tomorrow", "Friday")** | Gemini resolves to absolute date using message timestamp. If resolution fails, place in pending queue with date flagged as unresolved; do not run conflict check until user supplies a date. |
| **Timezone mismatch** | All times stored in UTC internally; display converted to user's local timezone (stored in user preferences, defaults to system timezone). Google Calendar API events are fetched and compared in UTC. |
| **Recurring events** | For MVP, only single-instance events are created. Recurring Google Calendar events are read for conflict checking: the `freebusy` API handles recurrence expansion automatically. |
| **Tentative events** | Calendar events with `status = 'tentative'` (Google: `TENTATIVE`) are flagged in conflict results with a note "This conflicts with a tentative event — you may still be free." |
| **All-day events** | Treated as 00:00–23:59 for overlap purposes; surface a softer warning rather than a hard block. |
| **Multi-day events** | Break into per-day ranges before comparison. |

---

## 9. Notification Logic

### Notification Triggers

| Trigger | Type | Message Template |
|---------|------|-----------------|
| Confirmed event added successfully | `event_added` | "✓ Added: {title} on {date} at {startTime}" |
| Scheduling conflict detected | `conflict` | "Heads up — {new_event_title} at {startTime} overlaps with {existing_title} from {existing_start}–{existing_end}." |
| Medium-confidence event needs review | `pending_review` | "Atlas isn't sure about this one: '{title}' on {date}. Tap to review." |
| Low-confidence extraction | *(silent log only)* | No user-facing notification. |
| Extraction / parse error | `extraction_error` | "Atlas couldn't parse a message from {sender}. Review it manually." |
| Deadline due within 48 hours | `deadline_reminder` | "Upcoming deadline: '{title}' is due {due_date}." |
| Deadline due within 24 hours | `deadline_reminder` | "Deadline today: '{title}' is due at {time}." |

### Delivery

- **MVP:** In-app toast (3-second auto-dismiss for low-urgency; persistent for conflict/pending) + notification badge on the review queue icon.
- **Future:** Twilio SMS for conflict and high-urgency deadline reminders (see §12).

### Suppression Rules

- Do not re-notify for the same conflict if the user has already been shown it and dismissed without acting.
- Do not send a deadline reminder if the deadline is already marked `completed = 1`.
- Batch multiple pending-review notifications into a single "You have N events to review" if more than 3 accumulate within 60 seconds.

---

## 10. MVP Implementation Plan

### Milestone 1 — Project Setup + TRD

- Initialize Next.js project with TypeScript and Tailwind CSS
- Initialize Node.js API layer (tRPC or REST)
- Configure ESLint, Prettier, and path aliases
- Set up SQLite with Drizzle ORM (or Prisma)
- Apply initial database migrations from the schema in §6
- Create `.env.example` with placeholders for `GEMINI_API_KEY` and `GOOGLE_CALENDAR_*`
- **Deliverable:** TRD.md (this document) merged to main; runnable `npm run dev`

### Milestone 2 — Message Simulator

- Build the simulated inbox UI: message list, compose form (sender, body)
- POST /api/messages endpoint: validate, persist, return confirmation
- Seed script with 20+ test messages covering confirmed plans, non-plans, and ambiguous cases
- Status badge on each message row: pending | classified | ignored | failed
- **Deliverable:** User can submit messages and see them persisted with status badges

### Milestone 3 — Gemini Extraction

- Implement `GeminiClassificationService` with the prompt from §7
- Integrate retry logic (exponential back-off, max 3 retries)
- Parse and validate Gemini response; persist to `extracted_events`
- Update message status after classification
- Unit tests for prompt building and response parsing
- **Deliverable:** Submitted messages are classified; extracted event data is visible in the UI

### Milestone 4 — Local Database + Event Storage

- Implement full CRUD for `calendar_events`, `pending_events`, `deadlines`, `notifications`
- Write confirmed events (confidence ≥ 0.85) to `calendar_events`
- Write medium-confidence events to `pending_events`
- Implement manual deadline entry form and API
- **Deliverable:** Calendar store is populated; deadline CRUD works

### Milestone 5 — Calendar + Event UI

- Dashboard: chronological list of calendar events + deadlines
- Pending Review queue: approve / dismiss actions
- Event detail drawer showing participants, location, reasoning summary
- Optional: Google Calendar OAuth flow + sync on confirmed event
- **Deliverable:** Full calendar and review UI functional end-to-end

### Milestone 6 — Conflict Detection

- Implement `ConflictDetectionEngine` using the SQL query in §8
- Block auto-add when conflict found; show conflict modal with both events
- Override button to force-add despite conflict
- Handle edge cases from §8: missing end time, timezone, all-day events
- **Deliverable:** Conflicts are detected and surfaced before any event is saved

### Milestone 7 — Notifications

- Implement `NotificationService` and `notifications` table writes
- In-app toast component (auto-dismiss + persistent variants)
- Notification badge + log panel in the UI
- Background job (cron or Next.js route handler) for deadline reminders
- **Deliverable:** All notification triggers from §9 produce visible in-app notifications

### Milestone 8 — Polish + Tests

- Integration tests: end-to-end message → event flow
- Unit tests: conflict detection, date resolution, confidence routing
- Error state UI: failed classification, Google Calendar sync failure
- Loading states and processing indicators
- Accessibility pass (ARIA labels, keyboard nav)
- README with setup instructions and demo screenshots
- **Deliverable:** Test suite passing; app demo-ready

---

## 11. Testing Plan

### 11.1 Plan Detection Tests

| Test | Input | Expected Output |
|------|-------|----------------|
| Clear confirmation | "sounds good, see you at 7" | `isConfirmedPlan: true`, confidence ≥ 0.85 |
| Clear non-plan | "haha that's so funny" | `isConfirmedPlan: false`, confidence < 0.50 |
| Vague social | "we should grab coffee sometime" | `isConfirmedPlan: false`, confidence < 0.50 |
| Ambiguous | "maybe Thursday works?" | confidence in 0.50–0.84 range |
| Explicit confirmation | "confirmed for tomorrow at 3" | `isConfirmedPlan: true`, confidence ≥ 0.85 |
| Day-of-week reference | "yes let's do lunch Friday" | date resolves to correct upcoming Friday |

### 11.2 Event Extraction Tests

| Test | Expected |
|------|----------|
| Title extraction | "Dinner with Alex" extracted from "dinner with alex at 7" |
| Relative date — tomorrow | Resolves to correct absolute date given anchor timestamp |
| Relative date — Friday | Resolves to the next Friday from anchor |
| Missing end time | Defaults to start + 1 hour |
| Location extraction | "Nobu" extracted from "meet at Nobu at 8" |
| Multiple participants | ["Alex", "Jordan"] extracted from "dinner with Alex and Jordan" |

### 11.3 Confidence Routing Tests

| Confidence | Expected Action |
|------------|----------------|
| 0.92 | Written to `calendar_events` |
| 0.65 | Written to `pending_events`; user review required |
| 0.30 | No event created; message status = ignored |

### 11.4 Conflict Detection Tests

| Scenario | Expected |
|----------|----------|
| New event fully inside existing | Conflict detected |
| New event partially overlapping existing | Conflict detected |
| New event adjacent (end == start) | No conflict |
| New event same day, no time overlap | No conflict |
| New event, missing end time (defaulted) | Default applied before check |
| All-day existing event | Soft warning shown |

### 11.5 Pending Event Flow Tests

- Approve action: pending event moves to `calendar_events`, conflict check runs
- Dismiss action: pending event status = dismissed, no calendar write
- Conflict on approve: conflict modal shown, event stays pending until resolved

### 11.6 Database Persistence Tests

- Message survives app restart (SQLite WAL commit verified)
- `calendar_events` rows survive app restart
- Cascaded delete: deleting a message does not delete associated calendar event

### 11.7 Google Calendar Integration Tests (optional, requires OAuth)

- Confirmed event synced; `google_event_id` populated
- Duplicate prevention: re-processing same message does not create duplicate Google event
- `freebusy` conflict check returns correct result for known test events

---

## 12. Future Scope

The following capabilities are intentionally out of MVP scope. They are documented here to ensure the MVP architecture does not foreclose them.

### Message Source Integrations

| Source | Integration Path |
|--------|----------------|
| **iMessage / SMS** | macOS: read from `~/Library/Messages/chat.db` via a native menu-bar daemon (requires Full Disk Access permission). iOS: app extension or Shortcuts automation. |
| **Gmail** | Gmail API (Pub/Sub push notifications for real-time ingestion; OAuth 2.0 already partially reused from Google Calendar). |
| **WhatsApp** | WhatsApp Business API or unofficial bridges (wa-js). Regulatory constraints vary by region. |
| **Slack** | Slack Events API with OAuth; monitor DMs for plan confirmation patterns. |
| **Discord** | Discord Bot API; monitor DMs and designated channels. |

### Platform Integrations

- **macOS menu bar app** — Electron or native Swift app that runs as a background daemon, monitors system notification center, and surfaces Atlas alerts as macOS notifications.
- **iOS app** — SwiftUI app with Share Extension to pipe messages into Atlas from any iOS app.
- **Background agent** — Persistent process that polls message sources on a schedule rather than requiring the web UI to be open.

### Notification Channels

- **Twilio SMS** — Send conflict and deadline alerts as SMS to the user's phone number.
- **Email digest** — Daily summary of upcoming events and deadlines.
- **macOS / iOS push notifications** — Native system notifications via APNs.

### Intelligence Upgrades

- **Proactive rescheduling suggestions** — When a conflict is detected, Atlas suggests the next available common slot based on all participants' calendars.
- **Participant calendar awareness** — If participants share their calendars (or Atlas can read them via Google Calendar API), Atlas can check their availability before suggesting times.
- **Recurring plan detection** — Recognize "our usual Tuesday standup" as a recurring commitment and generate a recurring calendar event.
- **Natural language event editing** — "Move my dinner with Alex to 8" parsed and applied to the existing event.
- **Sentiment and urgency scoring** — Prioritize deadline reminders based on message urgency signals.

### OS-Level Privacy Architecture (Future)

When Atlas operates at the OS layer (reading messages, accessing system notifications), the following privacy principles must be enforced:

1. **On-device classification first** — Run a lightweight local model for initial plan detection; only send to Gemini API if local confidence is below threshold. This minimizes data egress.
2. **Explicit permission prompts** — Request only the minimum OS permissions needed; explain in plain language why each is needed.
3. **Data residency** — All message content stays on-device or in the user's own cloud (Google Calendar). No Atlas backend stores message bodies.
4. **Audit log** — User-accessible log of every message Atlas read and every action it took.
5. **Opt-out per source** — User can disable Atlas for specific message threads, contacts, or sources without losing access to others.

---

*End of TRD — Atlas v1.0*
