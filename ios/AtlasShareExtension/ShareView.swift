import SwiftUI
import EventKit

struct ShareView: View {
    let messageText: String
    let source: QueuedMessage.MessageSource
    let calendarStore: EKEventStore
    let onDone: () -> Void
    let onCancel: () -> Void

    @State private var editableText: String
    @State private var state: ShareState = .idle
    @State private var result: ProcessResult? = nil
    @State private var senderName: String = ""

    enum ShareState {
        case idle, processing, done, disabled, noApiKey
    }

    init(messageText: String, source: QueuedMessage.MessageSource, calendarStore: EKEventStore, onDone: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.messageText = messageText
        self.source = source
        self.calendarStore = calendarStore
        self.onDone = onDone
        self.onCancel = onCancel
        _editableText = State(initialValue: messageText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status banner
                if !SharedStorage.shared.monitoringEnabled {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        Text("Atlas monitoring is off")
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Source badge
                        HStack {
                            Image(systemName: sourceIcon)
                                .foregroundStyle(sourceColor)
                            Text("From \(source.rawValue)")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                        }

                        // Sender
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sender (optional)")
                                .font(.caption).foregroundStyle(.secondary)
                            TextField("Who sent this?", text: $senderName)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Message text
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Message")
                                .font(.caption).foregroundStyle(.secondary)
                            TextEditor(text: $editableText)
                                .frame(minHeight: 100)
                                .padding(6)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Result card
                        if let result {
                            ResultCard(result: result)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding()
                }

                // Action buttons
                VStack(spacing: 10) {
                    Button(action: process) {
                        Group {
                            if state == .processing {
                                HStack {
                                    ProgressView().tint(.white)
                                    Text("Classifying…")
                                }
                            } else {
                                Label("Process with Atlas", systemImage: "sparkles")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProcess ? Color.indigo : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canProcess)

                    Button(state == .done ? "Done" : "Cancel") {
                        state == .done ? onDone() : onCancel()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Atlas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
        .onAppear {
            if !(SharedStorage.shared.geminiApiKey?.isEmpty == false) {
                state = .noApiKey
            } else if !SharedStorage.shared.monitoringEnabled {
                state = .disabled
            } else if !messageText.isEmpty {
                process()
            }
        }
        .animation(.easeOut(duration: 0.25), value: result == nil)
    }

    // MARK: - Processing

    private var canProcess: Bool {
        state != .processing && !editableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && SharedStorage.shared.monitoringEnabled
            && (SharedStorage.shared.geminiApiKey?.isEmpty == false)
    }

    private func process() {
        guard canProcess else { return }
        state = .processing
        result = nil

        let text = editableText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sender = senderName.isEmpty ? source.rawValue : senderName
        let store = calendarStore

        Task {
            let r = await ProcessorService.shared.process(
                body: text,
                sender: sender,
                source: source,
                calendarStore: store
            )
            await MainActor.run {
                result = r
                state = .done
            }
        }
    }

    // MARK: - Helpers

    private var sourceIcon: String {
        switch source {
        case .whatsApp:   return "bubble.left.fill"
        case .messenger:  return "message.fill"
        case .instagram:  return "camera.fill"
        case .iMessage:   return "message.fill"
        default:          return "square.and.arrow.up"
        }
    }

    private var sourceColor: Color {
        switch source {
        case .whatsApp:  return .green
        case .messenger: return .blue
        case .instagram: return .purple
        case .iMessage:  return .blue
        default:         return .gray
        }
    }
}

struct ResultCard: View {
    let result: ProcessResult

    var icon: String {
        switch result {
        case .added:         return "calendar.badge.checkmark"
        case .pendingReview: return "tray.and.arrow.down"
        case .conflict:      return "exclamationmark.triangle"
        case .ignored:       return "minus.circle"
        case .skipped:       return "pause.circle"
        case .error:         return "xmark.circle"
        }
    }

    var color: Color {
        switch result {
        case .added:         return .green
        case .pendingReview: return .orange
        case .conflict:      return .red
        default:             return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(result.displayMessage)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
