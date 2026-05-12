import SwiftUI

struct PendingReviewView: View {
    @EnvironmentObject var calendarService: CalendarService
    @State private var pending: [PendingEvent] = []
    @State private var processingId: UUID? = nil
    @State private var alertMessage: String? = nil
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if pending.isEmpty {
                    ContentUnavailableView(
                        "Nothing to review",
                        systemImage: "tray",
                        description: Text("Atlas will ask for your input when it's not sure about an event.")
                    )
                } else {
                    List {
                        ForEach(pending) { event in
                            PendingEventCard(
                                event: event,
                                isProcessing: processingId == event.id,
                                onApprove: { approve(event) },
                                onDismiss: { dismiss(event) }
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Review (\(pending.count))")
            .onAppear { reload() }
            .alert("Atlas", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func reload() {
        pending = SharedStorage.shared.awaitingReviewEvents
    }

    private func approve(_ event: PendingEvent) {
        processingId = event.id
        Task {
            let result = await ProcessorService.shared.approvePending(
                id: event.id,
                calendarStore: calendarService.store
            )
            await MainActor.run {
                processingId = nil
                if case .conflict(let names) = result {
                    alertMessage = "Conflict with \(names). The event was left in review."
                    showAlert = true
                }
                reload()
            }
        }
    }

    private func dismiss(_ event: PendingEvent) {
        Task {
            await ProcessorService.shared.dismissPending(id: event.id)
            await MainActor.run { reload() }
        }
    }
}

struct PendingEventCard: View {
    let event: PendingEvent
    let isProcessing: Bool
    let onApprove: () -> Void
    let onDismiss: () -> Void

    var confidenceColor: Color {
        switch event.confidence {
        case ConfidenceLevel.autoAdd...: return .green
        case ConfidenceLevel.pendingReview..<ConfidenceLevel.autoAdd: return .orange
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title)
                    .font(.body).fontWeight(.semibold)
                Spacer()
                Text("\(event.confidenceLabel) \(Int(event.confidence * 100))%")
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(confidenceColor.opacity(0.15))
                    .foregroundStyle(confidenceColor)
                    .clipShape(Capsule())
            }

            if let date = event.date {
                Label("\(date)\(event.startTime.map { " at \($0)" } ?? "")", systemImage: "calendar")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if let loc = event.location {
                Label(loc, systemImage: "mappin").font(.subheadline).foregroundStyle(.secondary)
            }
            if !event.participants.isEmpty {
                Label(event.participants.joined(separator: ", "), systemImage: "person.2")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Text(""\(event.reasoningSummary)"")
                .font(.caption).foregroundStyle(.tertiary).italic()

            HStack(spacing: 10) {
                Button(action: onApprove) {
                    Group {
                        if isProcessing {
                            ProgressView().tint(.white)
                        } else {
                            Label("Add to Calendar", systemImage: "calendar.badge.plus")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(isProcessing)

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .disabled(isProcessing)
            }

            Label("from \(event.source.rawValue)", systemImage: "message")
                .font(.caption2).foregroundStyle(.quaternary)
        }
        .padding(.vertical, 4)
    }
}
