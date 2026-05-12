import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var calendarService: CalendarService
    @State private var events: [AtlasCalendarEvent] = []
    @State private var refreshTick = UUID()

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No upcoming events",
                        systemImage: "calendar.badge.plus",
                        description: Text("Confirmed plans from your messages will appear here.")
                    )
                } else {
                    List {
                        ForEach(groupedByDate, id: \.key) { section in
                            Section(header: Text(section.key).font(.subheadline).fontWeight(.semibold)) {
                                ForEach(section.events) { event in
                                    EventRow(event: event)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Atlas")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    MonitoringToggleButton()
                }
            }
            .onAppear { reload() }
            .refreshable { reload() }
        }
    }

    private func reload() {
        events = calendarService.upcomingAtlasEvents
    }

    private var groupedByDate: [(key: String, events: [AtlasCalendarEvent])] {
        let grouped = Dictionary(grouping: events, by: \.date)
        return grouped.keys.sorted().map { key in
            (key: formatDate(key), events: grouped[key]!.sorted { $0.startTime < $1.startTime })
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: dateStr) else { return dateStr }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        df.dateFormat = "EEEE, MMM d"
        return df.string(from: date)
    }
}

struct EventRow: View {
    let event: AtlasCalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.body)
                .fontWeight(.medium)
            HStack(spacing: 8) {
                Label("\(event.startTime) – \(event.endTime)", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let loc = event.location {
                    Label(loc, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if !event.participants.isEmpty {
                Label(event.participants.joined(separator: ", "), systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct MonitoringToggleButton: View {
    @State private var isOn = SharedStorage.shared.monitoringEnabled

    var body: some View {
        Button {
            isOn.toggle()
            SharedStorage.shared.monitoringEnabled = isOn
        } label: {
            Label(isOn ? "On" : "Off", systemImage: isOn ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isOn ? .green : .secondary)
        }
    }
}
