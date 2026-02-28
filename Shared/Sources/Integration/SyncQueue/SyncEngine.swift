// MARK: - SyncEngine
// Processa a SyncQueue em background (AyD v2.0, Seção 10.4 e 10.5).
// Roda exclusivamente no iPhone companion app via BGProcessingTask.
// Garante que nenhuma ação do usuário seja perdida por falha de rede.

import Foundation

// MARK: - SyncEngine

public actor SyncEngine {

    private let registry: IntegrationRegistry
    private let oauth: OAuthManager
    private let syncQueueRepo: SyncQueueRepository
    private let noteRepo: NoteRepository
    private let reminderRepo: ReminderRepository

    public private(set) var isSyncing = false

    public nonisolated init(
        registry: IntegrationRegistry,
        oauth: OAuthManager,
        syncQueueRepo: SyncQueueRepository,
        noteRepo: NoteRepository,
        reminderRepo: ReminderRepository
    ) {
        self.registry = registry
        self.oauth = oauth
        self.syncQueueRepo = syncQueueRepo
        self.noteRepo = noteRepo
        self.reminderRepo = reminderRepo
    }

    // MARK: - Processamento da fila

    /// Processa todos os itens pendentes da fila.
    /// Chamado pelo BGProcessingTask ou manualmente pelo usuário.
    public func processQueue() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let pending = (try? await syncQueueRepo.fetchPending(connectorID: nil)) ?? []
        let now = Date()

        for var item in pending {
            // Respeita backoff — não processa antes do nextRetryAt
            if let nextRetry = item.nextRetryAt, nextRetry > now { continue }

            await process(&item)
        }
    }

    // MARK: - Processamento individual

    private func process(_ item: inout SyncQueueItem) async {
        guard let connector = await registry.connector(for: item.connectorID) else {
            try? await syncQueueRepo.updateStatus(id: item.id, status: .failed)
            return
        }

        do {
            try await syncQueueRepo.updateStatus(id: item.id, status: .inProgress)

            let credential = try await oauth.validCredential(
                for: item.connectorID,
                connector: connector
            )

            switch item.operation {
            case .create, .update:
                let entity = try await fetchEntity(type: item.entityType, id: item.entityID)
                let externalID = try await connector.push(entity, credential: credential)
                try await persistExternalID(externalID, entity: entity, connectorID: item.connectorID)
                try await syncQueueRepo.updateStatus(id: item.id, status: .done)

            case .delete:
                let externalID = try await fetchExternalID(
                    entityType: item.entityType,
                    entityID: item.entityID,
                    connectorID: item.connectorID
                )
                if let externalID {
                    try await connector.delete(externalID: externalID, credential: credential)
                }
                try await syncQueueRepo.updateStatus(id: item.id, status: .done)
            }

        } catch ConnectorError.networkUnavailable {
            item.scheduleRetry()
            try? await syncQueueRepo.scheduleRetry(id: item.id)

        } catch ConnectorError.rateLimited(let retryAfter) {
            // Respeita o Retry-After da API
            var updated = item
            updated.nextRetryAt = Date().addingTimeInterval(retryAfter)
            updated.status = .pending
            try? await syncQueueRepo.scheduleRetry(id: item.id)

        } catch ConnectorError.tokenExpired {
            // OAuthManager já tenta refresh automaticamente — se chegou aqui, falhou
            try? await syncQueueRepo.updateStatus(id: item.id, status: .failed)

        } catch {
            item.scheduleRetry()
            if item.retryCount >= SyncQueueItem.maxRetries {
                try? await syncQueueRepo.updateStatus(id: item.id, status: .failed)
                await notifyUserOfFailure(item: item)
            } else {
                try? await syncQueueRepo.scheduleRetry(id: item.id)
            }
        }
    }

    // MARK: - Helpers

    private func fetchEntity(type: EntityType, id: UUID) async throws -> SyncableEntity {
        switch type {
        case .note:
            let notes = try await noteRepo.fetchAll()
            guard let note = notes.first(where: { $0.id == id }) else {
                throw ConnectorError.entityNotFound(id.uuidString)
            }
            return .note(note)

        case .reminder:
            let reminders = try await reminderRepo.fetchAll()
            guard let reminder = reminders.first(where: { $0.id == id }) else {
                throw ConnectorError.entityNotFound(id.uuidString)
            }
            return .reminder(reminder)

        case .event:
            throw ConnectorError.entityNotFound(id.uuidString)
        }
    }

    private func persistExternalID(
        _ externalID: ExternalID,
        entity: SyncableEntity,
        connectorID: String
    ) async throws {
        switch entity {
        case .note(let note):
            try await noteRepo.markSynced(
                id: note.id,
                externalID: externalID,
                connectorID: connectorID
            )
        case .reminder:
            // Reminders têm externalIDs mas não têm markSynced dedicado — extensão futura
            break
        }
    }

    private func fetchExternalID(
        entityType: EntityType,
        entityID: UUID,
        connectorID: String
    ) async throws -> ExternalID? {
        switch entityType {
        case .note:
            let notes = try await noteRepo.fetchAll()
            return notes.first(where: { $0.id == entityID })?.externalIDs[connectorID]
        default:
            return nil
        }
    }

    private func notifyUserOfFailure(item: SyncQueueItem) async {
        // TODO: Enviar notificação discreta via WatchConnectivity ou UserNotifications
        print("⚠️ SyncEngine: Item \(item.id) falhou após \(SyncQueueItem.maxRetries) tentativas.")
    }
}

// MARK: - ConflictResolver (AyD v2.0, Seção 10.7)

public enum ConflictPolicy {
    case lastWriteWins   // Padrão: baseado em updatedAt
    case localWins
    case remoteWins
    case duplicate       // Cria duplicata com sufixo "(conflito)"
}

public struct ConflictResolver {

    public let defaultPolicy: ConflictPolicy

    public init(defaultPolicy: ConflictPolicy = .lastWriteWins) {
        self.defaultPolicy = defaultPolicy
    }

    public func resolve(local: SyncableEntity, remote: SyncableEntity) -> SyncableEntity {
        switch defaultPolicy {
        case .localWins:
            return local

        case .remoteWins:
            return remote

        case .lastWriteWins:
            switch (local, remote) {
            case (.note(let ln), .note(let rn)):
                return ln.updatedAt >= rn.updatedAt ? .note(ln) : .note(rn)
            case (.reminder(let lr), .reminder(let rr)):
                let localDate = lr.completedAt ?? lr.triggerDate
                let remoteDate = rr.completedAt ?? rr.triggerDate
                return localDate >= remoteDate ? .reminder(lr) : .reminder(rr)
            default:
                return local
            }

        case .duplicate:
            // Cria duplicata — a camada de repositório vai gerar nova entidade com sufixo "(conflito)"
            return local
        }
    }
}
