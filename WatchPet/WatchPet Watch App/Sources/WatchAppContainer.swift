import Foundation
import Observation
import WatchPetShared

@Observable
@MainActor
public final class WatchAppContainer {

    // MARK: Infrastructure
    public let speechTranscriber: SpeechTranscriber
    public let intentClassifier: IntentClassifierProtocol
    public let persistence: PersistenceController

    // MARK: Repositories
    public let noteRepository: NoteRepository
    public let reminderRepository: ReminderRepository
    public let timerRepository: TimerRepository
    public let userProfileRepository: UserProfileRepository
    public let habitLogRepository: HabitLogRepository
    public let conversationRepository: ConversationRepository
    public let syncQueueRepository: SyncQueueRepository

    // MARK: UseCases
    public let createReminder: CreateReminderUseCase
    public let cancelReminder: CancelReminderUseCase
    public let snoozeReminder: SnoozeReminderUseCase
    public let fetchReminders: FetchRemindersUseCase
    public let createTimer: CreateTimerUseCase
    public let completeTimer: CompleteTimerUseCase
    public let saveNote: SaveNoteUseCase
    public let fetchNotes: FetchNotesUseCase
    public let logHabit: LogHabitUseCase
    public let getDailySummary: GetDailySummaryUseCase
    public let saveConversation: SaveConversationUseCase

    public init(inMemory: Bool = false, locale: Locale = Locale(identifier: "pt-BR")) {
        let persistence = PersistenceController(inMemory: inMemory)
        self.persistence = persistence
        let context = persistence.viewContext

        self.noteRepository = CoreDataNoteRepository(context: context)
        self.reminderRepository = CoreDataReminderRepository(context: context)
        self.timerRepository = CoreDataTimerRepository(context: context)
        self.userProfileRepository = UserDefaultsProfileRepository()
        self.habitLogRepository = CoreDataHabitLogRepository(context: context)
        self.conversationRepository = CoreDataConversationRepository(context: context)
        self.syncQueueRepository = CoreDataSyncQueueRepository(context: context)

        self.speechTranscriber = SpeechTranscriber(locale: locale)
        self.intentClassifier = RuleBasedIntentClassifier()

        let createReminderUC = CreateReminderUseCase(repository: reminderRepository)
        self.createReminder = createReminderUC
        self.cancelReminder = CancelReminderUseCase(repository: reminderRepository)
        self.snoozeReminder = SnoozeReminderUseCase(repository: reminderRepository, createReminder: createReminderUC)
        self.fetchReminders = FetchRemindersUseCase(repository: reminderRepository)
        self.createTimer = CreateTimerUseCase(repository: timerRepository, habitRepository: habitLogRepository)
        self.completeTimer = CompleteTimerUseCase(timerRepository: timerRepository, habitRepository: habitLogRepository)
        self.saveNote = SaveNoteUseCase(
            noteRepository: noteRepository,
            habitRepository: habitLogRepository,
            syncQueueRepository: syncQueueRepository
        )
        self.fetchNotes = FetchNotesUseCase(noteRepository: noteRepository)
        self.logHabit = LogHabitUseCase(habitRepository: habitLogRepository, reminderRepository: reminderRepository)
        self.getDailySummary = GetDailySummaryUseCase(
            habitRepository: habitLogRepository,
            reminderRepository: reminderRepository,
            noteRepository: noteRepository
        )
        self.saveConversation = SaveConversationUseCase(repository: conversationRepository)
    }
}

#if DEBUG
public extension WatchAppContainer {
    static var preview: WatchAppContainer {
        WatchAppContainer(inMemory: true)
    }
}
#endif
