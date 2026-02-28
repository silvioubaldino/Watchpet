// MARK: - AppContainer
// Container de injeção de dependências (DI).
// Instancia e injeta todos os serviços e repositórios do app.
// Padrão: Service Locator simples — pode evoluir para Resolver/Swinject se necessário.

import Foundation

// MARK: - AppContainer (Watch)

/// Container principal do Apple Watch target.
@MainActor
public final class WatchAppContainer: ObservableObject {

    // MARK: - Infrastructure
    public let speechTranscriber: SpeechTranscriber
    public let intentClassifier: IntentClassifierProtocol

    // MARK: - Domain Managers
    public let petStateManager: PetStateManager

    // MARK: - Repositories (injetados via protocolo — mock em testes)
    public let noteRepository: NoteRepository
    public let reminderRepository: ReminderRepository
    public let timerRepository: TimerRepository
    public let userProfileRepository: UserProfileRepository
    public let habitLogRepository: HabitLogRepository
    public let conversationRepository: ConversationRepository
    public let syncQueueRepository: SyncQueueRepository

    public init(
        noteRepository: NoteRepository,
        reminderRepository: ReminderRepository,
        timerRepository: TimerRepository,
        userProfileRepository: UserProfileRepository,
        habitLogRepository: HabitLogRepository,
        conversationRepository: ConversationRepository,
        syncQueueRepository: SyncQueueRepository,
        locale: Locale = Locale(identifier: "pt-BR")
    ) {
        self.noteRepository = noteRepository
        self.reminderRepository = reminderRepository
        self.timerRepository = timerRepository
        self.userProfileRepository = userProfileRepository
        self.habitLogRepository = habitLogRepository
        self.conversationRepository = conversationRepository
        self.syncQueueRepository = syncQueueRepository

        self.speechTranscriber = SpeechTranscriber(locale: locale)
        self.intentClassifier = RuleBasedIntentClassifier()
        self.petStateManager = PetStateManager()

        // Carrega perfil do usuário e configura o pet
        let profile = userProfileRepository.load()
        petStateManager.configure(profile: profile)
    }
}

// MARK: - AppContainer (iPhone)

/// Container principal do iPhone companion app.
@MainActor
public final class iOSAppContainer: ObservableObject {

    // MARK: - Integration
    public let integrationRegistry: IntegrationRegistry
    public let oauthManager: OAuthManager
    public let syncEngine: SyncEngine

    // MARK: - Repositories
    public let noteRepository: NoteRepository
    public let reminderRepository: ReminderRepository
    public let syncQueueRepository: SyncQueueRepository
    public let integrationConfigRepository: IntegrationConfigRepository

    public init(
        noteRepository: NoteRepository,
        reminderRepository: ReminderRepository,
        syncQueueRepository: SyncQueueRepository,
        integrationConfigRepository: IntegrationConfigRepository
    ) {
        self.noteRepository = noteRepository
        self.reminderRepository = reminderRepository
        self.syncQueueRepository = syncQueueRepository
        self.integrationConfigRepository = integrationConfigRepository

        self.integrationRegistry = .shared
        self.oauthManager = .shared
        self.syncEngine = SyncEngine(
            syncQueueRepo: syncQueueRepository,
            noteRepo: noteRepository,
            reminderRepo: reminderRepository
        )
    }
}

// MARK: - Preview / Test Container

#if DEBUG
/// Container com mocks para SwiftUI Previews e testes unitários.
@MainActor
public extension WatchAppContainer {
    static var preview: WatchAppContainer {
        WatchAppContainer(
            noteRepository: MockNoteRepository(),
            reminderRepository: MockReminderRepository(),
            timerRepository: MockTimerRepository(),
            userProfileRepository: MockUserProfileRepository(),
            habitLogRepository: MockHabitLogRepository(),
            conversationRepository: MockConversationRepository(),
            syncQueueRepository: MockSyncQueueRepository()
        )
    }
}

// MARK: - Mock Repositories

final class MockNoteRepository: NoteRepository {
    var notes: [Note] = [
        Note(rawText: "Reunião amanhã às 14h com o time de design", category: "trabalho"),
        Note(rawText: "Comprar proteína depois do treino", tags: ["saude"]),
    ]
    func save(_ note: Note) async throws { notes.append(note) }
    func update(_ note: Note) async throws { notes = notes.map { $0.id == note.id ? note : $0 } }
    func delete(id: UUID) async throws { notes.removeAll { $0.id == id } }
    func fetchAll() async throws -> [Note] { notes }
    func fetchByDate(_ date: Date) async throws -> [Note] { notes }
    func search(query: String) async throws -> [Note] {
        notes.filter { $0.rawText.localizedCaseInsensitiveContains(query) }
    }
    func fetchUnsyncedNotes() async throws -> [Note] { notes.filter { !$0.isSynced } }
    func markSynced(id: UUID, externalID: String, connectorID: String) async throws {
        notes = notes.map {
            guard $0.id == id else { return $0 }
            var updated = $0
            updated.externalIDs[connectorID] = externalID
            updated.isSynced = true
            return updated
        }
    }
}

final class MockReminderRepository: ReminderRepository {
    var reminders: [Reminder] = [
        Reminder(title: "Beber água", triggerDate: Date().addingTimeInterval(3600), repeatInterval: 3600, isProactive: true),
        Reminder(title: "Remédio das 8h", triggerDate: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!),
    ]
    func save(_ reminder: Reminder) async throws { reminders.append(reminder) }
    func update(_ reminder: Reminder) async throws { reminders = reminders.map { $0.id == reminder.id ? reminder : $0 } }
    func delete(id: UUID) async throws { reminders.removeAll { $0.id == id } }
    func fetchAll() async throws -> [Reminder] { reminders }
    func fetchPending() async throws -> [Reminder] { reminders.filter { !$0.isCompleted } }
    func fetchByDate(_ date: Date) async throws -> [Reminder] { reminders }
    func markCompleted(id: UUID) async throws {
        reminders = reminders.map {
            guard $0.id == id else { return $0 }
            var updated = $0
            updated.completedAt = Date()
            return updated
        }
    }
}

final class MockTimerRepository: TimerRepository {
    var timers: [TimerRecord] = []
    func save(_ timer: TimerRecord) async throws { timers.append(timer) }
    func update(_ timer: TimerRecord) async throws { timers = timers.map { $0.id == timer.id ? timer : $0 } }
    func fetchActive() async throws -> TimerRecord? { timers.first { $0.isRunning } }
    func fetchAll(limit: Int) async throws -> [TimerRecord] { Array(timers.prefix(limit)) }
    func markCompleted(id: UUID) async throws {
        timers = timers.map {
            guard $0.id == id else { return $0 }
            var updated = $0
            updated.completedAt = Date()
            return updated
        }
    }
}

final class MockUserProfileRepository: UserProfileRepository {
    var profile: UserProfile = .default
    func load() -> UserProfile { profile }
    func save(_ profile: UserProfile) { self.profile = profile }
}

final class MockHabitLogRepository: HabitLogRepository {
    var log = HabitLog()
    func logForToday() async throws -> HabitLog { log }
    func save(_ log: HabitLog) async throws { self.log = log }
    func fetchLast(days: Int) async throws -> [HabitLog] { [log] }
    func incrementHydration() async throws { log.hydrationCheckins += 1 }
    func incrementPosture() async throws { log.postureBreaks += 1 }
    func incrementPomodoro() async throws { log.pomodoroCount += 1 }
    func incrementNotes() async throws { log.notesCreated += 1 }
}

final class MockConversationRepository: ConversationRepository {
    var conversations: [Conversation] = []
    func save(_ c: Conversation) async throws { conversations.append(c) }
    func fetchAll(limit: Int) async throws -> [Conversation] { Array(conversations.prefix(limit)) }
    func fetchByIntent(_ intent: IntentType, limit: Int) async throws -> [Conversation] {
        Array(conversations.filter { $0.intentType == intent }.prefix(limit))
    }
    func deleteAll() async throws { conversations = [] }
}

final class MockSyncQueueRepository: SyncQueueRepository {
    var items: [SyncQueueItem] = []
    func enqueue(_ item: SyncQueueItem) async throws { items.append(item) }
    func fetchPending(connectorID: String?) async throws -> [SyncQueueItem] {
        items.filter { $0.status == .pending && (connectorID == nil || $0.connectorID == connectorID) }
    }
    func updateStatus(id: UUID, status: SyncStatus) async throws {
        items = items.map { $0.id == id ? SyncQueueItem(id: $0.id, entityType: $0.entityType, entityID: $0.entityID, operation: $0.operation, connectorID: $0.connectorID, status: status, retryCount: $0.retryCount) : $0 }
    }
    func scheduleRetry(id: UUID) async throws {}
    func remove(id: UUID) async throws { items.removeAll { $0.id == id } }
    func countPending() async throws -> Int { items.filter { $0.status == .pending }.count }
}
#endif
