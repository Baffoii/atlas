import SwiftUI
import EventKit

struct SettingsView: View {
    @EnvironmentObject var calendarService: CalendarService
    @State private var apiKey = SharedStorage.shared.geminiApiKey ?? ""
    @State private var monitoringEnabled = SharedStorage.shared.monitoringEnabled
    @State private var selectedCalendarId = SharedStorage.shared.selectedCalendarId
    @State private var showApiKeySaved = false

    var body: some View {
        NavigationStack {
            Form {
                // ── Monitoring ──────────────────────────────────────────────
                Section {
                    Toggle(isOn: $monitoringEnabled) {
                        Label("Monitoring", systemImage: monitoringEnabled
                              ? "antenna.radiowaves.left.and.right"
                              : "antenna.radiowaves.left.and.right.slash")
                    }
                    .onChange(of: monitoringEnabled) { _, val in
                        SharedStorage.shared.monitoringEnabled = val
                    }
                } header: {
                    Text("Atlas")
                } footer: {
                    Text(monitoringEnabled
                         ? "Atlas is active. Share a message from WhatsApp, Messenger, or Instagram via the Share Sheet, or tap the Atlas icon inside any iMessage conversation."
                         : "Monitoring is paused. No messages will be processed.")
                }

                // ── Gemini API key ──────────────────────────────────────────
                Section {
                    SecureField("Gemini API key", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Save API key") {
                        SharedStorage.shared.geminiApiKey = apiKey.isEmpty ? nil : apiKey
                        showApiKeySaved = true
                    }
                    .disabled(apiKey == (SharedStorage.shared.geminiApiKey ?? ""))
                } header: {
                    Text("Gemini")
                } footer: {
                    Text("Get your key at aistudio.google.com. The key is stored in the shared app group container.")
                }
                .alert("Saved", isPresented: $showApiKeySaved) {
                    Button("OK") {}
                }

                // ── Calendar ────────────────────────────────────────────────
                Section("Calendar") {
                    switch calendarService.authorizationStatus {
                    case .notDetermined:
                        Button("Grant calendar access") {
                            Task { await calendarService.requestAccess() }
                        }
                    case .fullAccess, .writeOnly:
                        if calendarService.availableCalendars.isEmpty {
                            Text("No writable calendars found").foregroundStyle(.secondary)
                        } else {
                            Picker("Default calendar", selection: $selectedCalendarId) {
                                Text("System default").tag(Optional<String>.none)
                                ForEach(calendarService.availableCalendars, id: \.calendarIdentifier) { cal in
                                    Text(cal.title).tag(Optional(cal.calendarIdentifier))
                                }
                            }
                            .onChange(of: selectedCalendarId) { _, val in
                                SharedStorage.shared.selectedCalendarId = val
                            }
                        }
                    default:
                        Text("Calendar access denied. Enable in iOS Settings > Privacy > Calendars.")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                // ── How it works ────────────────────────────────────────────
                Section("How to use") {
                    InfoRow(icon: "message.fill", color: .green,
                            title: "iMessage",
                            detail: "Open any conversation → tap the Atlas icon in the app tray → copy a message → tap Process.")
                    InfoRow(icon: "square.and.arrow.up", color: .blue,
                            title: "WhatsApp / Messenger / Instagram",
                            detail: "Long-press any message → Share → Atlas. If monitoring is on, it processes automatically.")
                    InfoRow(icon: "calendar.badge.checkmark", color: .indigo,
                            title: "Calendar",
                            detail: "Confirmed plans (confidence ≥ 85%) go straight to your calendar. Lower confidence → Review tab.")
                    InfoRow(icon: "exclamationmark.triangle.fill", color: .orange,
                            title: "Conflicts",
                            detail: "If a new event overlaps an existing one, Atlas warns you before adding.")
                }

                // ── Data ─────────────────────────────────────────────────────
                Section("Data") {
                    HStack {
                        Text("Events tracked")
                        Spacer()
                        Text("\(SharedStorage.shared.calendarEvents.count)").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Pending review")
                        Spacer()
                        Text("\(SharedStorage.shared.awaitingReviewEvents.count)").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct InfoRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(color)
            Text(detail)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
