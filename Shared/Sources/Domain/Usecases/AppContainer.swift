// MARK: - AppContainer
// Container de injeção de dependências (DI).
// Instancia e injeta todos os serviços, repositórios e casos de uso do app.

import Foundation
import CoreData

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
        
        // SyncEngine is an actor. Nonisolated initialization:
        self.syncEngine = SyncEngine(
            registry: self.integrationRegistry,
            oauth: self.oauthManager,
            syncQueueRepo: syncQueueRepo,
            noteRepo: noteRepo,
            reminderRepo: reminderRepo
        )
    }
}

// MARK: - Preview Support

#if DEBUG

public extension iOSAppContainer {
    static var preview: iOSAppContainer {
        iOSAppContainer(inMemory: true)
    }
}
#endif
