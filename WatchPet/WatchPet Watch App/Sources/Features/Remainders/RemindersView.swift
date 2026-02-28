import WatchPetShared
// MARK: - RemindersView
// Tela de lembretes no Apple Watch — lista, criação rápida e ações.
// (AyD v2.0, Seção 3.1 — Módulo ⏰ Lembretes Inteligentes)

import SwiftUI
import Combine

// MARK: - RemindersViewModel

@MainActor
public final class RemindersViewModel: ObservableObject {

    @Published public private(set) var reminders: [Reminder] = []
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?

    private let fetchUC: FetchRemindersUseCase
    private let cancelUC: CancelReminderUseCase
    private let snoozeUC: SnoozeReminderUseCase
    private let createUC: CreateReminderUseCase

    public init(container: WatchAppContainer) {
        self.fetchUC = container.fetchReminders
        self.cancelUC = container.cancelReminder
        self.snoozeUC = container.snoozeReminder
        self.createUC = container.createReminder
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            reminders = try await fetchUC.executePending()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func cancel(id: UUID) async {
        do {
            try await cancelUC.execute(id: id)
            reminders.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func snooze(id: UUID) async {
        do {
            let newReminder = try await snoozeUC.execute(reminderID: id, minutes: 10)
            reminders.removeAll { $0.id == id }
            reminders.append(newReminder)
            reminders.sort { $0.triggerDate < $1.triggerDate }
            #if os(watchOS)
            WKInterfaceDevice.current().play(.success)
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createQuick(title: String, inMinutes: Int) async {
        do {
            let reminder = try await createUC.execute(.init(
                title: title,
                triggerDate: Date().addingTimeInterval(TimeInterval(inMinutes * 60))
            ))
            reminders.append(reminder)
            reminders.sort { $0.triggerDate < $1.triggerDate }
            #if os(watchOS)
            WKInterfaceDevice.current().play(.success)
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - RemindersView

public struct RemindersView: View {

    @StateObject private var viewModel: RemindersViewModel
    @State private var showQuickAdd = false

    public init(container: WatchAppContainer) {
        _viewModel = StateObject(wrappedValue: RemindersViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Carregando...")
                } else if viewModel.reminders.isEmpty {
                    emptyState
                } else {
                    remindersList
                }
            }
            .navigationTitle("⏰ Lembretes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showQuickAdd = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddReminderView(viewModel: viewModel, isPresented: $showQuickAdd)
            }
        }
        .task { await viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🎉")
                .font(.title)
            Text("Nenhum lembrete pendente")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var remindersList: some View {
        List {
            ForEach(viewModel.reminders) { reminder in
                ReminderRowView(
                    reminder: reminder,
                    onSnooze: { Task { await viewModel.snooze(id: reminder.id) } },
                    onCancel: { Task { await viewModel.cancel(id: reminder.id) } }
                )
            }
        }
        #if os(watchOS)
        .listStyle(.carousel)
        #endif
    }
}

// MARK: - ReminderRowView

struct ReminderRowView: View {

    let reminder: Reminder
    let onSnooze: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(reminder.title)
                .font(.caption.bold())
                .lineLimit(2)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(reminder.triggerDate.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if reminder.repeatInterval != nil {
                    Image(systemName: "repeat")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }

            HStack(spacing: 6) {
                Button("Snooze", action: onSnooze)
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .font(.caption2)

                Button("Cancelar", action: onCancel)
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .font(.caption2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - QuickAddReminderView

struct QuickAddReminderView: View {

    @ObservedObject var viewModel: RemindersViewModel
    @Binding var isPresented: Bool

    private let quickOptions: [(String, Int)] = [
        ("💧 Água em 1h", 60),
        ("🧘 Pausa em 30min", 30),
        ("💊 Remédio em 8h", 480),
        ("📋 Reunião em 2h", 120),
    ]

    var body: some View {
        List {
            ForEach(quickOptions, id: \.0) { title, minutes in
                Button {
                    Task {
                        await viewModel.createQuick(title: title, inMinutes: minutes)
                        isPresented = false
                    }
                } label: {
                    Text(title)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Novo Lembrete")
    }
}

// MARK: - Preview

#Preview("Reminders") {
    RemindersView(container: .preview)
}
