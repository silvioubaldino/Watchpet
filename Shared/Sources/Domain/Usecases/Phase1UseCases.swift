// MARK: - Phase 1 UseCases
// Regras de negócio da Fase 1 MVP (AyD v2.0, Seção 3).
// Cada UseCase tem uma única responsabilidade e depende apenas de protocolos.
// Testáveis isoladamente com mocks.

import Foundation
import UserNotifications

// MARK: - CreateReminderUseCase

public final class CreateReminderUseCase {

    private let repository: ReminderRepository
    private let notificationCenter: UNUserNotificationCenter

    public init(
        repository: ReminderRepository,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.repository = repository
        self.notificationCenter = notificationCenter
    }

    public struct Input {
        public let title: String
        public let triggerDate: Date
        public let repeatInterval: TimeInterval?
        public let isProactive: Bool

        public init(
            title: String,
            triggerDate: Date,
            repeatInterval: TimeInterval? = nil,
            isProactive: Bool = false
        ) {
            self.title = title
            self.triggerDate = triggerDate
            self.repeatInterval = repeatInterval
            self.isProactive = isProactive
        }
    }

    public func execute(_ input: Input) async throws -> Reminder {
        let reminder = Reminder(
            title: input.title,
            triggerDate: input.triggerDate,
            repeatInterval: input.repeatInterval,
            isProactive: input.isProactive
        )

        try await repository.save(reminder)
        try await scheduleNotification(for: reminder)

        return reminder
    }

    private func scheduleNotification(for reminder: Reminder) async throws {
        let content = UNMutableNotificationContent()
        content.title = "🐾 \(reminder.title)"
        content.body = "Seu pet lembrou você!"
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: reminder.repeatInterval != nil
        )

        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }
}

// MARK: - CancelReminderUseCase

public final class CancelReminderUseCase {

    private let repository: ReminderRepository
    private let notificationCenter: UNUserNotificationCenter

    public init(
        repository: ReminderRepository,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.repository = repository
        self.notificationCenter = notificationCenter
    }

    public func execute(id: UUID) async throws {
        try await repository.delete(id: id)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
}

// MARK: - SnoozeReminderUseCase

public final class SnoozeReminderUseCase {

    private let repository: ReminderRepository
    private let createReminder: CreateReminderUseCase

    public init(repository: ReminderRepository, createReminder: CreateReminderUseCase) {
        self.repository = repository
        self.createReminder = createReminder
    }

    /// Adia o lembrete mais recente por `minutes` minutos.
    public func execute(reminderID: UUID, minutes: Int = 10) async throws -> Reminder {
        let newDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        try await repository.markCompleted(id: reminderID)

        // Busca o lembrete original para copiar o título
        let all = try await repository.fetchAll()
        let original = all.first { $0.id == reminderID }

        return try await createReminder.execute(.init(
            title: original?.title ?? "Lembrete",
            triggerDate: newDate
        ))
    }
}

// MARK: - FetchRemindersUseCase

public final class FetchRemindersUseCase {

    private let repository: ReminderRepository

    public init(repository: ReminderRepository) {
        self.repository = repository
    }

    public func executePending() async throws -> [Reminder] {
        try await repository.fetchPending()
    }

    public func executeForToday() async throws -> [Reminder] {
        try await repository.fetchByDate(Date())
    }
}

// MARK: - CreateTimerUseCase

public final class CreateTimerUseCase {

    private let repository: TimerRepository
    private let habitRepository: HabitLogRepository

    public init(repository: TimerRepository, habitRepository: HabitLogRepository) {
        self.repository = repository
        self.habitRepository = habitRepository
    }

    public struct Input {
        public let duration: TimeInterval
        public let label: String?
        public let type: TimerType

        public init(duration: TimeInterval, label: String? = nil, type: TimerType = .custom) {
            self.duration = duration
            self.label = label
            self.type = type
        }

        /// Atalho para Pomodoro padrão (25 minutos)
        public static var pomodoro: Input {
            Input(duration: 25 * 60, label: "Foco", type: .focus)
        }

        /// Atalho para timer de hidratação (60 minutos)
        public static var hydration: Input {
            Input(duration: 60 * 60, label: "Água", type: .water)
        }
    }

    public func execute(_ input: Input) async throws -> TimerRecord {
        // Encerra timer ativo se existir (apenas um timer por vez)
        if let active = try await repository.fetchActive() {
            try await repository.markCompleted(id: active.id)
        }

        let timer = TimerRecord(
            duration: input.duration,
            label: input.label,
            type: input.type
        )

        try await repository.save(timer)
        return timer
    }
}

// MARK: - CompleteTimerUseCase

public final class CompleteTimerUseCase {

    private let timerRepository: TimerRepository
    private let habitRepository: HabitLogRepository

    public init(timerRepository: TimerRepository, habitRepository: HabitLogRepository) {
        self.timerRepository = timerRepository
        self.habitRepository = habitRepository
    }

    public func execute(timerID: UUID, type: TimerType) async throws {
        try await timerRepository.markCompleted(id: timerID)

        // Registra hábito correspondente
        switch type {
        case .focus:   try await habitRepository.incrementPomodoro()
        case .water:   try await habitRepository.incrementHydration()
        case .custom:  break
        }
    }
}

// MARK: - SaveNoteUseCase

public final class SaveNoteUseCase {

    private let noteRepository: NoteRepository
    private let habitRepository: HabitLogRepository
    private let syncQueueRepository: SyncQueueRepository

    public init(
        noteRepository: NoteRepository,
        habitRepository: HabitLogRepository,
        syncQueueRepository: SyncQueueRepository
    ) {
        self.noteRepository = noteRepository
        self.habitRepository = habitRepository
        self.syncQueueRepository = syncQueueRepository
    }

    public struct Input {
        public let rawText: String
        public let category: String?
        public let connectorID: String?  // nil = não sincroniza externamente

        public init(rawText: String, category: String? = nil, connectorID: String? = nil) {
            self.rawText = rawText
            self.category = category
            self.connectorID = connectorID
        }
    }

    public func execute(_ input: Input) async throws -> Note {
        let note = Note(
            rawText: input.rawText,
            category: input.category ?? detectCategory(from: input.rawText)
        )

        try await noteRepository.save(note)
        try await habitRepository.incrementNotes()

        // Enfileira para sync externo se solicitado
        if let connectorID = input.connectorID {
            let syncItem = SyncQueueItem(
                entityType: .note,
                entityID: note.id,
                operation: .create,
                connectorID: connectorID
            )
            try await syncQueueRepository.enqueue(syncItem)
        }

        return note
    }

    /// Categorização automática simples por palavras-chave (Fase 1).
    /// Fase 2: substituir por classificação via LLM.
    private func detectCategory(from text: String) -> String? {
        let lower = text.lowercased()
        if ["reunião", "projeto", "cliente", "deadline", "task"].contains(where: lower.contains) { return "trabalho" }
        if ["remédio", "médico", "treino", "água", "dormir"].contains(where: lower.contains) { return "saúde" }
        if ["comprar", "mercado", "loja", "lista"].contains(where: lower.contains) { return "compras" }
        if ["estudar", "ler", "livro", "curso"].contains(where: lower.contains) { return "estudos" }
        return nil
    }
}

// MARK: - LogHabitUseCase

public final class LogHabitUseCase {

    private let habitRepository: HabitLogRepository
    private let reminderRepository: ReminderRepository
    private let healthKitManager: HealthKitManager

    public init(habitRepository: HabitLogRepository, reminderRepository: ReminderRepository, healthKitManager: HealthKitManager = .shared) {
        self.habitRepository = habitRepository
        self.reminderRepository = reminderRepository
        self.healthKitManager = healthKitManager
    }

    public enum HabitType {
        case hydration
        case posture
    }

    public func execute(_ type: HabitType) async throws -> HabitLog {
        switch type {
        case .hydration: 
            try await habitRepository.incrementHydration()
            // Log 250ml by default when saying "drank water"
            try? await healthKitManager.logWater(ml: 250.0)
        case .posture:   
            try await habitRepository.incrementPosture()
        }
        return try await habitRepository.logForToday()
    }
}

// MARK: - GetDailySummaryUseCase

public final class GetDailySummaryUseCase {

    private let habitRepository: HabitLogRepository
    private let reminderRepository: ReminderRepository
    private let noteRepository: NoteRepository

    public init(
        habitRepository: HabitLogRepository,
        reminderRepository: ReminderRepository,
        noteRepository: NoteRepository
    ) {
        self.habitRepository = habitRepository
        self.reminderRepository = reminderRepository
        self.noteRepository = noteRepository
    }

    public struct DailySummary {
        public let habitLog: HabitLog
        public let pendingReminders: [Reminder]
        public let todayNotes: [Note]
        public let hydrationProgress: Double  // 0.0 – 1.0
        public let hydrationGoal: Int

        public var summaryText: String {
            var parts: [String] = []
            parts.append("Água: \(habitLog.hydrationCheckins)/\(hydrationGoal)")
            parts.append("Pomodoros: \(habitLog.pomodoroCount)")
            parts.append("Pausas: \(habitLog.postureBreaks)")
            parts.append("Notas: \(habitLog.notesCreated)")
            if !pendingReminders.isEmpty {
                parts.append("Lembretes pendentes: \(pendingReminders.count)")
            }
            return parts.joined(separator: " • ")
        }
    }

    public func execute(hydrationGoal: Int = 8) async throws -> DailySummary {
        async let log = habitRepository.logForToday()
        async let reminders = reminderRepository.fetchByDate(Date())
        async let notes = noteRepository.fetchByDate(Date())

        let (habitLog, pendingReminders, todayNotes) = try await (log, reminders, notes)

        return DailySummary(
            habitLog: habitLog,
            pendingReminders: pendingReminders.filter { !$0.isCompleted },
            todayNotes: todayNotes,
            hydrationProgress: min(1.0, Double(habitLog.hydrationCheckins) / Double(hydrationGoal)),
            hydrationGoal: hydrationGoal
        )
    }
}

// MARK: - SaveConversationUseCase

public final class SaveConversationUseCase {

    private let repository: ConversationRepository

    public init(repository: ConversationRepository) {
        self.repository = repository
    }

    public func execute(
        transcript: String,
        response: String,
        intent: IntentType,
        emotion: PetEmotion
    ) async throws {
        let conversation = Conversation(
            transcript: transcript,
            llmResponse: response,
            intentType: intent,
            petEmotion: emotion
        )
        try await repository.save(conversation)
    }
}
