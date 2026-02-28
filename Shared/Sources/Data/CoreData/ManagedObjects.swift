// MARK: - CoreData Managed Objects
// NSManagedObject subclasses para todas as entidades do WatchPet.
// Em projecto Xcode real: gerar via Editor → Create NSManagedObject Subclass
// com o modelo .xcdatamodeld. Aqui definidas manualmente para clareza.

import CoreData
import Foundation

// MARK: - CDNote

@objc(CDNote)
public class CDNote: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var rawText: String?
    @NSManaged public var category: String?
    @NSManaged public var tagsData: Data?       // [String] encoded as JSON
    @NSManaged public var externalIDsData: Data? // [String:String] encoded as JSON
    @NSManaged public var isSynced: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?

    public var tags: [String] {
        get { (try? JSONDecoder().decode([String].self, from: tagsData ?? Data())) ?? [] }
        set { tagsData = try? JSONEncoder().encode(newValue) }
    }

    public var externalIDs: [String: String] {
        get { (try? JSONDecoder().decode([String: String].self, from: externalIDsData ?? Data())) ?? [:] }
        set { externalIDsData = try? JSONEncoder().encode(newValue) }
    }

    public func toDomain() -> Note {
        Note(
            id: id ?? UUID(),
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            rawText: rawText ?? "",
            category: category,
            tags: tags,
            isSynced: isSynced,
            externalIDs: externalIDs
        )
    }

    public static func fetchRequest() -> NSFetchRequest<CDNote> {
        NSFetchRequest<CDNote>(entityName: "CDNote")
    }
}

// MARK: - CDReminder

@objc(CDReminder)
public class CDReminder: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var triggerDate: Date?
    @NSManaged public var repeatInterval: Double  // 0 = não repete
    @NSManaged public var isProactive: Bool
    @NSManaged public var completedAt: Date?
    @NSManaged public var linkedEntityID: UUID?
    @NSManaged public var externalIDsData: Data?

    public var externalIDs: [String: String] {
        get { (try? JSONDecoder().decode([String: String].self, from: externalIDsData ?? Data())) ?? [:] }
        set { externalIDsData = try? JSONEncoder().encode(newValue) }
    }

    public func toDomain() -> Reminder {
        Reminder(
            id: id ?? UUID(),
            title: title ?? "",
            triggerDate: triggerDate ?? Date(),
            repeatInterval: repeatInterval > 0 ? repeatInterval : nil,
            isProactive: isProactive,
            completedAt: completedAt,
            linkedEntityID: linkedEntityID,
            externalIDs: externalIDs
        )
    }

    public static func fetchRequest() -> NSFetchRequest<CDReminder> {
        NSFetchRequest<CDReminder>(entityName: "CDReminder")
    }
}

// MARK: - CDTimerRecord

@objc(CDTimerRecord)
public class CDTimerRecord: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var startedAt: Date?
    @NSManaged public var duration: Double
    @NSManaged public var label: String?
    @NSManaged public var completedAt: Date?
    @NSManaged public var typeRaw: String?

    public var type: TimerType {
        get { TimerType(rawValue: typeRaw ?? "") ?? .custom }
        set { typeRaw = newValue.rawValue }
    }

    public func toDomain() -> TimerRecord {
        TimerRecord(
            id: id ?? UUID(),
            startedAt: startedAt ?? Date(),
            duration: duration,
            label: label,
            completedAt: completedAt,
            type: type
        )
    }

    public static func fetchRequest() -> NSFetchRequest<CDTimerRecord> {
        NSFetchRequest<CDTimerRecord>(entityName: "CDTimerRecord")
    }
}

// MARK: - CDHabitLog

@objc(CDHabitLog)
public class CDHabitLog: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var hydrationCheckins: Int32
    @NSManaged public var postureBreaks: Int32
    @NSManaged public var pomodoroCount: Int32
    @NSManaged public var notesCreated: Int32

    public func toDomain() -> HabitLog {
        HabitLog(
            id: id ?? UUID(),
            date: date ?? Date(),
            hydrationCheckins: Int(hydrationCheckins),
            postureBreaks: Int(postureBreaks),
            pomodoroCount: Int(pomodoroCount),
            notesCreated: Int(notesCreated)
        )
    }

    public static func fetchRequest() -> NSFetchRequest<CDHabitLog> {
        NSFetchRequest<CDHabitLog>(entityName: "CDHabitLog")
    }
}

// MARK: - CDConversation

@objc(CDConversation)
public class CDConversation: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var transcript: String?
    @NSManaged public var llmResponse: String?
    @NSManaged public var intentTypeRaw: String?
    @NSManaged public var petEmotionRaw: String?

    public func toDomain() -> Conversation {
        Conversation(
            id: id ?? UUID(),
            timestamp: timestamp ?? Date(),
            transcript: transcript ?? "",
            llmResponse: llmResponse ?? "",
            intentType: IntentType(rawValue: intentTypeRaw ?? "") ?? .unknown,
            petEmotion: PetEmotion(rawValue: petEmotionRaw ?? "") ?? .happy
        )
    }

    public static func fetchRequest() -> NSFetchRequest<CDConversation> {
        NSFetchRequest<CDConversation>(entityName: "CDConversation")
    }
}

// MARK: - CDSyncQueueItem

@objc(CDSyncQueueItem)
public class CDSyncQueueItem: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var entityTypeRaw: String?
    @NSManaged public var entityID: UUID?
    @NSManaged public var operationRaw: String?
    @NSManaged public var connectorID: String?
    @NSManaged public var statusRaw: String?
    @NSManaged public var retryCount: Int32
    @NSManaged public var nextRetryAt: Date?
    @NSManaged public var createdAt: Date?

    public func toDomain() -> SyncQueueItem {
        SyncQueueItem(
            id: id ?? UUID(),
            entityType: EntityType(rawValue: entityTypeRaw ?? "") ?? .note,
            entityID: entityID ?? UUID(),
            operation: SyncOperation(rawValue: operationRaw ?? "") ?? .create,
            connectorID: connectorID ?? "",
            status: SyncStatus(rawValue: statusRaw ?? "") ?? .pending,
            retryCount: Int(retryCount),
            nextRetryAt: nextRetryAt,
            createdAt: createdAt ?? Date()
        )
    }

    public static func fetchRequest() -> NSFetchRequest<CDSyncQueueItem> {
        NSFetchRequest<CDSyncQueueItem>(entityName: "CDSyncQueueItem")
    }
}
