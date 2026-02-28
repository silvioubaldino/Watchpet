// MARK: - VoiceInteractionViewModel
// Coordena o pipeline completo de interação por voz no Watch:
// Transcrição → Classificação → UseCase → Resposta do Pet → TTS
// (AyD v2.0, Seção 2.2 — Jornada Principal do Usuário)

import Foundation
import AVFoundation
import Combine

@MainActor
public final class VoiceInteractionViewModel: ObservableObject {

    // MARK: - State

    public enum State: Equatable {
        case idle
        case listening
        case processing
        case responding(String)
        case error(String)
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var partialTranscript: String = ""
    @Published public private(set) var petResponse: PetResponse?
    @Published public private(set) var activeTimer: TimerRecord?
    @Published public private(set) var pendingRemindersCount: Int = 0

    // MARK: - Dependencies

    private let transcriber: SpeechTranscriber
    private let classifier: IntentClassifierProtocol
    private let petStateManager: PetStateManager

    private let createReminderUC: CreateReminderUseCase
    private let cancelReminderUC: CancelReminderUseCase
    private let snoozeReminderUC: SnoozeReminderUseCase
    private let fetchRemindersUC: FetchRemindersUseCase
    private let createTimerUC: CreateTimerUseCase
    private let completeTimerUC: CompleteTimerUseCase
    private let saveNoteUC: SaveNoteUseCase
    private let logHabitUC: LogHabitUseCase
    private let getDailySummaryUC: GetDailySummaryUseCase
    private let saveConversationUC: SaveConversationUseCase

    private let synthesizer = AVSpeechSynthesizer()
    private var timerTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init(container: WatchAppContainerV1) {
        self.transcriber = container.speechTranscriber
        self.classifier = container.intentClassifier
        self.petStateManager = container.petStateManager
        self.createReminderUC = container.createReminder
        self.cancelReminderUC = container.cancelReminder
        self.snoozeReminderUC = container.snoozeReminder
        self.fetchRemindersUC = container.fetchReminders
        self.createTimerUC = container.createTimer
        self.completeTimerUC = container.completeTimer
        self.saveNoteUC = container.saveNote
        self.logHabitUC = container.logHabit
        self.getDailySummaryUC = container.getDailySummary
        self.saveConversationUC = container.saveConversation

        setupTranscriberBinding()
        Task { await refreshPendingCount() }
    }

    // MARK: - Público

    public func startListening() {
        guard state == .idle else { return }
        transcriber.startListening()
        state = .listening
    }

    public func stopListening() {
        transcriber.stopListening()
    }

    public func resetToIdle() {
        transcriber.resetToIdle()
        state = .idle
        partialTranscript = ""
    }

    // MARK: - Pipeline de voz

    private func setupTranscriberBinding() {
        transcriber.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] newState in
                guard let self else { return }
                switch newState {
                case .listening:
                    self.state = .listening
                case .result(let transcript):
                    Task { await self.process(transcript: transcript) }
                case .error(let msg):
                    self.state = .error(msg)
                default:
                    break
                }
            }
            .store(in: &cancellables)

        transcriber.$partialTranscript
            .receive(on: RunLoop.main)
            .assign(to: &$partialTranscript)
    }

    private func process(transcript: String) async {
        guard !transcript.isEmpty else {
            state = .idle
            return
        }

        state = .processing
        petStateManager.onProcessingStarted()

        let intent = classifier.classify(transcript)
        let response: PetResponse

        do {
            response = try await executeUseCase(for: intent, transcript: transcript)
        } catch {
            response = PetResponse(
                text: "Algo deu errado: \(error.localizedDescription)",
                emotion: .thinking
            )
        }

        // Salva conversa no histórico
        try? await saveConversationUC.execute(
            transcript: transcript,
            response: response.text,
            intent: intent.type,
            emotion: response.emotion
        )

        petResponse = response
        state = .responding(response.text)
        petStateManager.onProcessingCompleted()

        // Fala a resposta
        speak(response.text)

        // Haptic
        if response.shouldVibrate {
            WKInterfaceDevice.current().play(.success)
        }

        // Volta ao idle após resposta
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if case .responding = self.state { self.state = .idle }
        }

        await refreshPendingCount()
    }

    // MARK: - UseCase Dispatcher

    private func executeUseCase(for intent: ClassifiedIntent, transcript: String) async throws -> PetResponse {
        let entities = intent.extractedEntities
        let response = petStateManager.respond(to: intent, transcript: transcript)

        switch intent.type {

        case .reminder:
            let date = entities.dateTime ?? Date().addingTimeInterval(60 * 60)
            let title = entities.reminderTitle ?? transcript
            _ = try await createReminderUC.execute(.init(
                title: title,
                triggerDate: date,
                repeatInterval: nil
            ))

        case .timer:
            let duration = entities.duration ?? 25 * 60
            let type: TimerType = entities.timerLabel?.lowercased().contains("água") == true ? .water : .focus
            let timer = try await createTimerUC.execute(.init(
                duration: duration,
                label: entities.timerLabel,
                type: type
            ))
            startTimerCountdown(timer: timer)

        case .note:
            _ = try await saveNoteUC.execute(.init(
                rawText: entities.noteContent ?? transcript,
                connectorID: entities.connectorID
            ))

        case .habit:
            let lower = transcript.lowercased()
            let habitType: LogHabitUseCase.HabitType = lower.contains("água") ? .hydration : .posture
            _ = try await logHabitUC.execute(habitType)

        case .conversation:
            // Para "como estou indo hoje?" — retorna resumo
            if transcript.lowercased().contains("como estou") || transcript.lowercased().contains("meu dia") {
                let summary = try await getDailySummaryUC.execute()
                return PetResponse(
                    text: summary.summaryText,
                    emotion: summary.hydrationProgress >= 0.5 ? .happy : .missing
                )
            }

        case .settings:
            // PetStateManager já atualizou o nome em respond(to:)
            break

        case .unknown:
            break
        }

        return response
    }

    // MARK: - Timer Countdown

    private func startTimerCountdown(timer: TimerRecord) {
        timerTask?.cancel()
        activeTimer = timer

        timerTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(timer.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.activeTimer = nil
                WKInterfaceDevice.current().play(.notification)
                let finishResponse = PetResponse(
                    text: "Tempo esgotado! \(timer.label.map { "Timer '\($0)' " } ?? "")Ótimo trabalho! 🎉",
                    emotion: .excited,
                    shouldVibrate: true
                )
                self.petResponse = finishResponse
                self.speak(finishResponse.text)
            }

            try? await completeTimerUC.execute(timerID: timer.id, type: timer.type)
        }
    }

    // MARK: - TTS

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "pt-BR")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.1
        synthesizer.speak(utterance)
    }

    // MARK: - Helpers

    private func refreshPendingCount() async {
        let reminders = (try? await fetchRemindersUC.executePending()) ?? []
        pendingRemindersCount = reminders.count
    }
}
