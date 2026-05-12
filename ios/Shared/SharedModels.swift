import Foundation

// MARK: - Message queue entry

struct QueuedMessage: Codable, Identifiable {
    let id: UUID
    let body: String
    let sender: String
    let source: MessageSource
    let timestamp: Date
    var status: MessageStatus

    enum MessageSource: String, Codable {
        case iMessage, whatsApp, messenger, instagram, clipboard, unknown
    }
    enum MessageStatus: String, Codable {
        case pending, processing, classified, failed, ignored
    }
}

// MARK: - Gemini result

struct GeminiResult: Codable {
    let isConfirmedPlan: Bool
    let confidence: Double
    let eventTitle: String?
    let date: String?
    let startTime: String?
    let endTime: String?
    let participants: [String]
    let location: String?
    let needsUserConfirmation: Bool
    let reasoningSummary: String
}

// MARK: - Pending event (awaiting user review)

struct PendingEvent: Codable, Identifiable {
    let id: UUID
    let title: String
    let date: String?
    let startTime: String?
    let endTime: String?
    let location: String?
    let participants: [String]
    let confidence: Double
    let reasoningSummary: String
    let source: QueuedMessage.MessageSource
    let originalBody: String
    let createdAt: Date
    var status: ReviewStatus

    enum ReviewStatus: String, Codable {
        case awaitingReview, approved, dismissed
    }

    var confidenceLabel: String {
        switch confidence {
        case ConfidenceLevel.autoAdd...: return "High"
        case ConfidenceLevel.pendingReview..<ConfidenceLevel.autoAdd: return "Medium"
        default: return "Low"
        }
    }
}

// MARK: - Atlas calendar event (mirrors what was written to EventKit)

struct AtlasCalendarEvent: Codable, Identifiable {
    let id: UUID
    let ekEventId: String
    let title: String
    let date: String
    let startTime: String
    let endTime: String
    let location: String?
    let participants: [String]
    let source: QueuedMessage.MessageSource
    let createdAt: Date
}

// MARK: - Deadline

struct Deadline: Codable, Identifiable {
    let id: UUID
    var title: String
    var dueDate: Date
    var description: String?
    var priority: Priority
    var completed: Bool
    let createdAt: Date

    enum Priority: String, Codable, CaseIterable {
        case low, medium, high

        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            case .low: return "gray"
            }
        }
    }
}

// MARK: - In-app notification

struct AtlasNotification: Codable, Identifiable {
    let id: UUID
    let type: NotificationType
    let title: String
    let body: String
    let relatedId: UUID?
    var isRead: Bool
    let createdAt: Date

    enum NotificationType: String, Codable {
        case eventAdded, conflict, pendingReview, deadlineReminder, extractionError
    }
}

// MARK: - Conflict detection

struct ConflictInfo {
    let conflictingEvent: AtlasCalendarEvent
    let overlapsMessage: String
}
