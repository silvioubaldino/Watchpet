import WatchPetShared
// MARK: - PetStateManager
// Motor emocional do pet virtual (AyD v2.0, Seção 5.2 e 5.3).
// Gerencia estado emocional, personalidade e respostas do pet.
// Publicado como ObservableObject para binding direto com SwiftUI.

import Foundation
import Combine

// MARK: - PetResponse

public struct PetResponse {
    public let text: String
    public let emotion: PetEmotion
    public let shouldVibrate: Bool

    public init(text: String, emotion: PetEmotion, shouldVibrate: Bool = false) {
        self.text = text
        self.emotion = emotion
        self.shouldVibrate = shouldVibrate
    }
}

// MARK: - PetStateManager

@MainActor
public final class PetStateManager: ObservableObject {

    @Published public private(set) var currentEmotion: PetEmotion = .happy
    @Published public private(set) var petName: String = "Pet"
    @Published public private(set) var personality: PetPersonality = .enthusiastic
    @Published public private(set) var streakCount: Int = 0

    private var lastInteractionDate: Date = Date()
    private var idleCheckTimer: Timer?

    // MARK: - Setup

    public init() {
        startIdleCheck()
    }

    public func configure(profile: UserProfile) {
        petName = profile.petName
        personality = profile.petPersonality
        streakCount = profile.streakCount
    }

    // MARK: - Respostas por intenção

    public func respond(to intent: ClassifiedIntent, transcript: String) -> PetResponse {
        lastInteractionDate = Date()

        switch intent.type {
        case .timer:
            return respondToTimer(entities: intent.extractedEntities)
        case .reminder:
            return respondToReminder(entities: intent.extractedEntities)
        case .note:
            return respondToNote(entities: intent.extractedEntities)
        case .habit:
            return respondToHabit(transcript: transcript)
        case .settings:
            return respondToSettings(entities: intent.extractedEntities)
        case .conversation:
            return respondToConversation(transcript: transcript)
        case .unknown:
            return respondUnknown()
        }
    }

    // MARK: - Eventos do sistema

    public func onGoalCompleted() {
        currentEmotion = .excited
        scheduleReturnToHappy(after: 10)
    }

    public func onStreakMilestone() {
        currentEmotion = .celebrating
        streakCount += 1
        scheduleReturnToHappy(after: 15)
    }

    public func onSyncStarted() {
        currentEmotion = .syncing
    }

    public func onSyncCompleted() {
        currentEmotion = .happy
    }

    public func onProcessingStarted() {
        currentEmotion = .thinking
    }

    public func onProcessingCompleted() {
        currentEmotion = .happy
    }

    // MARK: - Idle check

    private func startIdleCheck() {
        idleCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateIdleState()
            }
        }
    }

    private func evaluateIdleState() {
        let elapsed = Date().timeIntervalSince(lastInteractionDate)
        let thirtyMinutes: TimeInterval = 30 * 60
        let twoHours: TimeInterval = 2 * 60 * 60

        switch elapsed {
        case ..<thirtyMinutes:
            if currentEmotion == .sleeping || currentEmotion == .missing {
                currentEmotion = .happy
            }
        case thirtyMinutes..<twoHours:
            currentEmotion = .sleeping
        default:
            currentEmotion = .missing
        }
    }

    private func scheduleReturnToHappy(after seconds: TimeInterval) {
        Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentEmotion = .happy
            }
        }
    }

    // MARK: - Geração de resposta por personalidade

    private func respondToTimer(entities: IntentEntities) -> PetResponse {
        currentEmotion = .happy
        let duration = entities.duration.map { formatDuration($0) } ?? "isso"
        let label = entities.timerLabel.map { " pro \($0)" } ?? ""

        switch personality {
        case .enthusiastic:
            return PetResponse(
                text: "Timer de \(duration)\(label) ativado! Arrasaaaaa! 🎉",
                emotion: .excited,
                shouldVibrate: true
            )
        case .sarcastic:
            return PetResponse(
                text: "Timer de \(duration)\(label). Lá vamos nós.",
                emotion: .happy
            )
        case .wise:
            return PetResponse(
                text: "Timer de \(duration)\(label) iniciado. Que o tempo seja bem aproveitado.",
                emotion: .happy
            )
        case .minimalist:
            return PetResponse(
                text: "\(duration)\(label). Timer ativo.",
                emotion: .happy
            )
        case .curious:
            return PetResponse(
                text: "Timer de \(duration)\(label)! O que você vai fazer nesse tempo?",
                emotion: .excited
            )
        }
    }

    private func respondToReminder(entities: IntentEntities) -> PetResponse {
        currentEmotion = .happy
        let title = entities.reminderTitle ?? "isso"

        switch personality {
        case .enthusiastic:
            return PetResponse(
                text: "Anotei! Vou te lembrar de \(title)! Pode contar comigo! 🐾",
                emotion: .happy,
                shouldVibrate: true
            )
        case .sarcastic:
            return PetResponse(
                text: "Ok, lembrete salvo. Não culpe a mim se você ignorar.",
                emotion: .happy
            )
        case .wise:
            return PetResponse(
                text: "Lembrete criado para \(title). Sua atenção será bem direcionada.",
                emotion: .happy
            )
        case .minimalist:
            return PetResponse(text: "Lembrete: \(title).", emotion: .happy)
        case .curious:
            return PetResponse(
                text: "Lembrete criado! \(title)... por que isso é importante para você?",
                emotion: .happy
            )
        }
    }

    private func respondToNote(entities: IntentEntities) -> PetResponse {
        let syncMsg = entities.connectorID.map { " Vou sincronizar com \($0)!" } ?? ""

        switch personality {
        case .enthusiastic:
            return PetResponse(
                text: "Nota salva!\(syncMsg) Sua mente está livre agora! 📝✨",
                emotion: .happy,
                shouldVibrate: true
            )
        case .sarcastic:
            return PetResponse(
                text: "Salvo.\(syncMsg) Pelo menos um de nós é organizado.",
                emotion: .happy
            )
        case .wise:
            return PetResponse(
                text: "Nota registrada.\(syncMsg) Escrever é a melhor forma de não esquecer.",
                emotion: .happy
            )
        case .minimalist:
            return PetResponse(text: "Nota salva.\(syncMsg)", emotion: .happy)
        case .curious:
            return PetResponse(
                text: "Anotado!\(syncMsg) Que insight interessante! Vai desenvolver mais?",
                emotion: .excited
            )
        }
    }

    private func respondToHabit(transcript: String) -> PetResponse {
        let isHydration = transcript.lowercased().contains("agua") || transcript.lowercased().contains("água")

        switch personality {
        case .enthusiastic:
            let msg = isHydration ? "ISSO! Hidratação registrada! Você é incrível! 💧🎊" : "Hábito registrado! Continue assim, você arrasando demais!"
            return PetResponse(text: msg, emotion: .excited, shouldVibrate: true)
        case .sarcastic:
            return PetResponse(text: isHydration ? "Uau, bebeu água. Revolucionário." : "Anotado. Bom trabalho, acho.", emotion: .happy)
        case .wise:
            return PetResponse(text: isHydration ? "Hidratação registrada. Pequenos gestos constroem grandes hábitos." : "Hábito registrado. A consistência é tudo.", emotion: .happy)
        case .minimalist:
            return PetResponse(text: isHydration ? "Hidratação +1." : "Hábito registrado.", emotion: .happy)
        case .curious:
            return PetResponse(text: isHydration ? "Água anotada! Sabia que o corpo é 60% água? Incrível né?" : "Hábito anotado! Como você se sente?", emotion: .excited)
        }
    }

    private func respondToSettings(entities: IntentEntities) -> PetResponse {
        if let newName = entities.petName {
            petName = newName
            return PetResponse(
                text: "\(newName)... Adorei! Esse sou eu agora! 🐾",
                emotion: .celebrating,
                shouldVibrate: true
            )
        }
        return PetResponse(text: "Configuração atualizada!", emotion: .happy)
    }

    private func respondToConversation(transcript: String) -> PetResponse {
        switch personality {
        case .enthusiastic:
            return PetResponse(text: "Estou aqui! O que você precisa? Pode falar!", emotion: .happy)
        case .sarcastic:
            return PetResponse(text: "Sim, estou ouvindo. Continue.", emotion: .happy)
        case .wise:
            return PetResponse(text: "Presente. Como posso ajudar?", emotion: .happy)
        case .minimalist:
            return PetResponse(text: "Pronto.", emotion: .happy)
        case .curious:
            return PetResponse(text: "Oiii! O que você quis dizer com '\(transcript.prefix(30))'?", emotion: .excited)
        }
    }

    private func respondUnknown() -> PetResponse {
        switch personality {
        case .enthusiastic:
            return PetResponse(text: "Hmm, não entendi bem! Pode repetir? 🐾", emotion: .thinking)
        case .sarcastic:
            return PetResponse(text: "Não fiz ideia do que você disse.", emotion: .thinking)
        case .wise:
            return PetResponse(text: "Poderia reformular? Não captei a intenção.", emotion: .thinking)
        case .minimalist:
            return PetResponse(text: "Não entendido. Repita.", emotion: .thinking)
        case .curious:
            return PetResponse(text: "Hm! Não entendi! O que você quis dizer?", emotion: .thinking)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 && secs == 0 {
            return "\(minutes) minuto\(minutes > 1 ? "s" : "")"
        } else if minutes > 0 {
            return "\(minutes)min \(secs)s"
        } else {
            return "\(secs) segundo\(secs > 1 ? "s" : "")"
        }
    }
}
