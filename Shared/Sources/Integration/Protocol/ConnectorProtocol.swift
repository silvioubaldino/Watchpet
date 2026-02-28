// MARK: - ConnectorProtocol
// O contrato central da Integration Layer (AyD v2.0, Seção 10.2).
// Toda integração externa implementa este protocolo.
// A Integration Layer reside EXCLUSIVAMENTE no iPhone companion app.

import Foundation

// MARK: - Auth

public struct AuthCredential: Codable {
    public let connectorID: String
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?
    public let scopes: [String]

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        // Buffer de 60s para renovar antes de expirar
        return Date().addingTimeInterval(60) >= expiresAt
    }

    public init(
        connectorID: String,
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil,
        scopes: [String] = []
    ) {
        self.connectorID = connectorID
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.scopes = scopes
    }
}

public typealias ExternalID = String

// MARK: - SyncableEntity
// Wrapper para transportar entidades de domínio pela Integration Layer.

public enum SyncableEntity {
    case note(Note)
    case reminder(Reminder)

    public var entityType: EntityType {
        switch self {
        case .note:     return .note
        case .reminder: return .reminder
        }
    }

    public var entityID: UUID {
        switch self {
        case .note(let n):     return n.id
        case .reminder(let r): return r.id
        }
    }
}

// MARK: - ConnectorError

public enum ConnectorError: LocalizedError {
    case authenticationFailed(String)
    case tokenExpired
    case networkUnavailable
    case rateLimited(retryAfter: TimeInterval)
    case entityNotFound(ExternalID)
    case conflict(local: SyncableEntity, remote: SyncableEntity)
    case apiError(statusCode: Int, message: String)
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed(let msg): return "Falha de autenticação: \(msg)"
        case .tokenExpired:                  return "Token expirado. Reconecte o serviço."
        case .networkUnavailable:            return "Sem conexão. O item será sincronizado quando a rede voltar."
        case .rateLimited(let t):            return "Limite de requisições atingido. Tente em \(Int(t))s."
        case .entityNotFound(let id):        return "Entidade não encontrada no serviço externo: \(id)"
        case .conflict:                      return "Conflito de sincronização detectado."
        case .apiError(let code, let msg):   return "Erro da API (\(code)): \(msg)"
        case .unknown(let e):                return "Erro desconhecido: \(e.localizedDescription)"
        }
    }
}

// MARK: - ConnectorProtocol

/// Contrato mínimo que todo conector de serviço externo deve implementar.
/// Anti-patterns: nunca fazer chamadas de rede diretas do Watch;
/// nunca bloquear a UX aguardando sync; nunca armazenar tokens fora do Keychain.
public protocol ConnectorProtocol: AnyObject {

    /// Identificador único do conector. Ex: "notion", "gcal"
    var id: String { get }

    /// Nome de exibição. Ex: "Notion", "Google Calendar"
    var displayName: String { get }

    /// Tipos de entidade que este conector suporta
    var supportedEntityTypes: [EntityType] { get }

    // MARK: Autenticação

    /// Inicia fluxo OAuth no iPhone via ASWebAuthenticationSession.
    /// Nunca apresentar tela de login no Watch.
    func authenticate() async throws -> AuthCredential

    /// Renova o access token usando o refresh token.
    func refreshToken(_ credential: AuthCredential) async throws -> AuthCredential

    /// Revoga acesso e remove tokens do Keychain.
    func revokeAccess() async throws

    // MARK: Sincronização

    /// Envia uma entidade ao serviço externo. Retorna o ID externo criado.
    func push(_ entity: SyncableEntity, credential: AuthCredential) async throws -> ExternalID

    /// Busca entidades modificadas desde a data informada.
    func pull(since: Date, credential: AuthCredential) async throws -> [SyncableEntity]

    /// Remove uma entidade no serviço externo pelo ID externo.
    func delete(externalID: ExternalID, credential: AuthCredential) async throws

    // MARK: Health Check

    /// Valida se a conexão está ativa e o token é válido.
    func validateConnection(credential: AuthCredential) async throws -> Bool
}

// MARK: - Default implementations

public extension ConnectorProtocol {
    /// Por padrão, conectores não fazem pull (somente push).
    func pull(since: Date, credential: AuthCredential) async throws -> [SyncableEntity] {
        return []
    }
}
