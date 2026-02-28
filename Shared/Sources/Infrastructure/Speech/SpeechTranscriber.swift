// MARK: - SpeechTranscriber
// Pipeline de transcrição on-device (AyD v2.0, Seção 3.2).
// Usa SFSpeechRecognizer em modo offline para garantir privacidade e baixa latência.
// Roda APENAS no Apple Watch target.

import Foundation
import AVFoundation
import Combine

#if canImport(Speech)
import Speech
#endif

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

    #if canImport(Speech)
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    #endif

    private let audioEngine = AVAudioEngine()

    private var silenceTimer: Timer?
    private var maxDurationTimer: Timer?

    /// Callback chamado com o transcript final ao encerrar a escuta.
    public var onTranscriptReady: ((String) -> Void)?

    public init(locale: Locale = Locale(identifier: "pt-BR")) {
        self.locale = locale
        super.init()
        #if canImport(Speech)
        configureSpeechRecognizer()
        #endif
    }

    // MARK: - Setup
    
    #if canImport(Speech)
    private func configureSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.defaultTaskHint = .dictation
    }
    #endif

    // MARK: - Permissões

    public func requestPermissions() async -> Bool {
        #if canImport(Speech)
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }
        #endif

        // Permissão de microfone (iOS/watchOS)
        let micStatus = await AVAudioApplication.requestRecordPermission()
        return micStatus
    }

    public var isAvailable: Bool {
        #if canImport(Speech)
        #if targetEnvironment(simulator)
        return true // Simuladores freq. reportam false em isAvailable de forma incorreta
        #else
        return speechRecognizer?.isAvailable == true
        #endif
        #else
        return false
        #endif
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
        #if targetEnvironment(simulator)
        // No watchOS, usamos apenas .playAndRecord sem as opções de iOS (.defaultToSpeaker)
        try session.setCategory(.playAndRecord, mode: .default, options: [])
        #else
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        #endif
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func endAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Reconhecimento

    private func startRecognition() throws {
        #if canImport(Speech)
        guard let recognizer = speechRecognizer else { throw NSError(domain: "SpeechTranscriber", code: 1) }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { throw NSError(domain: "SpeechTranscriber", code: 2) }

        request.shouldReportPartialResults = true
        // Força modo offline para privacidade
        // No simulador, manter `requiresOnDeviceRecognition = true` costuma causar falhas (offline dictation not supported)
        #if targetEnvironment(simulator)
        request.requiresOnDeviceRecognition = false
        #else
        request.requiresOnDeviceRecognition = true
        #endif

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }

        let inputNode = audioEngine.inputNode
        var format = inputNode.outputFormat(forBus: 0)
        
        // Contorno para bug clássico de áudio do Simulador (0Hz sample rate / -10851)
        if format.sampleRate == 0 {
            format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) ?? format
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        #else
        throw NSError(domain: "SpeechTranscriber", code: 3, userInfo: [NSLocalizedDescriptionKey: "Reconhecimento não suportado"])
        #endif
    }
    
    #if canImport(Speech)
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
    #endif

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
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        #if canImport(Speech)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        #endif
        endAudioSession()
    }

    public func resetToIdle() {
        cleanUp()
        state = .idle
        partialTranscript = ""
    }
}
