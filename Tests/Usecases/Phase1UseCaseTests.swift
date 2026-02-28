// MARK: - Phase 1 UseCase Unit Tests
// Testes unitários para os UseCases da Fase 1.
// Usam mocks dos repositórios (definidos na Fase 0) — sem dependência de CoreData.

import XCTest
@testable import WatchPetShared

// MARK: - CreateReminderUseCaseTests

final class CreateReminderUseCaseTests: XCTestCase {

    var reminderRepo: MockReminderRepository!
    var notificationCenter: MockNotificationCenter!
    var sut: CreateReminderUseCase!

    override func setUp() {
        super.setUp()
        reminderRepo = MockReminderRepository()
        notificationCenter = MockNotificationCenter()
        sut = CreateReminderUseCase(
            repository: reminderRepo,
            notificationCenter: notificationCenter as! UNUserNotificationCenter
        )
    }

    func test_execute_savesReminderWithCorrectTitle() async throws {
        let input = CreateReminderUseCase.Input(
            title: "Beber água",
            triggerDate: Date().addingTimeInterval(3600)
        )

        let reminder = try await sut.execute(input)

        XCTAssertEqual(reminder.title, "Beber água")
        XCTAssertFalse(reminder.id.uuidString.isEmpty)
        XCTAssertEqual(reminderRepo.reminders.count, 3) // 2 sample + 1 novo
    }

    func test_execute_setsRepeatInterval_whenProvided() async throws {
        let input = CreateReminderUseCase.Input(
            title: "Água",
            triggerDate: Date().addingTimeInterval(60),
            repeatInterval: 3600
        )

        let reminder = try await sut.execute(input)

        XCTAssertEqual(reminder.repeatInterval, 3600)
    }

    func test_execute_noRepeat_whenIntervalNil() async throws {
        let input = CreateReminderUseCase.Input(
            title: "Reunião única",
            triggerDate: Date().addingTimeInterval(3600)
        )

        let reminder = try await sut.execute(input)

        XCTAssertNil(reminder.repeatInterval)
    }
}

// MARK: - CancelReminderUseCaseTests

final class CancelReminderUseCaseTests: XCTestCase {

    var reminderRepo: MockReminderRepository!
    var sut: CancelReminderUseCase!

    override func setUp() {
        super.setUp()
        reminderRepo = MockReminderRepository()
        sut = CancelReminderUseCase(repository: reminderRepo)
    }

    func test_execute_removesReminderFromRepository() async throws {
        let targetID = reminderRepo.reminders[0].id
        let initialCount = reminderRepo.reminders.count

        try await sut.execute(id: targetID)

        XCTAssertEqual(reminderRepo.reminders.count, initialCount - 1)
        XCTAssertFalse(reminderRepo.reminders.contains { $0.id == targetID })
    }
}

// MARK: - CreateTimerUseCaseTests

final class CreateTimerUseCaseTests: XCTestCase {

    var timerRepo: MockTimerRepository!
    var habitRepo: MockHabitLogRepository!
    var sut: CreateTimerUseCase!

    override func setUp() {
        super.setUp()
        timerRepo = MockTimerRepository()
        habitRepo = MockHabitLogRepository()
        sut = CreateTimerUseCase(repository: timerRepo, habitRepository: habitRepo)
    }

    func test_execute_createsTimerWithCorrectDuration() async throws {
        let input = CreateTimerUseCase.Input(duration: 25 * 60, label: "Pomodoro", type: .focus)

        let timer = try await sut.execute(input)

        XCTAssertEqual(timer.duration, 25 * 60)
        XCTAssertEqual(timer.label, "Pomodoro")
        XCTAssertEqual(timer.type, .focus)
    }

    func test_execute_pomodoroShortcut_has25MinDuration() async throws {
        let timer = try await sut.execute(.pomodoro)

        XCTAssertEqual(timer.duration, 25 * 60)
        XCTAssertEqual(timer.type, .focus)
    }

    func test_execute_completesActiveTimerBeforeCreatingNew() async throws {
        // Cria primeiro timer
        _ = try await sut.execute(.init(duration: 10 * 60))
        XCTAssertEqual(timerRepo.timers.count, 1)

        // Cria segundo — deve completar o primeiro
        _ = try await sut.execute(.init(duration: 5 * 60))

        let activeTimers = timerRepo.timers.filter { $0.isRunning }
        XCTAssertEqual(activeTimers.count, 1)
        XCTAssertEqual(activeTimers.first?.duration, 5 * 60)
    }
}

// MARK: - CompleteTimerUseCaseTests

final class CompleteTimerUseCaseTests: XCTestCase {

    var timerRepo: MockTimerRepository!
    var habitRepo: MockHabitLogRepository!
    var sut: CompleteTimerUseCase!

    override func setUp() {
        super.setUp()
        timerRepo = MockTimerRepository()
        habitRepo = MockHabitLogRepository()
        sut = CompleteTimerUseCase(timerRepository: timerRepo, habitRepository: habitRepo)
    }

    func test_execute_focus_incrementsPomodoroCount() async throws {
        let timer = TimerRecord(duration: 25 * 60, type: .focus)
        try await timerRepo.save(timer)

        try await sut.execute(timerID: timer.id, type: .focus)

        XCTAssertEqual(habitRepo.log.pomodoroCount, 1)
    }

    func test_execute_water_incrementsHydrationCount() async throws {
        let timer = TimerRecord(duration: 60 * 60, type: .water)
        try await timerRepo.save(timer)

        try await sut.execute(timerID: timer.id, type: .water)

        XCTAssertEqual(habitRepo.log.hydrationCheckins, 1)
    }

    func test_execute_custom_doesNotIncrementAnyHabit() async throws {
        let timer = TimerRecord(duration: 5 * 60, type: .custom)
        try await timerRepo.save(timer)

        try await sut.execute(timerID: timer.id, type: .custom)

        XCTAssertEqual(habitRepo.log.pomodoroCount, 0)
        XCTAssertEqual(habitRepo.log.hydrationCheckins, 0)
    }
}

// MARK: - SaveNoteUseCaseTests

final class SaveNoteUseCaseTests: XCTestCase {

    var noteRepo: MockNoteRepository!
    var habitRepo: MockHabitLogRepository!
    var syncQueueRepo: MockSyncQueueRepository!
    var sut: SaveNoteUseCase!

    override func setUp() {
        super.setUp()
        noteRepo = MockNoteRepository()
        habitRepo = MockHabitLogRepository()
        syncQueueRepo = MockSyncQueueRepository()
        sut = SaveNoteUseCase(
            noteRepository: noteRepo,
            habitRepository: habitRepo,
            syncQueueRepository: syncQueueRepo
        )
    }

    func test_execute_savesNoteWithRawText() async throws {
        let input = SaveNoteUseCase.Input(rawText: "Reunião amanhã às 14h")

        let note = try await sut.execute(input)

        XCTAssertEqual(note.rawText, "Reunião amanhã às 14h")
        XCTAssertFalse(note.id.uuidString.isEmpty)
    }

    func test_execute_autoDetectsCategory_trabalho() async throws {
        let input = SaveNoteUseCase.Input(rawText: "Reunião com o cliente sobre o projeto")

        let note = try await sut.execute(input)

        XCTAssertEqual(note.category, "trabalho")
    }

    func test_execute_autoDetectsCategory_saude() async throws {
        let input = SaveNoteUseCase.Input(rawText: "Tomar remédio depois do treino")

        let note = try await sut.execute(input)

        XCTAssertEqual(note.category, "saúde")
    }

    func test_execute_incrementsNotesHabit() async throws {
        let initialCount = habitRepo.log.notesCreated
        _ = try await sut.execute(.init(rawText: "Qualquer nota"))

        XCTAssertEqual(habitRepo.log.notesCreated, initialCount + 1)
    }

    func test_execute_withConnectorID_enqueuesToSyncQueue() async throws {
        _ = try await sut.execute(.init(rawText: "Nota importante", connectorID: "notion"))

        XCTAssertEqual(syncQueueRepo.items.count, 1)
        XCTAssertEqual(syncQueueRepo.items.first?.connectorID, "notion")
        XCTAssertEqual(syncQueueRepo.items.first?.operation, .create)
    }

    func test_execute_withoutConnectorID_doesNotEnqueue() async throws {
        _ = try await sut.execute(.init(rawText: "Nota local"))

        XCTAssertEqual(syncQueueRepo.items.count, 0)
    }
}

// MARK: - LogHabitUseCaseTests

final class LogHabitUseCaseTests: XCTestCase {

    var habitRepo: MockHabitLogRepository!
    var reminderRepo: MockReminderRepository!
    var sut: LogHabitUseCase!

    override func setUp() {
        super.setUp()
        habitRepo = MockHabitLogRepository()
        reminderRepo = MockReminderRepository()
        sut = LogHabitUseCase(habitRepository: habitRepo, reminderRepository: reminderRepo)
    }

    func test_execute_hydration_incrementsCheckins() async throws {
        let log = try await sut.execute(.hydration)
        XCTAssertEqual(log.hydrationCheckins, 1)
    }

    func test_execute_posture_incrementsPostureBreaks() async throws {
        let log = try await sut.execute(.posture)
        XCTAssertEqual(log.postureBreaks, 1)
    }

    func test_execute_multipleHydrations_accumulatesCorrectly() async throws {
        _ = try await sut.execute(.hydration)
        _ = try await sut.execute(.hydration)
        let log = try await sut.execute(.hydration)

        XCTAssertEqual(log.hydrationCheckins, 3)
    }
}

// MARK: - RuleBasedIntentClassifierTests

final class RuleBasedIntentClassifierTests: XCTestCase {

    var sut: RuleBasedIntentClassifier!

    override func setUp() {
        super.setUp()
        sut = RuleBasedIntentClassifier()
    }

    func test_classify_timerIntent() {
        let result = sut.classify("timer de 25 minutos")
        XCTAssertEqual(result.type, .timer)
        XCTAssertEqual(result.extractedEntities.duration, 25 * 60)
    }

    func test_classify_timerWithLabel() {
        let result = sut.classify("timer de 3 minutos pro café")
        XCTAssertEqual(result.type, .timer)
        XCTAssertEqual(result.extractedEntities.timerLabel, "café")
    }

    func test_classify_reminderIntent() {
        let result = sut.classify("me lembra de beber água")
        XCTAssertEqual(result.type, .reminder)
    }

    func test_classify_noteIntent() {
        let result = sut.classify("anota: reunião amanhã às 14h")
        XCTAssertEqual(result.type, .note)
    }

    func test_classify_noteWithNotion() {
        let result = sut.classify("salva essa nota no notion")
        XCTAssertEqual(result.type, .note)
        XCTAssertEqual(result.extractedEntities.connectorID, "notion")
    }

    func test_classify_habitHydration() {
        let result = sut.classify("bebi água")
        XCTAssertEqual(result.type, .habit)
    }

    func test_classify_settingsRename() {
        let result = sut.classify("muda seu nome para Rex")
        XCTAssertEqual(result.type, .settings)
        XCTAssertEqual(result.extractedEntities.petName, "Rex")
    }

    func test_classify_unknownFallsToConversation() {
        let result = sut.classify("olá, tudo bem?")
        XCTAssertEqual(result.type, .conversation)
    }

    func test_classify_durationExtraction_seconds() {
        let result = sut.classify("timer de 30 segundos")
        XCTAssertEqual(result.extractedEntities.duration, 30)
    }

    func test_classify_durationExtraction_hours() {
        let result = sut.classify("timer de 1 hora")
        XCTAssertEqual(result.extractedEntities.duration, 3600)
    }
}

// MARK: - Mock UNUserNotificationCenter

final class MockNotificationCenter {
    var scheduledRequests: [String] = []
    var removedRequests: [String] = []

    func add(_ request: UNNotificationRequest) async throws {
        scheduledRequests.append(request.identifier)
    }

    func removePendingNotificationRequests(withIdentifiers ids: [String]) {
        removedRequests.append(contentsOf: ids)
    }
}
