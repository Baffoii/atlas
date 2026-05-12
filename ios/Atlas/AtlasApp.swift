import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct AtlasApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(CalendarService.shared)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        LocalNotificationService.shared.registerCategories()
        registerBackgroundTasks()
        return true
    }

    // MARK: - Background tasks

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BGTaskID.processQueue,
            using: nil
        ) { task in
            self.handleProcessQueueTask(task as! BGAppRefreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BGTaskID.deadlineCheck,
            using: nil
        ) { task in
            self.handleDeadlineCheckTask(task as! BGProcessingTask)
        }
    }

    private func handleProcessQueueTask(_ task: BGAppRefreshTask) {
        scheduleProcessQueueTask()

        let operation = Task {
            let queue = SharedStorage.shared.dequeueAll()
            let calendarService = await CalendarService.shared

            for message in queue {
                SharedStorage.shared.updateMessageStatus(id: message.id, status: .processing)
                _ = await ProcessorService.shared.process(
                    body: message.body,
                    sender: message.sender,
                    source: message.source,
                    timestamp: message.timestamp,
                    calendarStore: await calendarService.store
                )
                SharedStorage.shared.updateMessageStatus(id: message.id, status: .classified)
            }
        }

        task.expirationHandler = { operation.cancel() }
        Task {
            await operation.value
            task.setTaskCompleted(success: true)
        }
    }

    private func handleDeadlineCheckTask(_ task: BGProcessingTask) {
        let deadlines = SharedStorage.shared.deadlines.filter { !$0.completed }
        let now = Date()

        for deadline in deadlines {
            let hoursUntil = deadline.dueDate.timeIntervalSince(now) / 3600
            if hoursUntil > 0 && hoursUntil <= 48 {
                let n = AtlasNotification(
                    id: UUID(), type: .deadlineReminder,
                    title: hoursUntil <= 24 ? "Deadline today" : "Upcoming deadline",
                    body: "\"\(deadline.title)\" is due \(deadline.dueDate.formatted(.relative(presentation: .named))).",
                    relatedId: deadline.id, isRead: false, createdAt: now
                )
                SharedStorage.shared.addNotification(n)
                LocalNotificationService.shared.scheduleDeadlineReminder(
                    title: deadline.title,
                    dueDate: deadline.dueDate,
                    deadlineId: deadline.id
                )
            }
        }

        task.setTaskCompleted(success: true)
    }

    func scheduleProcessQueueTask() {
        let request = BGAppRefreshTaskRequest(identifier: BGTaskID.processQueue)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    func scheduleDeadlineCheckTask() {
        let request = BGProcessingTaskRequest(identifier: BGTaskID.deadlineCheck)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Notification delegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
