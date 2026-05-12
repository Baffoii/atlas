import Foundation

enum AppGroup {
    static let id = "group.com.atlas.app"
    static let bundleId = "com.atlas.app"
}

enum BGTaskID {
    static let processQueue = "com.atlas.app.process-queue"
    static let deadlineCheck = "com.atlas.app.deadline-check"
}

enum StorageKey {
    static let monitoringEnabled = "monitoringEnabled"
    static let geminiApiKey      = "geminiApiKey"
    static let pendingEvents     = "pendingEvents"
    static let calendarEvents    = "calendarEvents"
    static let deadlines         = "deadlines"
    static let notifications     = "atlasNotifications"
    static let messageQueue      = "messageQueue"
    static let selectedCalendarId = "selectedCalendarId"
}

enum ConfidenceLevel {
    static let autoAdd: Double    = 0.85
    static let pendingReview: Double = 0.50
}
