// MARK: - SpeechTranscriber
// Usa a API nativa de ditação do watchOS (presentTextInputController).
// Roda APENAS no Apple Watch target (WatchPet Watch App).

import Foundation
import AVFoundation
import Combine
import WatchKit

// MARK: - TranscriptionState

public enum TranscriptionState: Equatable {
    case idle
    case listening
    case processing
    case result(String)
    case error(String)
}

// MARK: - SpeechTranscriber

@MainActor
public final class SpeechTranscriber: NSObject, ObservableObject {

    @Published public private(set) var state: TranscriptionState = .idle
    @Published public private(set) var partialTranscript: String = ""

    public var onTranscriptReady: ((String) -> Void)?

    private let locale: Locale

    public init(locale: Locale = Locale(identifier: "pt-BR")) {
        self.locale = locale
        super.init()
    }

    // MARK: - Permissões

    public func requestPermissions() async -> Bool {
        let micStatus = await AVAudioApplication.requestRecordPermission()
        return micStatus
    }

    public var isAvailable: Bool { true }

    // MARK: - Ciclo de vida

    public func startListening() {
        guard state == .idle else { return }
        state = .listening

        // Usa visibleInterfaceController (funciona em SwiftUI Watch apps)
        let controller = WKExtension.shared().visibleInterfaceController

        guard let controller else {
            // Fallback: entrega estado de erro para o ViewModel poder reagir
            state = .error("Interface não disponível.")
            return
        }

        controller.presentTextInputController(
            withSuggestions: ["sim", "não", "lembrete", "nota", "timer"],
            allowedInputMode: .allowEmoji
        ) { [weak self] results in
            // O callback já vem na main thread no watchOS
            guard let self else { return }

            if let results, let text = results.first as? String, !text.isEmpty {
                self.partialTranscript = text
                self.deliverTranscript(text)
            } else {
                // Usuário cancelou ou não digitou/falou nada
                self.state = .idle
                self.partialTranscript = ""
            }
        }
    }

    public func stopListening() {
        // Com presentTextInputController, o sistema controla o input.
        // Apenas resetamos o estado local caso o usuário clique o botão de stop no app.
        state = .idle
        partialTranscript = ""
    }

    public func resetToIdle() {
        state = .idle
        partialTranscript = ""
    }

    // MARK: - Entrega do resultado

    private func deliverTranscript(_ transcript: String) {
        state = .result(transcript)
        onTranscriptReady?(transcript)
        partialTranscript = ""
    }
}
