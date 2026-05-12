import SwiftUI
import EventKit

struct MessageExtensionView: View {
    let calendarStore: EKEventStore
    let isCompact: Bool
    let onExpand: () -> Void
    let onCollapse: () -> Void

    @State private var monitoringOn = SharedStorage.shared.monitoringEnabled
    @State private var clipboardText = ""
    @State private var processing = false
    @State private var lastResult: ProcessResult? = nil
    @State private var pendingCount = SharedStorage.shared.awaitingReviewEvents.count
    @State private var pendingEvents: [PendingEvent] = []
    @State private var processingPendingId: UUID? = nil

    var body: some View {
        if isCompact {
            compactView
        } else {
            expandedView
        }
    }

    // MARK: - Compact view (always visible in the app tray bar)

    var compactView: some View {
        HStack(spacing: 12) {
            // Atlas logo / toggle indicator
            Button(action: toggleMonitoring) {
                HStack(spacing: 6) {
                    Image(systemName: monitoringOn
                          ? "antenna.radiowaves.left.and.right"
                          : "antenna.radiowaves.left.and.right.slash")
                        .foregroundStyle(monitoringOn ? .green : .secondary)
                        .font(.system(size: 18, weight: .medium))
                    Text("Atlas")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(monitoringOn ? .primary : .secondary)
                }
            }
            .buttonStyle(.plain)

            Divider().frame(height: 22)

            // Paste & process
            Button(action: pasteAndProcess) {
                if processing {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Checking…").font(.system(size: 13))
                    }
                } else if let result = lastResult, result.isActionable {
                    Image(systemName: resultIcon(result))
                        .foregroundStyle(resultColor(result))
                        .font(.system(size: 15, weight: .medium))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                        Text("Process")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(monitoringOn ? .indigo : .secondary)
                }
            }
            .disabled(!monitoringOn || processing)
            .buttonStyle(.plain)

            Spacer()

            // Pending badge + expand
            if pendingCount > 0 {
                Button(action: onExpand) {
                    HStack(spacing: 4) {
                        Text("\(pendingCount)")
                            .font(.caption).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.orange)
                            .clipShape(Capsule())
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onExpand) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - Expanded view (full screen when user taps expand)

    var expandedView: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Toggle row
                HStack {
                    Label(monitoringOn ? "Atlas is on" : "Atlas is off",
                          systemImage: monitoringOn ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(monitoringOn ? .green : .secondary)
                    Spacer()
                    Toggle("", isOn: $monitoringOn)
                        .labelsHidden()
                        .tint(.green)
                        .onChange(of: monitoringOn) { _, val in
                            SharedStorage.shared.monitoringEnabled = val
                        }
                }
                .padding()
                .background(Color(.systemGray6))

                // Process from clipboard
                Button(action: pasteAndProcess) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Process copied message")
                        Spacer()
                        if processing { ProgressView().scaleEffect(0.8) }
                    }
                    .padding()
                    .background(Color.indigo.opacity(0.1))
                    .foregroundStyle(monitoringOn ? .indigo : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
                .disabled(!monitoringOn || processing)
                .buttonStyle(.plain)

                // Last result
                if let result = lastResult {
                    HStack {
                        Image(systemName: resultIcon(result))
                            .foregroundStyle(resultColor(result))
                        Text(result.displayMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Pending review list
                if !pendingEvents.isEmpty {
                    Text("Needs review")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 16)

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(pendingEvents) { event in
                                MiniPendingCard(
                                    event: event,
                                    isProcessing: processingPendingId == event.id,
                                    onApprove: { approvePending(event) },
                                    onDismiss: { dismissPending(event) }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Spacer()
                    if monitoringOn {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal")
                                .font(.largeTitle).foregroundStyle(.green)
                            Text("All clear").font(.headline)
                            Text("Copy a message and tap 'Process' above.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
            .navigationTitle("Atlas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onCollapse) {
                        Image(systemName: "chevron.down")
                    }
                }
            }
        }
        .onAppear { reloadPending() }
    }

    // MARK: - Actions

    private func toggleMonitoring() {
        monitoringOn.toggle()
        SharedStorage.shared.monitoringEnabled = monitoringOn
    }

    private func pasteAndProcess() {
        let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            lastResult = .ignored("Nothing on clipboard — copy a message first.")
            return
        }
        clipboardText = text
        processing = true
        lastResult = nil

        let store = calendarStore
        Task {
            let r = await ProcessorService.shared.process(
                body: text,
                sender: "iMessage",
                source: .iMessage,
                calendarStore: store
            )
            await MainActor.run {
                lastResult = r
                processing = false
                reloadPending()
            }
        }
    }

    private func approvePending(_ event: PendingEvent) {
        processingPendingId = event.id
        let store = calendarStore
        Task {
            _ = await ProcessorService.shared.approvePending(id: event.id, calendarStore: store)
            await MainActor.run {
                processingPendingId = nil
                reloadPending()
            }
        }
    }

    private func dismissPending(_ event: PendingEvent) {
        Task {
            await ProcessorService.shared.dismissPending(id: event.id)
            await MainActor.run { reloadPending() }
        }
    }

    private func reloadPending() {
        pendingEvents = SharedStorage.shared.awaitingReviewEvents
        pendingCount = pendingEvents.count
    }

    // MARK: - Helpers

    private func resultIcon(_ r: ProcessResult) -> String {
        switch r {
        case .added:         return "calendar.badge.checkmark"
        case .pendingReview: return "tray.and.arrow.down"
        case .conflict:      return "exclamationmark.triangle"
        default:             return "minus.circle"
        }
    }

    private func resultColor(_ r: ProcessResult) -> Color {
        switch r {
        case .added:         return .green
        case .pendingReview: return .orange
        case .conflict:      return .red
        default:             return .secondary
        }
    }
}

// MARK: - Mini pending card (for use inside iMessage extension)

struct MiniPendingCard: View {
    let event: PendingEvent
    let isProcessing: Bool
    let onApprove: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title)
                .font(.subheadline).fontWeight(.semibold)
            if let date = event.date {
                Text("\(date)\(event.startTime.map { " · \($0)" } ?? "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(""\(event.reasoningSummary)"")
                .font(.caption2).foregroundStyle(.tertiary).italic()
                .lineLimit(2)

            HStack(spacing: 8) {
                Button(action: onApprove) {
                    Group {
                        if isProcessing {
                            ProgressView().tint(.white).scaleEffect(0.7)
                        } else {
                            Text("Add")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isProcessing)

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isProcessing)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .buttonStyle(.plain)
    }
}
