// MARK: - WatchPet App Entry Point
// Target: WatchPet_Watch
// Ponto de entrada do Apple Watch app com SwiftUI.

import SwiftUI

@main
struct WatchPetApp: App {

    @StateObject private var container = WatchAppContainer.preview // Substituir por produção
    @StateObject private var connectivity = WatchConnectivityBridge.shared

    var body: some Scene {
        WindowGroup {
            MainWatchView()
                .environmentObject(container)
                .environmentObject(connectivity)
        }
    }
}

// MARK: - MainWatchView

/// Tela principal do Watch — combina avatar do pet com área de interação por voz.
struct MainWatchView: View {

    @EnvironmentObject var container: WatchAppContainer
    @EnvironmentObject var connectivity: WatchConnectivityBridge

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // Avatar do pet
                PetAvatarView(
                    emotion: container.petStateManager.currentEmotion,
                    petName: container.petStateManager.petName
                )
                .frame(height: 100)

                // Área de transcrição e status
                TranscriptionStatusView(
                    transcriber: container.speechTranscriber
                )

                // Botão principal de ativação por voz
                VoiceActivationButton(
                    transcriber: container.speechTranscriber
                )
            }
            .padding(.horizontal, 8)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: QuickActionsView()) {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            setupTranscriberCallback()
        }
    }

    private func setupTranscriberCallback() {
        container.speechTranscriber.onTranscriptReady = { transcript in
            Task { @MainActor in
                handleTranscript(transcript)
            }
        }
    }

    @MainActor
    private func handleTranscript(_ transcript: String) {
        container.petStateManager.onProcessingStarted()

        let intent = container.intentClassifier.classify(transcript)
        let response = container.petStateManager.respond(to: intent, transcript: transcript)

        // TODO (Fase 1): executar UseCase correspondente ao intent
        // Ex: CreateReminderUseCase, CreateTimerUseCase, SaveNoteUseCase

        print("🐾 Intent: \(intent.type) | Resposta: \(response.text)")
        container.petStateManager.onProcessingCompleted()

        // Feedback háptico
        if response.shouldVibrate {
            WKInterfaceDevice.current().play(.success)
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

// MARK: - TranscriptionStatusView

struct TranscriptionStatusView: View {

    @ObservedObject var transcriber: SpeechTranscriber

    var body: some View {
        Group {
            switch transcriber.state {
            case .idle:
                Text("Levante o pulso ou toque para falar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

            case .listening:
                HStack(spacing: 4) {
                    AudioWaveformView()
                        .frame(width: 32, height: 16)
                    Text(transcriber.partialTranscript.isEmpty ? "Ouvindo..." : transcriber.partialTranscript)
                        .font(.caption2)
                        .lineLimit(2)
                }

            case .processing:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Processando...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

            case .result(let text):
                Text(text)
                    .font(.caption2)
                    .lineLimit(3)
                    .foregroundStyle(.primary)

            case .error(let message):
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .frame(height: 36)
        .padding(.horizontal, 4)
    }
}

// MARK: - AudioWaveformView

/// Animação simples de forma de onda de áudio enquanto escuta.
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

// MARK: - VoiceActivationButton

struct VoiceActivationButton: View {

    @ObservedObject var transcriber: SpeechTranscriber

    var body: some View {
        Button {
            switch transcriber.state {
            case .idle:
                transcriber.startListening()
            case .listening:
                transcriber.stopListening()
            default:
                transcriber.resetToIdle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 52, height: 52)

                Image(systemName: buttonIcon)
                    .font(.title3)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private var buttonColor: Color {
        switch transcriber.state {
        case .listening: return .red
        case .processing: return .orange
        default: return .blue
        }
    }

    private var buttonIcon: String {
        switch transcriber.state {
        case .listening: return "stop.fill"
        case .processing: return "ellipsis"
        default: return "mic.fill"
        }
    }
}

// MARK: - QuickActionsView

struct QuickActionsView: View {
    var body: some View {
        List {
            NavigationLink("⏱ Timers") {
                Text("Timer View — Fase 1")
            }
            NavigationLink("⏰ Lembretes") {
                Text("Reminders View — Fase 1")
            }
            NavigationLink("📝 Notas") {
                Text("Notes View — Fase 2")
            }
            NavigationLink("📊 Hábitos") {
                Text("Habits View — Fase 3")
            }
        }
        .navigationTitle("Ações")
    }
}

// MARK: - Previews

#Preview("Main Watch View") {
    MainWatchView()
        .environmentObject(WatchAppContainer.preview)
        .environmentObject(WatchConnectivityBridge.shared)
}

#Preview("Pet Avatars") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(PetEmotion.allCases, id: \.self) { emotion in
                PetAvatarView(emotion: emotion, petName: emotion.rawValue)
            }
        }
    }
}
