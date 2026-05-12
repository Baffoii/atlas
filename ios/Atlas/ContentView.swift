import SwiftUI

struct ContentView: View {
    @EnvironmentObject var calendarService: CalendarService
    @State private var selectedTab = 0

    var unreadCount: Int { SharedStorage.shared.unreadNotificationCount }
    var pendingCount: Int { SharedStorage.shared.awaitingReviewEvents.count }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .badge(pendingCount > 0 ? pendingCount : 0)
                .tag(0)

            PendingReviewView()
                .tabItem { Label("Review", systemImage: "tray.and.arrow.down") }
                .badge(pendingCount)
                .tag(1)

            DeadlinesView()
                .tabItem { Label("Deadlines", systemImage: "checklist") }
                .tag(2)

            NotificationsView()
                .tabItem { Label("Alerts", systemImage: "bell") }
                .badge(unreadCount > 0 ? unreadCount : 0)
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
        .accentColor(.indigo)
        .task {
            await calendarService.requestAccess()
            await LocalNotificationService.shared.requestPermission()
        }
    }
}
