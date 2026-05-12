import SwiftUI

struct NotificationsView: View {
    @State private var notifications: [AtlasNotification] = []

    var body: some View {
        NavigationStack {
            Group {
                if notifications.isEmpty {
                    ContentUnavailableView(
                        "No notifications",
                        systemImage: "bell.slash",
                        description: Text("Conflict warnings and event alerts will appear here.")
                    )
                } else {
                    List {
                        ForEach(notifications) { n in
                            NotificationRow(notification: n)
                                .onTapGesture { markRead(n) }
                                .listRowBackground(n.isRead ? Color.clear : Color.indigo.opacity(0.06))
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Alerts")
            .toolbar {
                if notifications.contains(where: { !$0.isRead }) {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Mark all read") { markAllRead() }
                            .font(.subheadline)
                    }
                }
            }
            .onAppear { reload() }
        }
    }

    private func reload() {
        notifications = SharedStorage.shared.notifications
    }

    private func markRead(_ n: AtlasNotification) {
        SharedStorage.shared.markNotificationRead(id: n.id)
        reload()
    }

    private func markAllRead() {
        for n in notifications where !n.isRead {
            SharedStorage.shared.markNotificationRead(id: n.id)
        }
        reload()
    }
}

struct NotificationRow: View {
    let notification: AtlasNotification

    var icon: String {
        switch notification.type {
        case .eventAdded:       return "calendar.badge.checkmark"
        case .conflict:         return "exclamationmark.triangle"
        case .pendingReview:    return "tray.and.arrow.down"
        case .deadlineReminder: return "clock.badge.exclamationmark"
        case .extractionError:  return "exclamationmark.circle"
        }
    }

    var iconColor: Color {
        switch notification.type {
        case .eventAdded:       return .green
        case .conflict:         return .red
        case .pendingReview:    return .orange
        case .deadlineReminder: return .blue
        case .extractionError:  return .orange
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(.subheadline).fontWeight(notification.isRead ? .regular : .semibold)
                Text(notification.body)
                    .font(.caption).foregroundStyle(.secondary)
                Text(notification.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            if !notification.isRead {
                Spacer()
                Circle()
                    .fill(Color.indigo)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 2)
        .opacity(notification.isRead ? 0.7 : 1)
    }
}
