// MARK: - IntegrationRegistry
// Catálogo de conectores disponíveis (AyD v2.0, Seção 10.3).
// Singleton no iPhone companion app.
// Adicionar novo conector = criar classe + registrar aqui. Nada mais muda.

import Foundation

@MainActor
public final class IntegrationRegistry: ObservableObject {

    public static let shared = IntegrationRegistry()

    /// Conectores registrados no app. Chave = connectorID.
    private var connectors: [String: ConnectorProtocol] = [:]

    /// IDs de conectores habilitados pelo usuário (persistido em IntegrationConfigRepository).
    @Published public private(set) var enabledConnectorIDs: Set<String> = []

    private init() {
        registerDefaultConnectors()
    }

    // MARK: - Registro

    private func registerDefaultConnectors() {
        // Fase 4: Notion e Google Calendar
        register(NotionConnector())
        register(GoogleCalendarConnector())
        // register(AppleNotesConnector())
        //
        // Fase 5:
        // register(TodoistConnector())
        // register(ObsidianConnector())
        // register(SlackConnector())
    }

    /// Registra um conector. Chamado apenas durante setup.
    public func register(_ connector: ConnectorProtocol) {
        connectors[connector.id] = connector
    }

    // MARK: - Consulta

    public func connector(for id: String) -> ConnectorProtocol? {
        connectors[id]
    }

    /// Conectores habilitados que suportam o tipo de entidade especificado.
    public func enabledConnectors(for entityType: EntityType) -> [ConnectorProtocol] {
        connectors.values.filter {
            $0.supportedEntityTypes.contains(entityType) && enabledConnectorIDs.contains($0.id)
        }
    }

    /// Todos os conectores disponíveis (habilitados ou não).
    public var allConnectors: [ConnectorProtocol] {
        Array(connectors.values)
    }

    public var allConnectorIDs: [String] {
        Array(connectors.keys).sorted()
    }

    // MARK: - Enable / Disable

    public func enable(connectorID: String) {
        guard connectors[connectorID] != nil else { return }
        enabledConnectorIDs.insert(connectorID)
    }

    public func disable(connectorID: String) {
        enabledConnectorIDs.remove(connectorID)
    }

    public func isEnabled(_ connectorID: String) -> Bool {
        enabledConnectorIDs.contains(connectorID)
    }
}
