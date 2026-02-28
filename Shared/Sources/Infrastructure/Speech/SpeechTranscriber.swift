// MARK: - SpeechTranscriber
// Pipeline de transcrição on-device (AyD v2.0, Seção 3.2).
// Usa SFSpeechRecognizer em modo offline para garantir privacidade e baixa latência.
// Roda APENAS no Apple Watch target.

import Foundation
import Speech
import AVFoundation
import Combine

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

    // Configurações
    private let locale: Locale
    private let silenceThreshold: TimeInterval = 1.2  // segundos — encerra segmento
    private let maxDuration: TimeInterval = 30.0       // timeout de segurança

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var silenceTimer: Timer?
    private var maxDurationTimer: Timer?

    /// Callback chamado com o transcript final ao encerrar a escuta.
    public var onTranscriptReady: ((String) -> Void)?

    public init(locale: Locale = Locale(identifier: "pt-BR")) {
        self.locale = locale
        super.init()
        configureSpeechRecognizer()
    }

    // MARK: - Setup

    private func configureSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.defaultTaskHint = .dictation
    }

    // MARK: - Permissões

    public func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        // Permissão de microfone (iOS/watchOS)
        let micStatus = await AVAudioApplication.requestRecordPermission()
        return micStatus
    }

    public var isAvailable: Bool {
        speechRecognizer?.isAvailable == true
    }

    // MARK: - Ciclo de vida

    public func startListening() {
        guard state == .idle else { return }
        guard isAvailable else {
            state = .error("Reconhecimento de voz não disponível offline neste momento.")
            return
        }

        do {
            try beginAudioSession()
            try startRecognition()
            state = .listening
            startMaxDurationTimer()
        } catch {
            state = .error("Falha ao iniciar microfone: \(error.localizedDescription)")
        }
    }

    public func stopListening() {
        guard state == .listening else { return }
        finalizeRecognition()
    }

    // MARK: - AVAudioSession

    private func beginAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func endAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Reconhecimento

    private func startRecognition() throws {
        guard let recognizer = speechRecognizer else { throw NSError(domain: "SpeechTranscriber", code: 1) }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { throw NSError(domain: "SpeechTranscriber", code: 2) }

        request.shouldReportPartialResults = true
        // Força modo offline para privacidade
        request.requiresOnDeviceRecognition = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            let transcript = result.bestTranscription.formattedString
            partialTranscript = transcript

            // Reinicia timer de silêncio a cada fala detectada
            resetSilenceTimer()

            if result.isFinal {
                deliverTranscript(transcript)
            }
        }

        if let error {
            if state == .listening {
                state = .error("Erro de reconhecimento: \(error.localizedDescription)")
            }
            cleanUp()
        }
    }

    // MARK: - Timers

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(
            withTimeInterval: silenceThreshold,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finalizeRecognition()
            }
        }
    }

    private func startMaxDurationTimer() {
        maxDurationTimer = Timer.scheduledTimer(
            withTimeInterval: maxDuration,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finalizeRecognition()
            }
        }
    }

    // MARK: - Finalização

    private func finalizeRecognition() {
        let transcript = partialTranscript
        cleanUp()
        if !transcript.isEmpty {
            deliverTranscript(transcript)
        } else {
            state = .idle
        }
    }

    private func deliverTranscript(_ transcript: String) {
        state = .result(transcript)
        onTranscriptReady?(transcript)
        partialTranscript = ""
    }

    private func cleanUp() {
        silenceTimer?.invalidate()
        maxDurationTimer?.invalidate()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        endAudioSession()
    }

    public func resetToIdle() {
        cleanUp()
        state = .idle
        partialTranscript = ""
    }
}
