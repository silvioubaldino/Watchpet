// MARK: - WatchPet iOS Companion App Entry Point
// Target: WatchPet_iOS
// Companion app do iPhone: configurações, integrações, sincronização.

import SwiftUI

@main
struct WatchPetiOSApp: App {

    @StateObject private var container = iOSAppContainer(
        noteRepository: MockNoteRepository(),
        reminderRepository: MockReminderRepository(),
        syncQueueRepository: MockSyncQueueRepository(),
        integrationConfigRepository: MockIntegrationConfigRepository()
    )
    @StateObject private var connectivity = WatchConnectivityBridge.shared

    var body: some Scene {
        WindowGroup {
            iOSRootView()
                .environmentObject(container)
                .environmentObject(connectivity)
        }
    }
}

// MARK: - iOSRootView

struct iOSRootView: View {

    @EnvironmentObject var container: iOSAppContainer
    @EnvironmentObject var connectivity: WatchConnectivityBridge

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Início", systemImage: "house.fill")
                }

            IntegrationsView()
                .tabItem {
                    Label("Integrações", systemImage: "link.circle.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Config.", systemImage: "gearshape.fill")
                }
        }
        .onAppear {
            setupConnectivityHandlers()
        }
    }

    private func setupConnectivityHandlers() {
        // iPhone recebe SyncQueueItems do Watch e processa
        connectivity.onSyncQueueReceived = { items in
            Task {
                for item in items {
                    try? await container.syncQueueRepository.enqueue(item)
                }
                await container.syncEngine.processQueue()
            }
        }
    }
}

// MARK: - DashboardView

struct DashboardView: View {

    @EnvironmentObject var connectivity: WatchConnectivityBridge

    var body: some View {
        NavigationStack {
            List {
                Section("Status do Watch") {
                    HStack {
                        Image(systemName: connectivity.isReachable ? "applewatch.watchface" : "applewatch")
                            .foregroundStyle(connectivity.isReachable ? .green : .secondary)
                        VStack(alignment: .leading) {
                            Text(connectivity.isReachable ? "Watch conectado" : "Watch fora de alcance")
                                .font(.subheadline)
                            if let lastSync = connectivity.lastSyncDate {
                                Text("Último sync: \(lastSync.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if connectivity.pendingSyncCount > 0 {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.orange)
                            Text("\(connectivity.pendingSyncCount) item(s) pendentes de sync")
                                .font(.subheadline)
                        }
                    }
                }

                Section("Sincronização") {
                    // Placeholder — Fase 4
                    Text("Conectores e histórico de sync — Fase 4")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .navigationTitle("WatchPet")
        }
    }
}

// MARK: - IntegrationsView (Fase 4 placeholder)

struct IntegrationsView: View {

    @EnvironmentObject var container: iOSAppContainer

    var body: some View {
        NavigationStack {
            List {
                Section {
                    IntegrationRowView(
                        icon: "doc.richtext",
                        name: "Notion",
                        description: "Sincroniza notas e tarefas",
                        isConnected: false,
                        phase: "Fase 4"
                    )
                    IntegrationRowView(
                        icon: "calendar",
                        name: "Google Calendar",
                        description: "Sincroniza lembretes e eventos",
                        isConnected: false,
                        phase: "Fase 4"
                    )
                    IntegrationRowView(
                        icon: "note.text",
                        name: "Apple Notes",
                        description: "Exporta notas via Shortcuts",
                        isConnected: false,
                        phase: "Fase 4"
                    )
                } header: {
                    Text("Conectores disponíveis")
                } footer: {
                    Text("As integrações externas ficam disponíveis no plano WatchPet Pro.")
                        .font(.caption)
                }

                Section("Em breve — Fase 5") {
                    ForEach(["Todoist", "Obsidian", "Slack", "Webhook genérico"], id: \.self) { name in
                        Label(name, systemImage: "clock.badge.questionmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Integrações")
        }
    }
}

struct IntegrationRowView: View {
    let icon: String
    let name: String
    let description: String
    let isConnected: Bool
    let phase: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(isConnected ? .blue : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.bold())
                Text(description).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text(phase)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Pet") {
                    NavigationLink("Nome e personalidade") { Text("Configurações do Pet — Fase 5") }
                    NavigationLink("Voz e idioma") { Text("Configurações de voz — Fase 1") }
                }
                Section("Lembretes proativos") {
                    NavigationLink("Horários ativos") { Text("Horários — Fase 3") }
                    NavigationLink("Metas de hábitos") { Text("Metas — Fase 3") }
                }
                Section("Privacidade") {
                    Label("Transcrição 100% on-device", systemImage: "lock.shield.fill")
                        .foregroundStyle(.green)
                    Label("Tokens no Keychain", systemImage: "key.fill")
                        .foregroundStyle(.green)
                }
                Section("Sobre") {
                    LabeledContent("Versão", value: "0.1.0 (Fase 0)")
                    LabeledContent("AyD", value: "v2.0")
                }
            }
            .navigationTitle("Configurações")
        }
    }
}

// MARK: - Mock para iOS

final class MockIntegrationConfigRepository: IntegrationConfigRepository {
    var configs: [IntegrationConfig] = []
    func fetchAll() async throws -> [IntegrationConfig] { configs }
    func fetch(connectorID: String) async throws -> IntegrationConfig? { configs.first { $0.connectorID == connectorID } }
    func save(_ config: IntegrationConfig) async throws { configs.append(config) }
    func update(_ config: IntegrationConfig) async throws { configs = configs.map { $0.connectorID == config.connectorID ? config : $0 } }
    func delete(connectorID: String) async throws { configs.removeAll { $0.connectorID == connectorID } }
}

// MARK: - Previews

#Preview("iOS Root") {
    iOSRootView()
        .environmentObject(iOSAppContainer(
            noteRepository: MockNoteRepository(),
            reminderRepository: MockReminderRepository(),
            syncQueueRepository: MockSyncQueueRepository(),
            integrationConfigRepository: MockIntegrationConfigRepository()
        ))
        .environmentObject(WatchConnectivityBridge.shared)
}
