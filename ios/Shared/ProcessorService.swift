import Foundation
import EventKit

/// Core pipeline: message text → Gemini → route by confidence → EventKit / pending queue / ignore
actor ProcessorService {
    static let shared = ProcessorService()

    // MARK: - Entry point

    /// Classifies a message and takes the appropriate action.
    /// Returns a human-readable result string for display in extensions.
    func process(
        body: String,
        sender: String,
        source: QueuedMessage.MessageSource,
        timestamp: Date = Date(),
        calendarStore: EKEventStore
    ) async -> ProcessResult {
        guard SharedStorage.shared.monitoringEnabled else {
            return .skipped("Atlas monitoring is off.")
        }

        // Classify
        let geminiResult: GeminiResult
        do {
            geminiResult = try await GeminiService.shared.classify(
                body: body, sender: sender, timestamp: timestamp
            )
        } catch {
            let n = AtlasNotification(
                id: UUID(), type: .extractionError,
                title: "Extraction failed",
                body: "Atlas couldn't classify a message from \(sender). \(error.localizedDescription)",
                relatedId: nil, isRead: false, createdAt: Date()
            )
            SharedStorage.shared.addNotification(n)
            return .error(error.localizedDescription)
        }

        guard geminiResult.isConfirmedPlan, geminiResult.confidence >= ConfidenceLevel.pendingReview else {
            return .ignored("Not a confirmed plan (confidence \(String(format: "%.0f", geminiResult.confidence * 100))%)")
        }

        // High confidence → attempt auto-add
        if geminiResult.confidence >= ConfidenceLevel.autoAdd,
           let date = geminiResult.date,
           let startTime = geminiResult.startTime,
           let endTime = geminiResult.endTime {

            let conflicts = checkConflicts(date: date, startTime: startTime, endTime: endTime)

            if !conflicts.isEmpty {
                let conflictNames = conflicts.map { "\($0.title) (\($0.startTime)–\($0.endTime))" }.joined(separator: ", ")
                let n = AtlasNotification(
                    id: UUID(), type: .conflict,
                    title: "Scheduling conflict",
                    body: "Heads up — \(geminiResult.eventTitle ?? "New event") at \(startTime) overlaps with \(conflictNames).",
                    relatedId: nil, isRead: false, createdAt: Date()
                )
                SharedStorage.shared.addNotification(n)

                // Park as pending so the user can decide
                let pending = buildPending(from: geminiResult, sender: sender, source: source, body: body)
                SharedStorage.shared.addPendingEvent(pending)
                notifyPendingReview(pending)
                return .conflict(conflictNames)
            }

            // Write to EventKit
            if let ekId = await writeToCalendar(geminiResult, store: calendarStore) {
                let event = AtlasCalendarEvent(
                    id: UUID(), ekEventId: ekId,
                    title: geminiResult.eventTitle ?? "Event",
                    date: date, startTime: startTime, endTime: endTime,
                    location: geminiResult.location,
                    participants: geminiResult.participants,
                    source: source, createdAt: Date()
                )
                SharedStorage.shared.addCalendarEvent(event)
                let n = AtlasNotification(
                    id: UUID(), type: .eventAdded,
                    title: "Event added",
                    body: "Added: \(event.title) on \(date) at \(startTime)",
                    relatedId: event.id, isRead: false, createdAt: Date()
                )
                SharedStorage.shared.addNotification(n)
                return .added(event)
            }
        }

        // Medium confidence or missing details → pending review
        let pending = buildPending(from: geminiResult, sender: sender, source: source, body: body)
        SharedStorage.shared.addPendingEvent(pending)
        notifyPendingReview(pending)
        return .pendingReview(pending)
    }

    // MARK: - Approve pending event

    func approvePending(id: UUID, calendarStore: EKEventStore) async -> ProcessResult {
        guard let pending = SharedStorage.shared.pendingEvents.first(where: { $0.id == id }),
              let date = pending.date,
              let startTime = pending.startTime,
              let endTime = pending.endTime else {
            return .error("Pending event not found or missing date/time")
        }

        let conflicts = checkConflicts(date: date, startTime: startTime, endTime: endTime)
        if !conflicts.isEmpty {
            let names = conflicts.map { $0.title }.joined(separator: ", ")
            return .conflict(names)
        }

        let fakeResult = GeminiResult(
            isConfirmedPlan: true, confidence: 1.0,
            eventTitle: pending.title, date: date,
            startTime: startTime, endTime: endTime,
            participants: pending.participants,
            location: pending.location,
            needsUserConfirmation: false,
            reasoningSummary: pending.reasoningSummary
        )

        if let ekId = await writeToCalendar(fakeResult, store: calendarStore) {
            let event = AtlasCalendarEvent(
                id: UUID(), ekEventId: ekId,
                title: pending.title, date: date,
                startTime: startTime, endTime: endTime,
                location: pending.location,
                participants: pending.participants,
                source: pending.source, createdAt: Date()
            )
            SharedStorage.shared.addCalendarEvent(event)
            SharedStorage.shared.updatePendingEvent(id: id, status: .approved)
            let n = AtlasNotification(
                id: UUID(), type: .eventAdded,
                title: "Event added",
                body: "Added: \(event.title) on \(date) at \(startTime)",
                relatedId: event.id, isRead: false, createdAt: Date()
            )
            SharedStorage.shared.addNotification(n)
            return .added(event)
        }
        return .error("Failed to write event to calendar")
    }

    // MARK: - Dismiss pending event

    func dismissPending(id: UUID) {
        SharedStorage.shared.updatePendingEvent(id: id, status: .dismissed)
    }

    // MARK: - Conflict check

    private func checkConflicts(date: String, startTime: String, endTime: String) -> [AtlasCalendarEvent] {
        SharedStorage.shared.calendarEvents.filter { e in
            guard e.date == date else { return false }
            let newStart = timeToMinutes(startTime)
            let newEnd = timeToMinutes(endTime)
            let evStart = timeToMinutes(e.startTime)
            let evEnd = timeToMinutes(e.endTime)
            return newStart < evEnd && newEnd > evStart
        }
    }

    private func timeToMinutes(_ t: String) -> Int {
        let p = t.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return 0 }
        return p[0] * 60 + p[1]
    }

    // MARK: - EventKit write

    private func writeToCalendar(_ result: GeminiResult, store: EKEventStore) async -> String? {
        guard let dateStr = result.date,
              let startStr = result.startTime,
              let endStr = result.endTime else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        guard let startDate = formatter.date(from: "\(dateStr) \(startStr)"),
              let endDate = formatter.date(from: "\(dateStr) \(endStr)") else { return nil }

        let event = EKEvent(eventStore: store)
        event.title = result.eventTitle ?? "Event"
        event.startDate = startDate
        event.endDate = endDate
        event.location = result.location
        event.notes = result.participants.isEmpty ? nil : "With: \(result.participants.joined(separator: ", "))"

        if let calId = SharedStorage.shared.selectedCalendarId,
           let cal = store.calendar(withIdentifier: calId) {
            event.calendar = cal
        } else {
            event.calendar = store.defaultCalendarForNewEvents
        }

        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private func buildPending(
        from result: GeminiResult,
        sender: String,
        source: QueuedMessage.MessageSource,
        body: String
    ) -> PendingEvent {
        PendingEvent(
            id: UUID(),
            title: result.eventTitle ?? "Event with \(sender)",
            date: result.date,
            startTime: result.startTime,
            endTime: result.endTime,
            location: result.location,
            participants: result.participants.isEmpty ? [sender] : result.participants,
            confidence: result.confidence,
            reasoningSummary: result.reasoningSummary,
            source: source,
            originalBody: body,
            createdAt: Date(),
            status: .awaitingReview
        )
    }

    private func notifyPendingReview(_ event: PendingEvent) {
        let n = AtlasNotification(
            id: UUID(), type: .pendingReview,
            title: "Review needed",
            body: "Atlas isn't sure about: \"\(event.title)\"\(event.date.map { " on \($0)" } ?? ""). Tap to review.",
            relatedId: event.id, isRead: false, createdAt: Date()
        )
        SharedStorage.shared.addNotification(n)
    }
}

// MARK: - Result type

enum ProcessResult {
    case added(AtlasCalendarEvent)
    case pendingReview(PendingEvent)
    case conflict(String)
    case ignored(String)
    case skipped(String)
    case error(String)

    var displayMessage: String {
        switch self {
        case .added(let e):          return "✓ Added \"\(e.title)\" to your calendar"
        case .pendingReview(let e):  return "🔍 Needs review: \"\(e.title)\""
        case .conflict(let s):       return "⚠️ Conflict with \(s) — parked for review"
        case .ignored(let r):        return "— \(r)"
        case .skipped(let r):        return "— \(r)"
        case .error(let e):          return "✗ \(e)"
        }
    }

    var isActionable: Bool {
        switch self {
        case .added, .pendingReview, .conflict: return true
        default: return false
        }
    }
}
