// MARK: - WatchConnectivityBridge
// Comunicação Watch ↔ iPhone via WatchConnectivity (AyD v2.0, Seção 10.5 - Etapas 3 e 4).
// Watch enfileira SyncQueueItems localmente e os transfere ao iPhone.
// iPhone consome a fila, processa integrações e confirma sync ao Watch.

import Foundation
import WatchConnectivity
import Combine

// MARK: - Mensagens

public enum WatchMessage: String {
    case syncQueueItems = "syncQueueItems"    // Watch → iPhone: array de SyncQueueItem
    case syncConfirmation = "syncConfirmation" // iPhone → Watch: UUID do item confirmado
    case profileUpdate = "profileUpdate"       // iPhone → Watch: UserProfile atualizado
    case integrationStatus = "integrationStatus" // iPhone → Watch: status das integrações
}

// MARK: - WatchConnectivityBridge

@MainActor
public final class WatchConnectivityBridge: NSObject, ObservableObject {

    public static let shared = WatchConnectivityBridge()

    @Published public private(set) var isReachable = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var pendingSyncCount: Int = 0

    // Callbacks — configurados pelo AppContainer
    public var onSyncQueueReceived: (([SyncQueueItem]) -> Void)?  // iPhone side
    public var onSyncConfirmed: ((UUID) -> Void)?                  // Watch side
    public var onProfileUpdated: ((UserProfile) -> Void)?          // Watch side

    private let session: WCSession

    private override init() {
        session = WCSession.default
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Watch → iPhone: Enfileirar itens para sync

    /// Chamado pelo Watch quando um novo SyncQueueItem é criado.
    /// Usa transferUserInfo para garantia de entrega mesmo sem o app aberto no iPhone.
    public func transferSyncQueueItems(_ items: [SyncQueueItem]) {
        guard session.activationState == .activated else { return }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(items) else { return }

        // transferUserInfo: entregue mesmo se o iPhone companion app estiver fechado
        session.transferUserInfo([
            WatchMessage.syncQueueItems.rawValue: data
        ])

        pendingSyncCount = items.count
    }

    // MARK: - iPhone → Watch: Confirmar sync concluído

    /// Chamado pelo iPhone após processar um item da SyncQueue com sucesso.
    public func confirmSync(itemID: UUID) {
        guard session.isReachable else {
            // Se Watch não está alcançável, usa transferUserInfo para garantia de entrega
            session.transferUserInfo([
                WatchMessage.syncConfirmation.rawValue: itemID.uuidString
            ])
            return
        }

        // Se alcançável, usa sendMessage para resposta imediata
        session.sendMessage(
            [WatchMessage.syncConfirmation.rawValue: itemID.uuidString],
            replyHandler: nil,
            errorHandler: { error in
                print("⚠️ WatchConnectivity: Falha ao confirmar sync: \(error)")
            }
        )
    }

    // MARK: - iPhone → Watch: Atualizar perfil

    public func sendProfileUpdate(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        session.transferUserInfo([WatchMessage.profileUpdate.rawValue: data])
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityBridge: WCSessionDelegate {

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }

    // Recebe dados garantidos (transferUserInfo)
    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            handleReceivedMessage(userInfo)
        }
    }

    // Recebe mensagens em tempo real (sendMessage)
    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleReceivedMessage(message)
        }
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        let decoder = JSONDecoder()

        // SyncQueueItems: Watch → iPhone
        if let data = message[WatchMessage.syncQueueItems.rawValue] as? Data,
           let items = try? decoder.decode([SyncQueueItem].self, from: data) {
            onSyncQueueReceived?(items)
        }

        // SyncConfirmation: iPhone → Watch
        if let idString = message[WatchMessage.syncConfirmation.rawValue] as? String,
           let id = UUID(uuidString: idString) {
            lastSyncDate = Date()
            pendingSyncCount = max(0, pendingSyncCount - 1)
            onSyncConfirmed?(id)
        }

        // ProfileUpdate: iPhone → Watch
        if let data = message[WatchMessage.profileUpdate.rawValue] as? Data,
           let profile = try? decoder.decode(UserProfile.self, from: data) {
            onProfileUpdated?(profile)
        }
    }

    // Necessário apenas no iOS (não watchOS)
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
