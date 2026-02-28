// MARK: - Repository Protocols
// Interfaces da camada de domínio — implementadas na camada de dados.
// O domínio nunca depende de CoreData, CloudKit ou qualquer framework externo.

import Foundation
import Combine

// MARK: - ConversationRepository

public protocol ConversationRepository {
    func save(_ conversation: Conversation) async throws
    func fetchAll(limit: Int) async throws -> [Conversation]
    func fetchByIntent(_ intent: IntentType, limit: Int) async throws -> [Conversation]
    func deleteAll() async throws
}

// MARK: - NoteRepository

public protocol NoteRepository {
    func save(_ note: Note) async throws
    func update(_ note: Note) async throws
    func delete(id: UUID) async throws
    func fetchAll() async throws -> [Note]
    func fetchByDate(_ date: Date) async throws -> [Note]
    func search(query: String) async throws -> [Note]
    func fetchUnsyncedNotes() async throws -> [Note]
    func markSynced(id: UUID, externalID: String, connectorID: String) async throws
}

// MARK: - ReminderRepository

public protocol ReminderRepository {
    func save(_ reminder: Reminder) async throws
    func update(_ reminder: Reminder) async throws
    func delete(id: UUID) async throws
    func fetchAll() async throws -> [Reminder]
    func fetchPending() async throws -> [Reminder]
    func fetchByDate(_ date: Date) async throws -> [Reminder]
    func markCompleted(id: UUID) async throws
}

// MARK: - TimerRepository

public protocol TimerRepository {
    func save(_ timer: TimerRecord) async throws
    func update(_ timer: TimerRecord) async throws
    func fetchActive() async throws -> TimerRecord?
    func fetchAll(limit: Int) async throws -> [TimerRecord]
    func markCompleted(id: UUID) async throws
}

// MARK: - UserProfileRepository

public protocol UserProfileRepository {
    func load() -> UserProfile
    func save(_ profile: UserProfile)
}

// MARK: - HabitLogRepository

public protocol HabitLogRepository {
    func logForToday() async throws -> HabitLog
    func save(_ log: HabitLog) async throws
    func fetchLast(days: Int) async throws -> [HabitLog]
    func incrementHydration() async throws
    func incrementPosture() async throws
    func incrementPomodoro() async throws
    func incrementNotes() async throws
}

// MARK: - SyncQueueRepository

public protocol SyncQueueRepository {
    func enqueue(_ item: SyncQueueItem) async throws
    func fetchPending(connectorID: String?) async throws -> [SyncQueueItem]
    func updateStatus(id: UUID, status: SyncStatus) async throws
    func scheduleRetry(id: UUID) async throws
    func remove(id: UUID) async throws
    func countPending() async throws -> Int
}

// MARK: - IntegrationConfigRepository

public protocol IntegrationConfigRepository {
    func fetchAll() async throws -> [IntegrationConfig]
    func fetch(connectorID: String) async throws -> IntegrationConfig?
    func save(_ config: IntegrationConfig) async throws
    func update(_ config: IntegrationConfig) async throws
    func delete(connectorID: String) async throws
}
