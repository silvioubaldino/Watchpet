// MARK: - AppContainer Phase 1
// Atualiza o container com repositórios CoreData reais e UseCases da Fase 1.
// Substitui o AppContainer da Fase 0 (que usava apenas mocks).

import Foundation
import CoreData

// MARK: - WatchAppContainer (Phase 1)

@MainActor
public final class WatchAppContainerV1: ObservableObject {

    // MARK: Infrastructure
    public let speechTranscriber: SpeechTranscriber
    public let intentClassifier: IntentClassifierProtocol
    public let persistence: PersistenceController

    // MARK: Domain Managers
    public let petStateManager: PetStateManager

    // MARK: Repositories
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

    // MARK: UseCases — Habit
    public let logHabit: LogHabitUseCase
    public let getDailySummary: GetDailySummaryUseCase

    // MARK: UseCases — Conversation
    public let saveConversation: SaveConversationUseCase

    // MARK: - Init (Produção)

    public init(inMemory: Bool = false, locale: Locale = Locale(identifier: "pt-BR")) {
        let persistence = PersistenceController(inMemory: inMemory)
        self.persistence = persistence
        let ctx = persistence.viewContext

        // Repositories
        let noteRepo = CoreDataNoteRepository(context: ctx)
        let reminderRepo = CoreDataReminderRepository(context: ctx)
        let timerRepo = CoreDataTimerRepository(context: ctx)
        let habitRepo = CoreDataHabitLogRepository(context: ctx)
        let conversationRepo = CoreDataConversationRepository(context: ctx)
        let syncQueueRepo = CoreDataSyncQueueRepository(context: ctx)
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
        self.logHabit = LogHabitUseCase(habitRepository: habitRepo, reminderRepository: reminderRepo)
        self.getDailySummary = GetDailySummaryUseCase(
            habitRepository: habitRepo,
            reminderRepository: reminderRepo,
            noteRepository: noteRepo
        )
        self.saveConversation = SaveConversationUseCase(repository: conversationRepo)

        // Pet
        let pet = PetStateManager()
        pet.configure(profile: profileRepo.load())
        self.petStateManager = pet
    }

    // MARK: - Preview (in-memory)

    public static var preview: WatchAppContainerV1 {
        WatchAppContainerV1(inMemory: true)
    }
}
