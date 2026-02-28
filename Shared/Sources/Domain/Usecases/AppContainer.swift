// MARK: - AppContainer
// Container de injeção de dependências (DI).
// Instancia e injeta todos os serviços, repositórios e casos de uso do app.

import Foundation
import CoreData

// MARK: - WatchAppContainer

/// Container principal do Apple Watch target.
@MainActor
public final class WatchAppContainer: ObservableObject {

    // MARK: Infrastructure
    public let speechTranscriber: SpeechTranscriber
    public let intentClassifier: IntentClassifierProtocol
    public let persistence: PersistenceController

    // MARK: Domain Managers
    public let petStateManager: PetStateManager

    // MARK: Repositories (injetados via protocolo)
    public let noteRepository: NoteRepository
    public let reminderRepository: ReminderRepository
    public let timerRepository: TimerRepository
    public let userProfileRepository: UserProfileRepository
    public let habitLogRepository: HabitLogRepository
    public let conversationRepository: ConversationRepository
    public let syncQueueRepository: SyncQueueRepository

    // MARK: UseCases — Reminder
    public let createReminder: CreateReminderUseCase
    public let cancelReminder: CancelReminderUseCase
    public let snoozeReminder: SnoozeReminderUseCase
    public let fetchReminders: FetchRemindersUseCase

    // MARK: UseCases — Timer
    public let createTimer: CreateTimerUseCase
    public let completeTimer: CompleteTimerUseCase

    // MARK: UseCases — Note
    public let saveNote: SaveNoteUseCase
    public let fetchNotes: FetchNotesUseCase

    // MARK: UseCases — Habit
    public let logHabit: LogHabitUseCase
    public let getDailySummary: GetDailySummaryUseCase

    // MARK: UseCases — Conversation
    public let saveConversation: SaveConversationUseCase

    // MARK: - Initialization

    /// Inicializador para produção ou pré-visualização.
    /// - Parameters:
    ///   - inMemory: Se verdadeiro, usa o banco de dados em memória (para testes/previews).
    ///   - locale: Localidade para reconhecimento de voz.
    public init(inMemory: Bool = false, locale: Locale = Locale(identifier: "pt-BR")) {
        // Persistence
        let persistence = PersistenceController(inMemory: inMemory)
        self.persistence = persistence
        let context = persistence.viewContext

        // Repositories
        let noteRepo = CoreDataNoteRepository(context: context)
        let reminderRepo = CoreDataReminderRepository(context: context)
        let timerRepo = CoreDataTimerRepository(context: context)
        let habitRepo = CoreDataHabitLogRepository(context: context)
        let conversationRepo = CoreDataConversationRepository(context: context)
        let syncQueueRepo = CoreDataSyncQueueRepository(context: context)
        let profileRepo = UserDefaultsProfileRepository()

        self.noteRepository = noteRepo
        self.reminderRepository = reminderRepo
        self.timerRepository = timerRepo
        self.userProfileRepository = profileRepo
        self.habitLogRepository = habitRepo
        self.conversationRepository = conversationRepo
        self.syncQueueRepository = syncQueueRepo

        // Infrastructure
        self.speechTranscriber = SpeechTranscriber(locale: locale)
        self.intentClassifier = RuleBasedIntentClassifier()

        // UseCases
        let createReminderUC = CreateReminderUseCase(repository: reminderRepo)
        self.createReminder = createReminderUC
        self.cancelReminder = CancelReminderUseCase(repository: reminderRepo)
        self.snoozeReminder = SnoozeReminderUseCase(repository: reminderRepo, createReminder: createReminderUC)
        self.fetchReminders = FetchRemindersUseCase(repository: reminderRepo)
        self.createTimer = CreateTimerUseCase(repository: timerRepo, habitRepository: habitRepo)
        self.completeTimer = CompleteTimerUseCase(timerRepository: timerRepo, habitRepository: habitRepo)
        self.saveNote = SaveNoteUseCase(
            noteRepository: noteRepo,
            habitRepository: habitRepo,
            syncQueueRepository: syncQueueRepo
        )
        self.fetchNotes = FetchNotesUseCase(noteRepository: noteRepo)
        self.logHabit = LogHabitUseCase(habitRepository: habitRepo, reminderRepository: reminderRepo)
        self.getDailySummary = GetDailySummaryUseCase(
            habitRepository: habitRepo,
            reminderRepository: reminderRepo,
            noteRepository: noteRepo
        )
        self.saveConversation = SaveConversationUseCase(repository: conversationRepo)

        // Pet
        self.petStateManager = PetStateManager()
        self.petStateManager.configure(profile: profileRepo.load())
    }
}

// MARK: - iOSAppContainer

/// Container principal do iPhone companion app.
@MainActor
public final class iOSAppContainer: ObservableObject {

    // MARK: Integration
    public let integrationRegistry: IntegrationRegistry
    public let oauthManager: OAuthManager
    public let syncEngine: SyncEngine

    // MARK: Persistence
    public let persistence: PersistenceController

    // MARK: Repositories
    public let noteRepository: NoteRepository
    public let reminderRepository: ReminderRepository
    public let syncQueueRepository: SyncQueueRepository
    public let integrationConfigRepository: IntegrationConfigRepository

    public init(inMemory: Bool = false) {
        let persistence = PersistenceController(inMemory: inMemory)
        self.persistence = persistence
        let context = persistence.viewContext

        let noteRepo = CoreDataNoteRepository(context: context)
        let reminderRepo = CoreDataReminderRepository(context: context)
        let syncQueueRepo = CoreDataSyncQueueRepository(context: context)
        let integrationRepo = CoreDataIntegrationConfigRepository(context: context)

        self.noteRepository = noteRepo
        self.reminderRepository = reminderRepo
        self.syncQueueRepository = syncQueueRepo
        self.integrationConfigRepository = integrationRepo

        self.integrationRegistry = .shared
        self.oauthManager = .shared
        self.syncEngine = SyncEngine(
            syncQueueRepo: syncQueueRepo,
            noteRepo: noteRepo,
            reminderRepo: reminderRepo
        )
    }
}

// MARK: - Preview Support

#if DEBUG
public extension WatchAppContainer {
    static var preview: WatchAppContainer {
        WatchAppContainer(inMemory: true)
    }
}

public extension iOSAppContainer {
    static var preview: iOSAppContainer {
        iOSAppContainer(inMemory: true)
    }
}
#endif
