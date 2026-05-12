# Atlas — iOS App

Native SwiftUI iPhone app with three targets that work together.

## Architecture

```
Atlas (main app)
  ├── Dashboard — upcoming events from your calendar
  ├── Review — medium-confidence events waiting for your approval
  ├── Deadlines — manual task tracking with reminders
  ├── Alerts — notification log (conflicts, adds, reviews)
  └── Settings — API key, calendar picker, monitoring toggle

AtlasShareExtension
  └── Activated from the Share sheet in WhatsApp, Messenger, Instagram,
      or any other app. Long-press a message → Share → Atlas.

AtlasMessageExtension
  └── iMessage App Extension. Lives in the app tray at the bottom of
      every iMessage conversation. Shows a compact bar with the on/off
      toggle and a one-tap Process button.
```

All three targets share data through an **App Group** (`group.com.atlas.app`).

---

## Requirements

- macOS with Xcode 15+
- An Apple Developer account (free account works for local installs; paid account for TestFlight)
- iPhone running iOS 16+
- A Gemini API key from [aistudio.google.com](https://aistudio.google.com)

---

## Build

```bash
cd ios/
bash setup.sh          # installs xcodegen and generates Atlas.xcodeproj
open Atlas.xcodeproj
```

In Xcode:
1. Select the **Atlas** target → **Signing & Capabilities** → set your Team
2. Confirm the App Group `group.com.atlas.app` is listed under Signing & Capabilities
3. Repeat for **AtlasShareExtension** and **AtlasMessageExtension** — all three must share the same App Group
4. Select your connected iPhone as the build target
5. **Product → Run** (Cmd+R)

> Extensions only work on a physical device, not the Simulator.

---

## First launch

1. Open **Atlas** → **Settings**
2. Tap **Grant calendar access** and approve
3. Paste your **Gemini API key** and tap Save
4. The **Monitoring** toggle is on by default

---

## How each source works

### iMessage (2 taps from any conversation)

1. Open any iMessage conversation
2. Tap the **four dots (•••)** icon in the app tray at the bottom of the screen to see all iMessage apps
3. Tap **Atlas** — the Atlas bar appears
4. Long-press any message bubble → **Copy**
5. Tap **Process** in the Atlas bar
6. Result appears immediately: added to calendar, sent to review, or conflict warning

The on/off toggle lives directly in the Atlas bar — no need to leave Messages.

> **Why copy?** iOS sandboxing prevents any app from reading the text of another app's conversation. Copying is the minimum user action required on iOS. On Android this works differently.

### WhatsApp (2 taps)

1. Long-press any message → tap the **Share** icon
2. Tap **Atlas** in the share sheet
3. Atlas auto-processes if monitoring is on

### Facebook Messenger (2 taps)

1. Long-press any message → **More** → tap the **Share** icon
2. Tap **Atlas** in the share sheet

### Instagram (2 taps)

1. Long-press any DM message → **More** → **Share**
2. Tap **Atlas** in the share sheet

> If Atlas doesn't appear in the share sheet, scroll to **More** at the bottom and enable it.

---

## Confidence routing

| Confidence | Action |
|------------|--------|
| ≥ 85% | Auto-added to calendar (after conflict check) |
| 50–84% | Parked in **Review** tab — you approve or dismiss |
| < 50% | Ignored silently |

---

## Conflict detection

Before adding any event, Atlas checks your existing Atlas-tracked events for time overlap. If there's a conflict:
- A push notification fires immediately
- The new event is parked in **Review** rather than auto-added
- The notification names both conflicting events and their times

---

## Background processing

Atlas registers two background tasks with iOS:

| Task | Trigger | Purpose |
|------|---------|---------|
| `process-queue` | Every ~15 min (iOS decides) | Processes any queued messages |
| `deadline-check` | Every ~1 hour | Fires reminders for deadlines within 48 hours |

Background execution frequency is controlled by iOS based on your usage patterns. The app must be used regularly for iOS to grant frequent background time.

---

## Customising the App Group and bundle IDs

If you need to change the bundle ID prefix (e.g. from `com.atlas` to `com.yourname.atlas`):

1. Edit `project.yml` — update all three `PRODUCT_BUNDLE_IDENTIFIER` entries
2. Edit `AppGroupConstants.swift` — update `AppGroup.id` to match your new App Group ID
3. Update all three `.entitlements` files with the new App Group string
4. Regenerate the project: `xcodegen generate`
5. In Xcode, re-register the new App Group under each target's Signing & Capabilities

---

## File map

```
ios/
  project.yml                   xcodegen spec → generates Atlas.xcodeproj
  setup.sh                      one-command setup script

  Shared/                       compiled into all three targets
    AppGroupConstants.swift     bundle IDs, storage keys, confidence thresholds
    SharedModels.swift          all data types (Codable structs)
    SharedStorage.swift         thread-safe App Group UserDefaults wrapper
    GeminiService.swift         Gemini 1.5 Flash API client, retry logic
    ProcessorService.swift      message → classify → route → EventKit pipeline

  Atlas/                        main app target
    AtlasApp.swift              app entry point, BGTaskScheduler registration
    ContentView.swift           TabView
    Views/
      DashboardView.swift       upcoming events list
      PendingReviewView.swift   approve / dismiss medium-confidence events
      DeadlinesView.swift       manual deadlines with priority + reminders
      NotificationsView.swift   notification log
      SettingsView.swift        API key, calendar picker, monitoring toggle
    Services/
      CalendarService.swift     EventKit wrapper (write-only access)
      LocalNotificationService.swift  UNUserNotificationCenter helpers
    Atlas.entitlements
    Info.plist

  AtlasShareExtension/          Share Extension target
    ShareViewController.swift   UIViewController, extracts shared text
    ShareView.swift             SwiftUI processing UI
    AtlasShareExtension.entitlements
    Info.plist

  AtlasMessageExtension/        iMessage App Extension target
    MessagesViewController.swift  MSMessagesAppViewController
    MessageExtensionView.swift    compact bar + expanded review panel
    AtlasMessageExtension.entitlements
    Info.plist
```
