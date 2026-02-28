// MARK: - WatchPet Phase 1 — Main Watch App
// Atualiza o entry point com todos os módulos da Fase 1 integrados.

import SwiftUI

@main
struct WatchPetAppV1: App {

    @StateObject private var container = WatchAppContainerV1()
    @StateObject private var connectivity = WatchConnectivityBridge.shared

    var body: some Scene {
        WindowGroup {
            MainWatchViewV1()
                .environmentObject(container)
                .environmentObject(connectivity)
        }
    }
}

// MARK: - MainWatchViewV1

struct MainWatchViewV1: View {

    @EnvironmentObject var container: WatchAppContainerV1
    @StateObject private var voiceVM: VoiceInteractionViewModel

    init() {
        // VoiceInteractionViewModel inicializado no onAppear via container
        _voiceVM = StateObject(wrappedValue: VoiceInteractionViewModel(container: .preview))
    }

    var body: some View {
        TabView {
            // Tab 1 — Tela principal: Pet + Voz
            MainPetVoiceView(voiceVM: voiceVM)
                .tag(0)

            // Tab 2 — Timers
            TimersView(container: container)
                .tag(1)

            // Tab 3 — Lembretes
            RemindersView(container: container)
                .tag(2)
        }
        .tabViewStyle(.page)
    }
}

// MARK: - MainPetVoiceView

struct MainPetVoiceView: View {

    @EnvironmentObject var container: WatchAppContainerV1
    @ObservedObject var voiceVM: VoiceInteractionViewModel

    var body: some View {
        VStack(spacing: 6) {

            // Avatar do pet
            PetAvatarView(
                emotion: container.petStateManager.currentEmotion,
                petName: container.petStateManager.petName
            )
            .frame(height: 90)

            // Resposta do pet ou transcript parcial
            responseArea

            // Botão de voz
            HStack(spacing: 10) {
                voiceButton

                if voiceVM.pendingRemindersCount > 0 {
                    NavigationLink(destination: RemindersView(container: container)) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("\(voiceVM.pendingRemindersCount)")
                                .font(.system(size: 8).bold())
                                .foregroundStyle(.white)
                                .padding(2)
                                .background(.red)
                                .clipShape(Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 8)
        .onAppear { requestPermissions() }
    }

    private var responseArea: some View {
        Group {
            switch voiceVM.state {
            case .idle:
                Text("Toque para falar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

            case .listening:
                HStack(spacing: 4) {
                    AudioWaveformView()
                        .frame(width: 32, height: 14)
                    Text(voiceVM.partialTranscript.isEmpty ? "Ouvindo..." : voiceVM.partialTranscript)
                        .font(.caption2)
                        .lineLimit(2)
                }

            case .processing:
                HStack(spacing: 4) {
                    ProgressView().scaleEffect(0.5)
                    Text("Pensando...").font(.caption2).foregroundStyle(.secondary)
                }

            case .responding(let text):
                Text(text)
                    .font(.caption2)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .transition(.opacity)

            case .error(let msg):
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .frame(height: 38)
        .animation(.easeInOut(duration: 0.2), value: voiceVM.state)
    }

    private var voiceButton: some View {
        Button {
            switch voiceVM.state {
            case .idle:        voiceVM.startListening()
            case .listening:   voiceVM.stopListening()
            default:           voiceVM.resetToIdle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 48, height: 48)
                Image(systemName: buttonIcon)
                    .font(.title3)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private var buttonColor: Color {
        switch voiceVM.state {
        case .listening:  return .red
        case .processing: return .orange
        default:          return .blue
        }
    }

    private var buttonIcon: String {
        switch voiceVM.state {
        case .listening:  return "stop.fill"
        case .processing: return "ellipsis"
        default:          return "mic.fill"
        }
    }

    private func requestPermissions() {
        Task {
            let granted = await container.speechTranscriber.requestPermissions()
            if !granted {
                print("⚠️ Permissão de microfone/speech negada")
            }
        }
    }
}

// MARK: - Preview

#Preview("Main Watch V1") {
    MainPetVoiceView(voiceVM: VoiceInteractionViewModel(container: .preview))
        .environmentObject(WatchAppContainerV1.preview)
        .environmentObject(WatchConnectivityBridge.shared)
}
