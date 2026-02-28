// MARK: - OAuthManager
// Gerencia autenticação OAuth 2.0 via ASWebAuthenticationSession (AyD v2.0, Seção 10.6).
// Tokens armazenados EXCLUSIVAMENTE no Keychain com kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly.
// Nunca persiste em CoreData, UserDefaults ou logs.
// Nunca expõe tokens ao Watch.

import Foundation
import Security
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

// MARK: - Keychain Helper

private enum KeychainError: Error {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
}

private final class KeychainStore {

    static func save(data: Data, service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String:                 kSecClassGenericPassword,
            kSecAttrService as String:           service,
            kSecAttrAccount as String:           account,
            kSecValueData as String:             data,
            kSecAttrAccessible as String:        kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Remove existing before saving
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func load(service: String, account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            if status == errSecItemNotFound { throw KeychainError.itemNotFound }
            throw KeychainError.unexpectedStatus(status)
        }
        return data
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - OAuthManager

public enum OAuthError: LocalizedError {
    case credentialNotFound
    case tokenRefreshFailed
    case authenticationCancelled
    case invalidCallbackURL

    public var errorDescription: String? {
        switch self {
        case .credentialNotFound:     return "Credencial não encontrada. Conecte o serviço novamente."
        case .tokenRefreshFailed:     return "Falha ao renovar token. Reconecte o serviço."
        case .authenticationCancelled: return "Autenticação cancelada pelo usuário."
        case .invalidCallbackURL:     return "URL de callback inválida."
        }
    }
}

public actor OAuthManager {

    public static let shared = OAuthManager()

    private let keychainService = "com.watchpet.oauth"

    private init() {}

    // MARK: - Persistência segura

    /// Persiste credenciais no Keychain. Nunca armazena em outro lugar.
    public func save(_ credential: AuthCredential) throws {
        let data = try JSONEncoder().encode(credential)
        try KeychainStore.save(
            data: data,
            service: keychainService,
            account: credential.connectorID
        )
    }

    /// Recupera credencial do Keychain. Renova automaticamente se expirada.
    public func validCredential(for connectorID: String, connector: ConnectorProtocol) async throws -> AuthCredential {
        guard let stored = try? loadFromKeychain(connectorID: connectorID) else {
            throw OAuthError.credentialNotFound
        }

        if stored.isExpired {
            return try await refresh(stored, connector: connector)
        }
        return stored
    }

    /// Revoga acesso e remove do Keychain.
    public func revoke(connectorID: String, connector: ConnectorProtocol) async throws {
        if let credential = try? loadFromKeychain(connectorID: connectorID) {
            try? await connector.revokeAccess()
            _ = credential // silence warning
        }
        KeychainStore.delete(service: keychainService, account: connectorID)
    }

    public func hasCredential(for connectorID: String) -> Bool {
        (try? loadFromKeychain(connectorID: connectorID)) != nil
    }

    // MARK: - Privado

    private func loadFromKeychain(connectorID: String) throws -> AuthCredential {
        let data = try KeychainStore.load(service: keychainService, account: connectorID)
        return try JSONDecoder().decode(AuthCredential.self, from: data)
    }

    private func refresh(_ credential: AuthCredential, connector: ConnectorProtocol) async throws -> AuthCredential {
        do {
            let refreshed = try await connector.refreshToken(credential)
            try save(refreshed)
            return refreshed
        } catch {
            throw OAuthError.tokenRefreshFailed
        }
    }
}
