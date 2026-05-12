import EventKit
import Foundation

@MainActor
final class CalendarService: ObservableObject {
    static let shared = CalendarService()

    let store = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var availableCalendars: [EKCalendar] = []

    private init() {
        refreshStatus()
    }

    func refreshStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if authorizationStatus == .fullAccess || authorizationStatus == .writeOnly {
            loadCalendars()
        }
    }

    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestWriteOnlyAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            await MainActor.run { refreshStatus() }
            return granted
        } catch {
            return false
        }
    }

    func loadCalendars() {
        availableCalendars = store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .sorted { $0.title < $1.title }
    }

    /// Upcoming confirmed events in the next 30 days from Atlas's own log.
    var upcomingAtlasEvents: [AtlasCalendarEvent] {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        return SharedStorage.shared.calendarEvents
            .filter { $0.date >= today }
            .sorted { $0.date < $1.date || ($0.date == $1.date && $0.startTime < $1.startTime) }
    }
}
