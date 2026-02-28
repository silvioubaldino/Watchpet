// MARK: - CoreData Repository Implementations
// Implementações concretas dos protocolos de repositório usando CoreData.
// Injetadas no AppContainer em produção; mocks usados em testes/previews.

import CoreData
import Foundation

// MARK: - CoreDataNoteRepository

public final class CoreDataNoteRepository: NoteRepository {

    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func save(_ note: Note) async throws {
        try await context.perform {
            let cd = CDNote(context: self.context)
            self.map(note, to: cd)
            try self.context.save()
        }
    }

    public func update(_ note: Note) async throws {
        try await context.perform {
            let cd = try self.fetch(id: note.id)
            self.map(note, to: cd)
            try self.context.save()
        }
    }

    public func delete(id: UUID) async throws {
        try await context.perform {
            let cd = try self.fetch(id: id)
            self.context.delete(cd)
            try self.context.save()
        }
    }

    public func fetchAll() async throws -> [Note] {
        try await context.perform {
            let request = CDNote.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            return try self.context.fetch(request).map { $0.toDomain() }
        }
    }

    public func fetchByDate(_ date: Date) async throws -> [Note] {
        try await context.perform {
            let start = Calendar.current.startOfDay(for: date)
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
            let request = CDNote.fetchRequest()
            request.predicate = NSPredicate(format: "createdAt >= %@ AND createdAt < %@", start as CVarArg, end as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            return try self.context.fetch(request).map { $0.toDomain() }
        }
    }

    public func search(query: String) async throws -> [Note] {
        try await context.perform {
            let request = CDNote.fetchRequest()
            request.predicate = NSPredicate(format: "rawText CONTAINS[cd] %@", query)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            return try self.context.fetch(request).map { $0.toDomain() }
        }
    }

    public func fetchUnsyncedNotes() async throws -> [Note] {
        try await context.perform {
            let request = CDNote.fetchRequest()
            request.predicate = NSPredicate(format: "isSynced == NO")
            return try self.context.fetch(request).map { $0.toDomain() }
        }
    }

    public func markSynced(id: UUID, externalID: String, connectorID: String) async throws {
        try await context.perform {
            let cd = try self.fetch(id: id)
            var ids = cd.externalIDs
            ids[connectorID] = externalID
            cd.externalIDs = ids
            cd.isSynced = true
            cd.updatedAt = Date()
            try self.context.save()
        }
    }

    // MARK: - Helpers

    private func fetch(id: UUID) throws -> CDNote {
        let request = CDNote.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        guard let result = try context.fetch(request).first else {
            throw RepositoryError.notFound(id.uuidString)
        }
        return result
    }

    private func map(_ note: Note, to cd: CDNote) {
        cd.id = note.id
        cd.rawText = note.rawText
        cd.category = note.category
        cd.tags = note.tags
        cd.externalIDs = note.externalIDs
        cd.isSynced = note.isSynced
        cd.createdAt = note.createdAt
        cd.updatedAt = note.updatedAt
    }
}

// MARK: - CoreDataReminderRepository

public final class CoreDataReminderRepository: ReminderRepository {

    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func save(_ reminder: Reminder) async throws {
        try await context.perform {
            let cd = CDReminder(context: self.context)
            self.map(reminder, to: cd)
            try self.context.save()
        }
    }

    public func update(_ reminder: Reminder) async throws {
        try await context.perform {
            let cd = try self.fetch(id: reminder.id)
            self.map(reminder, to: cd)
            try self.context.save()
        }
    }

    public func delete(id: UUID) async throws {
        try await context.perform {
            let cd = try self.fetch(id: id)
            self.context.delete(cd)
            try self.context.save()
        }
    }

    public func fetchAll() async throws -> [Reminder] {
        try await context.perform {
            let request = CDReminder.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "triggerDate", ascending: true)]
            return try self.context.fetch(request).map { $0.toDomain() }
        }
    }

    public func fetchPending() async throws -> [Reminder] {
        try await context.perform {
            let request = CDReminder.fetchRequest()
            request.predicate = NSPredicate(format: "completedAt == nil")
            request.sortDescriptors = [NSSortDescriptor(key: "triggerDate", ascending: true)]
            return try self.context.fetch(request).map { $0.toDomain() }
        }
    }

    public func fetchByDate(_ date: Date) async throws -> [Reminder] {
        try await context.perform {
            let start = Calendar.current.startOfDay(for: date)
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
            let request = CDReminder.fetchRequest()
            request.predicate = NSPredicate(
                format: "triggerDate >= %@ AND triggerDate < %@ AND completedAt == nil",
                start as CVarArg, end as CVarArg
            )
            request.sortDescriptors = [NSSortDescriptor(key: "triggerDate", ascending: true)]
            return try self.context.fetch(request).map { $0.toDomain() }
        }
    }

    public func markCompleted(id: UUID) async throws {
        try await context.perform {
            let cd = try self.fetch(id: id)
            cd.completedAt = Date()
            try self.context.save()
        }
    }

    private func fetch(id: UUID) throws -> CDReminder {
        let request = CDReminder.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        guard let result = try context.fetch(request).first else {
            throw RepositoryError.notFound(id.uuidString)
        }
        return result
    }

    private func map(_ reminder: Reminder, to cd: CDReminder) {
        cd.id = reminder.id
        cd.title = reminder.title
        cd.triggerDate = reminder.triggerDate
        cd.repeatInterval = reminder.repeatInterval ?? 0
        cd.isProactive = reminder.isProactive
        cd.completedAt = reminder.completedAt
        cd.linkedEntityID = reminder.linkedEntityID
        cd.externalIDs = reminder.externalIDs
    }
}

// MARK: - CoreDataTimerRepository

public final class CoreDataTimerRepository: TimerRepository {

    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func save(_ timer: TimerRecord) async throws {
        try await context.perform {
            let cd = CDTimerRecord(context: self.context)
            self.map(timer, to: cd)
            try self.context.save()
        }
    }

    public func update(_ timer: TimerRecord) async throws {
        try await context.perform {
            let cd = try self.fetch(id: timer.id)
            self.map(timer, to: cd)
            try self.context.save()
        }
    }

    public func fetchActive() async throws -> TimerRecord? {
        try await context.perform {
            let request = CDTimerRecord.fetchRequest()
            request.predicate = NSPredicate(format: "completedAt == nil")
            request.fetchLimit = 1
            return try self.context.fetch(request).first?.toDomain()
        }
    }

    public func fetchAll(limit: Int) async throws -> [TimerRecord] {
        try await context.perform {
            let request = CDTimerRecord.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            request.fetchLimit = limit
            return try self.context.fetch(request).map { $0.toDomain() }
        }
    }

    public func markCompleted(id: UUID) async throws {
        try await context.perform {
            let cd = try self.fetch(id: id)
            cd.completedAt = Date()
            try self.context.save()
        }
    }

    private func fetch(id: UUID) throws -> CDTimerRecord {
        let request = CDTimerRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        guard let result = try context.fetch(request).first else {
            throw RepositoryError.notFound(id.uuidString)
        }
        return result
    }

    private func map(_ timer: TimerRecord, to cd: CDTimerRecord) {
        cd.id = timer.id
        cd.startedAt = timer.startedAt
        cd.duration = timer.duration
        cd.label = timer.label
        cd.completedAt = timer.completedAt
        cd.type = timer.type
    }
}

// MARK: - CoreDataHabitLogRepository

public final class CoreDataHabitLogRepository: HabitLogRepository {

    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func logForToday() async throws -> HabitLog {
        let today = Calendar.current.startOfDay(for: Date())
        return try await context.perform {
            let request = CDHabitLog.fetchRequest()
            request.predicate = NSPredicate(format: "date == %@", today as CVarArg)
            request.fetchLimit = 1
            if let existing = try self.context.fetch(request).first {
                return existing.toDomain()
            }
            // Cria log do dia se não existir
            let cd = CDHabitLog(context: self.context)
            cd.id = UUID()
            cd.date = today
            try self.context.save()
            return cd.toDomain()
        }
    }

    public func save(_ log: HabitLog) async throws {
        try await context.perform {
            let request = CDHabitLog.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", log.id as CVarArg)
            request.fetchLimit = 1
            let cd = try self.context.fetch(request).first ?? CDHabitLog(context: self.context)
            cd.id = log.id
            cd.date = log.date
            cd.hydrationCheckins = Int32(log.hydrationCheckins)
            cd.postureBreaks = Int32(log.postureBreaks)
            cd.pomodoroCount = Int32(log.pomodoroCount)
            cd.notesCreated = Int32(log.notesCreated)
            try self.context.save()
        }
    }

    public func fetchLast(days: Int) async throws -> [HabitLog] {
        try await context.perform {
            let since = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            let request = CDHabitLog.fetchRequest()
            request.predicate = NSPredicate(format: "date >= %@", since as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            return try self.context.fetch(request).map { $0.toDomain() }
        }
    }

    public func incrementHydration() async throws {
        var log = try await logForToday()
        log.hydrationCheckins += 1
        try await save(log)
    }

    public func incrementPosture() async throws {
        var log = try await logForToday()
        log.postureBreaks += 1
        try await save(log)
    }

    public func incrementPomodoro() async throws {
        var log = try await logForToday()
        log.pomodoroCount += 1
        try await save(log)
    }

    public func incrementNotes() async throws {
        var log = try await logForToday()
        log.notesCreated += 1
        try await save(log)
    }
}

// MARK: - CoreDataConversationRepository

public final class CoreDataConversationRepository: ConversationRepository {

    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func save(_ conversation: Conversation) async throws {
        try await context.perform {
            let cd = CDConversation(context: self.context)
            cd.id = conversation.id
            cd.timestamp = conversation.timestamp
            cd.transcript = conversation.transcript
            cd.llmResponse = conversation.llmResponse
            cd.intentTypeRaw = conversation.intentType.rawValue
            cd.petEmotionRaw = conversation.petEmotion.rawValue
            try self.context.save()
        }
    }

    public func fetchAll(limit: Int) async throws -> [Conversation] {
        try await context.perform {
            let request = CDConversation.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            request.fetchLimit = limit
            return try self.context.fetch(request).map { $0.toDomain() }
        }
    }

    public func fetchByIntent(_ intent: IntentType, limit: Int) async throws -> [Conversation] {
        try await context.perform {
            let request = CDConversation.fetchRequest()
            request.predicate = NSPredicate(format: "intentTypeRaw == %@", intent.rawValue)
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            request.fetchLimit = limit
            return try self.context.fetch(request).map { $0.toDomain() }
        }
    }

    public func deleteAll() async throws {
        try await context.perform {
            let request = CDConversation.fetchRequest()
            let items = try self.context.fetch(request)
            items.forEach { self.context.delete($0) }
            try self.context.save()
        }
    }
}

// MARK: - CoreDataSyncQueueRepository

public final class CoreDataSyncQueueRepository: SyncQueueRepository {

    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func enqueue(_ item: SyncQueueItem) async throws {
        try await context.perform {
            let cd = CDSyncQueueItem(context: self.context)
            self.map(item, to: cd)
            try self.context.save()
        }
    }

    public func fetchPending(connectorID: String?) async throws -> [SyncQueueItem] {
        try await context.perform {
            let request = CDSyncQueueItem.fetchRequest()
            var predicates: [NSPredicate] = [
                NSPredicate(format: "statusRaw IN %@", [SyncStatus.pending.rawValue, SyncStatus.inProgress.rawValue])
            ]
            if let connectorID {
                predicates.append(NSPredicate(format: "connectorID == %@", connectorID))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try self.context.fetch(request).map { $0.toDomain() }
        }
    }

    public func updateStatus(id: UUID, status: SyncStatus) async throws {
        try await context.perform {
            let cd = try self.fetch(id: id)
            cd.statusRaw = status.rawValue
            try self.context.save()
        }
    }

    public func scheduleRetry(id: UUID) async throws {
        try await context.perform {
            let cd = try self.fetch(id: id)
            var item = cd.toDomain()
            item.scheduleRetry()
            cd.statusRaw = item.status.rawValue
            cd.retryCount = Int32(item.retryCount)
            cd.nextRetryAt = item.nextRetryAt
            try self.context.save()
        }
    }

    public func remove(id: UUID) async throws {
        try await context.perform {
            let cd = try self.fetch(id: id)
            self.context.delete(cd)
            try self.context.save()
        }
    }

    public func countPending() async throws -> Int {
        try await context.perform {
            let request = CDSyncQueueItem.fetchRequest()
            request.predicate = NSPredicate(format: "statusRaw == %@", SyncStatus.pending.rawValue)
            return try self.context.count(for: request)
        }
    }

    private func fetch(id: UUID) throws -> CDSyncQueueItem {
        let request = CDSyncQueueItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        guard let result = try context.fetch(request).first else {
            throw RepositoryError.notFound(id.uuidString)
        }
        return result
    }

    private func map(_ item: SyncQueueItem, to cd: CDSyncQueueItem) {
        cd.id = item.id
        cd.entityTypeRaw = item.entityType.rawValue
        cd.entityID = item.entityID
        cd.operationRaw = item.operation.rawValue
        cd.connectorID = item.connectorID
        cd.statusRaw = item.status.rawValue
        cd.retryCount = Int32(item.retryCount)
        cd.nextRetryAt = item.nextRetryAt
        cd.createdAt = item.createdAt
    }
}

// MARK: - UserDefaults UserProfileRepository

public final class UserDefaultsProfileRepository: UserProfileRepository {

    private let key = "watchpet.userProfile"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> UserProfile {
        guard let data = defaults.data(forKey: key),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return .default }
        return profile
    }

    public func save(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }
}

// MARK: - CoreDataIntegrationConfigRepository

public final class CoreDataIntegrationConfigRepository: IntegrationConfigRepository {

    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func fetchAll() async throws -> [IntegrationConfig] {
        try await context.perform {
            let request = CDIntegrationConfig.fetchRequest()
            return try self.context.fetch(request).map { $0.toDomain() }
        }
    }

    public func fetch(connectorID: String) async throws -> IntegrationConfig? {
        try await context.perform {
            let request = CDIntegrationConfig.fetchRequest()
            request.predicate = NSPredicate(format: "connectorID == %@", connectorID)
            request.fetchLimit = 1
            return try self.context.fetch(request).first?.toDomain()
        }
    }

    public func save(_ config: IntegrationConfig) async throws {
        try await context.perform {
            let request = CDIntegrationConfig.fetchRequest()
            request.predicate = NSPredicate(format: "connectorID == %@", config.connectorID)
            request.fetchLimit = 1
            
            let cd = try self.context.fetch(request).first ?? CDIntegrationConfig(context: self.context)
            cd.id = config.id
            cd.connectorID = config.connectorID
            cd.serviceName = config.serviceName
            cd.isEnabled = config.isEnabled
            cd.lastSyncedAt = config.lastSyncedAt
            cd.scopes = config.scopes
            try self.context.save()
        }
    }

    public func update(_ config: IntegrationConfig) async throws {
        try await save(config)
    }

    public func delete(connectorID: String) async throws {
        try await context.perform {
            let request = CDIntegrationConfig.fetchRequest()
            request.predicate = NSPredicate(format: "connectorID == %@", connectorID)
            request.fetchLimit = 1
            if let cd = try self.context.fetch(request).first {
                self.context.delete(cd)
                try self.context.save()
            }
        }
    }
}

// MARK: - RepositoryError

public enum RepositoryError: LocalizedError {
    case notFound(String)
    case saveFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id):    return "Entidade não encontrada: \(id)"
        case .saveFailed(let e):   return "Falha ao salvar: \(e.localizedDescription)"
        }
    }
}
