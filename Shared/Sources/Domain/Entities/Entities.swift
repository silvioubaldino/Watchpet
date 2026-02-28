// MARK: - WatchPet Domain Entities
// Modelos de domínio puros — sem dependência de framework.
// Seguem o contrato definido no AyD v2.0, Seção 4.3.

import Foundation

// MARK: - Enums compartilhados

public enum IntentType: String, Codable, CaseIterable {
    case conversation
    case reminder
    case timer
    case note
    case habit
    case settings
    case unknown
}

public enum PetEmotion: String, Codable, CaseIterable {
    case sleeping       // Sem interação 30+ min
    case happy          // Default
    case thinking       // Processando LLM
    case excited        // Meta do dia concluída
    case missing        // Sem interação 2+ horas
    case celebrating    // Streak 7+ dias
    case syncing        // Sync com serviço externo
}

public enum PetPersonality: String, Codable, CaseIterable {
    case enthusiastic   // 🐶 Entusiasta (default)
    case sarcastic      // 🐱 Sarcástico & Esperto
    case wise           // 🦉 Sábio & Calmo
    case minimalist     // 🤖 Minimalista Tech
    case curious        // 🦊 Animado & Curioso

    public var displayName: String {
        switch self {
        case .enthusiastic: return "🐶 Entusiasta"
        case .sarcastic:    return "🐱 Sarcástico & Esperto"
        case .wise:         return "🦉 Sábio & Calmo"
        case .minimalist:   return "🤖 Minimalista Tech"
        case .curious:      return "🦊 Animado & Curioso"
        }
    }
}

public enum EntityType: String, Codable {
    case note
    case reminder
    case event
}

public enum SyncOperation: String, Codable {
    case create
    case update
    case delete
}

public enum SyncStatus: String, Codable {
    case pending
    case inProgress
    case done
    case failed
}

// MARK: - Conversation

public struct Conversation: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let transcript: String
    public let llmResponse: String
    public let intentType: IntentType
    public let petEmotion: PetEmotion

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        transcript: String,
        llmResponse: String,
        intentType: IntentType,
        petEmotion: PetEmotion
    ) {
        self.id = id
        self.timestamp = timestamp
        self.transcript = transcript
        self.llmResponse = llmResponse
        self.intentType = intentType
        self.petEmotion = petEmotion
    }
}

// MARK: - Note

public struct Note: Identifiable, Codable {
    public let id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var rawText: String
    public var category: String?
    public var tags: [String]
    public var isSynced: Bool
    /// IDs correspondentes em serviços externos. Ex: ["notion": "page_abc123", "gcal": "event_xyz"]
    public var externalIDs: [String: String]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        rawText: String,
        category: String? = nil,
        tags: [String] = [],
        isSynced: Bool = false,
        externalIDs: [String: String] = [:]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.rawText = rawText
        self.category = category
        self.tags = tags
        self.isSynced = isSynced
        self.externalIDs = externalIDs
    }
}

// MARK: - Reminder

public struct Reminder: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var triggerDate: Date
    public var repeatInterval: TimeInterval? // segundos; nil = não repete
    public var isProactive: Bool
    public var completedAt: Date?
    public var linkedEntityID: UUID?
    public var externalIDs: [String: String]

    public var isCompleted: Bool { completedAt != nil }

    public init(
        id: UUID = UUID(),
        title: String,
        triggerDate: Date,
        repeatInterval: TimeInterval? = nil,
        isProactive: Bool = false,
        completedAt: Date? = nil,
        linkedEntityID: UUID? = nil,
        externalIDs: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.triggerDate = triggerDate
        self.repeatInterval = repeatInterval
        self.isProactive = isProactive
        self.completedAt = completedAt
        self.linkedEntityID = linkedEntityID
        self.externalIDs = externalIDs
    }
}

// MARK: - TimerRecord

public enum TimerType: String, Codable {
    case focus      // Pomodoro
    case water
    case custom
}

public struct TimerRecord: Identifiable, Codable {
    public let id: UUID
    public let startedAt: Date
    public let duration: TimeInterval // segundos
    public var label: String?
    public var completedAt: Date?
    public let type: TimerType

    public var isRunning: Bool { completedAt == nil }
    public var elapsed: TimeInterval { Date().timeIntervalSince(startedAt) }
    public var remaining: TimeInterval { max(0, duration - elapsed) }

    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        duration: TimeInterval,
        label: String? = nil,
        completedAt: Date? = nil,
        type: TimerType = .custom
    ) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
        self.label = label
        self.completedAt = completedAt
        self.type = type
    }
}

// MARK: - UserProfile

public struct UserProfile: Codable {
    public var petName: String
    public var petPersonality: PetPersonality
    public var preferredVoice: String        // AVSpeechSynthesisVoice identifier
    public var activeHoursStart: Int         // hora (0-23)
    public var activeHoursEnd: Int
    public var hydrationGoalCheckins: Int    // número de checkins diários desejados
    public var streakCount: Int
    public var language: String              // "pt-BR", "en-US" etc.

    public static var `default`: UserProfile {
        UserProfile(
            petName: "Pet",
            petPersonality: .enthusiastic,
            preferredVoice: "com.apple.ttsbundle.Luciana-compact",
            activeHoursStart: 7,
            activeHoursEnd: 22,
            hydrationGoalCheckins: 8,
            streakCount: 0,
            language: "pt-BR"
        )
    }

    public init(
        petName: String,
        petPersonality: PetPersonality,
        preferredVoice: String,
        activeHoursStart: Int,
        activeHoursEnd: Int,
        hydrationGoalCheckins: Int,
        streakCount: Int,
        language: String
    ) {
        self.petName = petName
        self.petPersonality = petPersonality
        self.preferredVoice = preferredVoice
        self.activeHoursStart = activeHoursStart
        self.activeHoursEnd = activeHoursEnd
        self.hydrationGoalCheckins = hydrationGoalCheckins
        self.streakCount = streakCount
        self.language = language
    }
}

// MARK: - HabitLog

public struct HabitLog: Identifiable, Codable {
    public let id: UUID
    public let date: Date
    public var hydrationCheckins: Int
    public var postureBreaks: Int
    public var pomodoroCount: Int
    public var notesCreated: Int

    public init(
        id: UUID = UUID(),
        date: Date = Calendar.current.startOfDay(for: Date()),
        hydrationCheckins: Int = 0,
        postureBreaks: Int = 0,
        pomodoroCount: Int = 0,
        notesCreated: Int = 0
    ) {
        self.id = id
        self.date = date
        self.hydrationCheckins = hydrationCheckins
        self.postureBreaks = postureBreaks
        self.pomodoroCount = pomodoroCount
        self.notesCreated = notesCreated
    }
}

// MARK: - Integration Entities

public struct IntegrationConfig: Identifiable, Codable {
    public let id: UUID
    public let connectorID: String
    public let serviceName: String
    public var isEnabled: Bool
    // Tokens NÃO ficam aqui — ficam exclusivamente no Keychain (ver OAuthManager)
    public var scopes: [String]
    public var lastSyncedAt: Date?

    public init(
        id: UUID = UUID(),
        connectorID: String,
        serviceName: String,
        isEnabled: Bool = false,
        scopes: [String] = [],
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.connectorID = connectorID
        self.serviceName = serviceName
        self.isEnabled = isEnabled
        self.scopes = scopes
        self.lastSyncedAt = lastSyncedAt
    }
}

public struct SyncQueueItem: Identifiable, Codable {
    public let id: UUID
    public let entityType: EntityType
    public let entityID: UUID
    public let operation: SyncOperation
    public let connectorID: String
    public var status: SyncStatus
    public var retryCount: Int
    public var nextRetryAt: Date?
    public let createdAt: Date

    // Backoff exponencial: 30s, 2min, 10min, 1h, 24h
    static let backoffIntervals: [TimeInterval] = [30, 120, 600, 3600, 86400]
    public static let maxRetries = 5

    public mutating func scheduleRetry() {
        guard retryCount < Self.maxRetries else {
            status = .failed
            return
        }
        let interval = Self.backoffIntervals[min(retryCount, Self.backoffIntervals.count - 1)]
        nextRetryAt = Date().addingTimeInterval(interval)
        retryCount += 1
        status = .pending
    }

    public init(
        id: UUID = UUID(),
        entityType: EntityType,
        entityID: UUID,
        operation: SyncOperation,
        connectorID: String,
        status: SyncStatus = .pending,
        retryCount: Int = 0,
        nextRetryAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.entityType = entityType
        self.entityID = entityID
        self.operation = operation
        self.connectorID = connectorID
        self.status = status
        self.retryCount = retryCount
        self.nextRetryAt = nextRetryAt
        self.createdAt = createdAt
    }
}
