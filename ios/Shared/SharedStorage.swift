import Foundation

/// Thread-safe App Group storage shared between the main app, Share Extension, and iMessage Extension.
final class SharedStorage {
    static let shared = SharedStorage()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    private init() {
        guard let suite = UserDefaults(suiteName: AppGroup.id) else {
            fatalError("App Group \(AppGroup.id) not configured — check entitlements")
        }
        defaults = suite
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Monitoring toggle

    var monitoringEnabled: Bool {
        get { defaults.bool(forKey: StorageKey.monitoringEnabled) }
        set { defaults.set(newValue, forKey: StorageKey.monitoringEnabled) }
    }

    // MARK: - Gemini API key (stored in UserDefaults for extension access;
    //         for production consider Keychain with accessGroup)

    var geminiApiKey: String? {
        get { defaults.string(forKey: StorageKey.geminiApiKey) }
        set { defaults.set(newValue, forKey: StorageKey.geminiApiKey) }
    }

    // MARK: - Selected calendar

    var selectedCalendarId: String? {
        get { defaults.string(forKey: StorageKey.selectedCalendarId) }
        set { defaults.set(newValue, forKey: StorageKey.selectedCalendarId) }
    }

    // MARK: - Message queue

    var messageQueue: [QueuedMessage] {
        get { load(forKey: StorageKey.messageQueue) ?? [] }
        set { save(newValue, forKey: StorageKey.messageQueue) }
    }

    func enqueue(_ message: QueuedMessage) {
        lock.withLock {
            var queue = messageQueue
            queue.append(message)
            messageQueue = queue
        }
    }

    func dequeueAll() -> [QueuedMessage] {
        lock.withLock {
            let all = messageQueue.filter { $0.status == .pending }
            return all
        }
    }

    func updateMessageStatus(id: UUID, status: QueuedMessage.MessageStatus) {
        lock.withLock {
            var queue = messageQueue
            if let idx = queue.firstIndex(where: { $0.id == id }) {
                queue[idx] = QueuedMessage(
                    id: queue[idx].id,
                    body: queue[idx].body,
                    sender: queue[idx].sender,
                    source: queue[idx].source,
                    timestamp: queue[idx].timestamp,
                    status: status
                )
            }
            messageQueue = queue
        }
    }

    // MARK: - Pending events

    var pendingEvents: [PendingEvent] {
        get { load(forKey: StorageKey.pendingEvents) ?? [] }
        set { save(newValue, forKey: StorageKey.pendingEvents) }
    }

    func addPendingEvent(_ event: PendingEvent) {
        lock.withLock {
            var list = pendingEvents
            list.append(event)
            pendingEvents = list
        }
    }

    func updatePendingEvent(id: UUID, status: PendingEvent.ReviewStatus) {
        lock.withLock {
            var list = pendingEvents
            if let idx = list.firstIndex(where: { $0.id == id }) {
                let old = list[idx]
                list[idx] = PendingEvent(
                    id: old.id, title: old.title, date: old.date,
                    startTime: old.startTime, endTime: old.endTime,
                    location: old.location, participants: old.participants,
                    confidence: old.confidence, reasoningSummary: old.reasoningSummary,
                    source: old.source, originalBody: old.originalBody,
                    createdAt: old.createdAt, status: status
                )
            }
            pendingEvents = list
        }
    }

    var awaitingReviewEvents: [PendingEvent] {
        pendingEvents.filter { $0.status == .awaitingReview }
    }

    // MARK: - Calendar events

    var calendarEvents: [AtlasCalendarEvent] {
        get { load(forKey: StorageKey.calendarEvents) ?? [] }
        set { save(newValue, forKey: StorageKey.calendarEvents) }
    }

    func addCalendarEvent(_ event: AtlasCalendarEvent) {
        lock.withLock {
            var list = calendarEvents
            list.append(event)
            calendarEvents = list
        }
    }

    // MARK: - Deadlines

    var deadlines: [Deadline] {
        get { load(forKey: StorageKey.deadlines) ?? [] }
        set { save(newValue, forKey: StorageKey.deadlines) }
    }

    func addDeadline(_ deadline: Deadline) {
        lock.withLock {
            var list = deadlines
            list.append(deadline)
            deadlines = list
        }
    }

    func updateDeadline(_ deadline: Deadline) {
        lock.withLock {
            var list = deadlines
            if let idx = list.firstIndex(where: { $0.id == deadline.id }) {
                list[idx] = deadline
            }
            deadlines = list
        }
    }

    func removeDeadline(id: UUID) {
        lock.withLock {
            deadlines = deadlines.filter { $0.id != id }
        }
    }

    // MARK: - Notifications

    var notifications: [AtlasNotification] {
        get { load(forKey: StorageKey.notifications) ?? [] }
        set { save(newValue, forKey: StorageKey.notifications) }
    }

    func addNotification(_ n: AtlasNotification) {
        lock.withLock {
            var list = notifications
            list.insert(n, at: 0)
            if list.count > 100 { list = Array(list.prefix(100)) }
            notifications = list
        }
    }

    func markNotificationRead(id: UUID) {
        lock.withLock {
            var list = notifications
            if let idx = list.firstIndex(where: { $0.id == id }) {
                let old = list[idx]
                list[idx] = AtlasNotification(
                    id: old.id, type: old.type, title: old.title,
                    body: old.body, relatedId: old.relatedId,
                    isRead: true, createdAt: old.createdAt
                )
            }
            notifications = list
        }
    }

    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    // MARK: - Private helpers

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func load<T: Decodable>(forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
}
