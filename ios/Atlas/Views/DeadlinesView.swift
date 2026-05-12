import SwiftUI

struct DeadlinesView: View {
    @State private var deadlines: [Deadline] = []
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if deadlines.isEmpty {
                    ContentUnavailableView(
                        "No deadlines",
                        systemImage: "checklist",
                        description: Text("Tap + to add a deadline or task.")
                    )
                } else {
                    List {
                        ForEach(deadlines.sorted { $0.dueDate < $1.dueDate }) { deadline in
                            DeadlineRow(deadline: deadline, onComplete: { complete(deadline) })
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Deadlines")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet, onDismiss: reload) {
                AddDeadlineSheet()
            }
            .onAppear { reload() }
        }
    }

    private func reload() {
        deadlines = SharedStorage.shared.deadlines.filter { !$0.completed }
    }

    private func complete(_ deadline: Deadline) {
        var updated = deadline
        updated.completed = true
        SharedStorage.shared.updateDeadline(updated)
        LocalNotificationService.shared.cancelDeadlineReminder(deadlineId: deadline.id)
        reload()
    }

    private func delete(at offsets: IndexSet) {
        let sorted = deadlines.sorted { $0.dueDate < $1.dueDate }
        for idx in offsets {
            SharedStorage.shared.removeDeadline(id: sorted[idx].id)
        }
        reload()
    }
}

struct DeadlineRow: View {
    let deadline: Deadline
    let onComplete: () -> Void

    var isUrgent: Bool {
        deadline.dueDate.timeIntervalSinceNow < 86400
    }

    var priorityColor: Color {
        switch deadline.priority {
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onComplete) {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(deadline.title)
                    .font(.body).fontWeight(.medium)
                Label(deadline.dueDate.formatted(.relative(presentation: .named)), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(isUrgent ? .red : .secondary)
                if let desc = deadline.description {
                    Text(desc).font(.caption2).foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(deadline.priority.rawValue.capitalized)
                .font(.caption2).fontWeight(.medium)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(priorityColor.opacity(0.15))
                .foregroundStyle(priorityColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}

struct AddDeadlineSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var dueDate = Date().addingTimeInterval(86400)
    @State private var description = ""
    @State private var priority: Deadline.Priority = .medium

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    DatePicker("Due", selection: $dueDate)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3)
                }
                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(Deadline.Priority.allCases, id: \.self) { p in
                            Text(p.rawValue.capitalized).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Deadline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let deadline = Deadline(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            dueDate: dueDate,
            description: description.isEmpty ? nil : description,
            priority: priority,
            completed: false,
            createdAt: Date()
        )
        SharedStorage.shared.addDeadline(deadline)
        LocalNotificationService.shared.scheduleDeadlineReminder(
            title: deadline.title,
            dueDate: deadline.dueDate,
            deadlineId: deadline.id
        )
        dismiss()
    }
}
