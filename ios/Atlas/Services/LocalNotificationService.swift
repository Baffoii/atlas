import UserNotifications
import Foundation

final class LocalNotificationService {
    static let shared = LocalNotificationService()
    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
        } catch {
            return false
        }
    }

    func scheduleConflictAlert(newEventTitle: String, conflictWith: String) {
        send(
            id: "conflict-\(UUID().uuidString)",
            title: "Scheduling conflict",
            body: "Heads up — \(newEventTitle) overlaps with \(conflictWith).",
            categoryId: "CONFLICT"
        )
    }

    func schedulePendingReviewAlert(eventTitle: String, eventId: UUID) {
        send(
            id: "pending-\(eventId.uuidString)",
            title: "Review needed",
            body: "Atlas isn't sure about: \"\(eventTitle)\". Tap to review.",
            categoryId: "PENDING_REVIEW"
        )
    }

    func scheduleDeadlineReminder(title: String, dueDate: Date, deadlineId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming deadline"
        content.body = "\"\(title)\" is due \(relativeDateString(dueDate))"
        content.sound = .default
        content.categoryIdentifier = "DEADLINE"

        // Fire 24 hours before
        let fireDate = dueDate.addingTimeInterval(-86400)
        guard fireDate > Date() else { return }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "deadline-\(deadlineId.uuidString)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelDeadlineReminder(deadlineId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["deadline-\(deadlineId.uuidString)"]
        )
    }

    func registerCategories() {
        let approve = UNNotificationAction(identifier: "APPROVE", title: "Add to Calendar", options: .foreground)
        let dismiss = UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: .destructive)

        let pendingCategory = UNNotificationCategory(
            identifier: "PENDING_REVIEW",
            actions: [approve, dismiss],
            intentIdentifiers: []
        )
        let conflictCategory = UNNotificationCategory(
            identifier: "CONFLICT",
            actions: [dismiss],
            intentIdentifiers: []
        )
        let deadlineCategory = UNNotificationCategory(
            identifier: "DEADLINE",
            actions: [],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories(
            [pendingCategory, conflictCategory, deadlineCategory]
        )
    }

    // MARK: - Private

    private func send(id: String, title: String, body: String, categoryId: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryId

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
