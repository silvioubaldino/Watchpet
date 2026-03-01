import WatchPetShared
// MARK: - WatchPet App Entry Point
// Target: WatchPet_Watch
// Ponto de entrada do Apple Watch app com SwiftUI.

import SwiftUI

@main
struct WatchPetApp: App {

    @State private var container = WatchAppContainer()
    @StateObject private var connectivity = WatchConnectivityBridge.shared
    @StateObject private var petStateManager = PetStateManager()

    var body: some Scene {
        WindowGroup {
            MainWatchView()
                .environment(container)
                .environmentObject(connectivity)
                .environmentObject(petStateManager)
                .onAppear {
                    petStateManager.configure(profile: container.userProfileRepository.load())
                }
        }
    }
}

// MARK: - MainWatchView

struct MainWatchView: View {

    @Environment(WatchAppContainer.self) var container
    @EnvironmentObject var petStateManager: PetStateManager
    @StateObject private var voiceVM: VoiceInteractionViewModel

    init() {
        // VoiceInteractionViewModel será configurado com o container real no onAppear
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

            // Tab 4 — Notas
            NotesView()
                .environment(container)
                .tag(3)
        }
        .tabViewStyle(.page)
        .onAppear {
            // Sincroniza o VM com o container real injetado
            voiceVM.updateContainer(container, petStateManager: petStateManager)
            requestPermissions()
        }
    }

    private func requestPermissions() {
        Task {
            let speechGranted = await container.speechTranscriber.requestPermissions()
            if !speechGranted {
                print("⚠️ Permissão de microfone/speech negada")
            }
            
            do {
                let healthGranted = try await HealthKitManager.shared.requestAuthorization()
                if !healthGranted {
                    print("⚠️ Permissão de HealthKit negada ou indisponível")
                }
            } catch {
                print("⚠️ Erro ao pedir HealthKit: \(error)")
            }
        }
    }
}

// MARK: - MainPetVoiceView

struct MainPetVoiceView: View {

    @Environment(WatchAppContainer.self) var container
    @EnvironmentObject var petStateManager: PetStateManager
    @ObservedObject var voiceVM: VoiceInteractionViewModel

    var body: some View {
        VStack(spacing: 6) {

            // Avatar do pet
            PetAvatarView(
                emotion: petStateManager.currentEmotion,
                petName: petStateManager.petName
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
}

// MARK: - PetAvatarView

struct PetAvatarView: View {

    let emotion: PetEmotion
    let petName: String

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(emotionColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Text(emotionEmoji)
                    .font(.system(size: 44))
                    .scaleEffect(isAnimating ? emotionScale : 1.0)
                    .animation(
                        Animation.easeInOut(duration: emotionAnimationDuration)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            .onAppear { isAnimating = true }
            .onChange(of: emotion) { _ in
                isAnimating = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isAnimating = true
                }
            }

            Text(petName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var emotionEmoji: String {
        switch emotion {
        case .sleeping:     return "😴"
        case .happy:        return "😊"
        case .thinking:     return "🤔"
        case .excited:      return "😄"
        case .missing:      return "😟"
        case .celebrating:  return "🎉"
        case .syncing:      return "🔄"
        }
    }

    private var emotionColor: Color {
        switch emotion {
        case .sleeping:     return .gray
        case .happy:        return .green
        case .thinking:     return .blue
        case .excited:      return .orange
        case .missing:      return .purple
        case .celebrating:  return .yellow
        case .syncing:      return .cyan
        }
    }

    private var emotionScale: CGFloat {
        switch emotion {
        case .excited, .celebrating: return 1.15
        case .sleeping:               return 0.95
        case .thinking, .syncing:     return 1.05
        default:                      return 1.08
        }
    }

    private var emotionAnimationDuration: Double {
        switch emotion {
        case .sleeping:             return 2.5
        case .excited, .celebrating: return 0.4
        case .thinking, .syncing:   return 0.8
        default:                    return 1.5
        }
    }
}

// MARK: - AudioWaveformView

struct AudioWaveformView: View {

    @State private var animating = false
    private let barCount = 5
    private let barHeights: [CGFloat] = [6, 12, 8, 14, 6]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(Color.green)
                    .frame(width: 3)
                    .frame(height: animating ? barHeights[index] : 4)
                    .animation(
                        Animation.easeInOut(duration: 0.3 + Double(index) * 0.08)
                            .repeatForever(autoreverses: true),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - Previews

#Preview("Main Watch") {
    MainWatchView()
        .environment(WatchAppContainer.preview)
        .environmentObject(WatchConnectivityBridge.shared)
}
