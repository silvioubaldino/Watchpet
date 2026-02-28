// MARK: - IntentClassifier
// Classificador de intenção leve para o MVP (AyD v2.0, Seção 3.3).
// MVP: regras heurísticas + keywords. v2: substituir pelo modelo CoreML fine-tuned (~50M params).
// Latência alvo: < 300ms on-device.

import Foundation

// MARK: - ClassifiedIntent

public struct ClassifiedIntent {
    public let type: IntentType
    public let confidence: Float       // 0.0 – 1.0
    public let extractedEntities: IntentEntities

    public init(type: IntentType, confidence: Float, extractedEntities: IntentEntities = .empty) {
        self.type = type
        self.confidence = confidence
        self.extractedEntities = extractedEntities
    }
}

// MARK: - IntentEntities

public struct IntentEntities {
    public var dateTime: Date?
    public var duration: TimeInterval?   // segundos
    public var reminderTitle: String?
    public var noteContent: String?
    public var timerLabel: String?
    public var petName: String?
    public var settingKey: String?
    public var connectorID: String?      // "notion", "gcal" etc.

    public static let empty = IntentEntities()

    public init(
        dateTime: Date? = nil,
        duration: TimeInterval? = nil,
        reminderTitle: String? = nil,
        noteContent: String? = nil,
        timerLabel: String? = nil,
        petName: String? = nil,
        settingKey: String? = nil,
        connectorID: String? = nil
    ) {
        self.dateTime = dateTime
        self.duration = duration
        self.reminderTitle = reminderTitle
        self.noteContent = noteContent
        self.timerLabel = timerLabel
        self.petName = petName
        self.settingKey = settingKey
        self.connectorID = connectorID
    }
}

// MARK: - IntentClassifierProtocol

public protocol IntentClassifierProtocol {
    func classify(_ transcript: String) -> ClassifiedIntent
}

// MARK: - RuleBasedIntentClassifier (MVP)

/// Classificador heurístico por palavras-chave.
/// Substituir por CoreMLIntentClassifier quando o modelo estiver pronto.
public final class RuleBasedIntentClassifier: IntentClassifierProtocol {

    public init() {}

    public func classify(_ transcript: String) -> ClassifiedIntent {
        let text = transcript.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        // Ordem importa: verificar intenções mais específicas primeiro
        if let intent = tryTimer(text, original: transcript)    { return intent }
        if let intent = tryReminder(text, original: transcript) { return intent }
        if let intent = tryNote(text, original: transcript)     { return intent }
        if let intent = tryHabit(text)                          { return intent }
        if let intent = trySettings(text, original: transcript) { return intent }

        return ClassifiedIntent(type: .conversation, confidence: 0.5)
    }

    // MARK: - Timer

    private func tryTimer(_ text: String, original: String) -> ClassifiedIntent? {
        let timerKeywords = ["timer", "cronometr", "pomodoro", "minuto", "segundo", "hora"]
        guard timerKeywords.contains(where: { text.contains($0) }) else { return nil }

        var entities = IntentEntities()

        // Extrai duração: "25 minutos", "3 segundos", "1 hora"
        if let duration = extractDuration(from: text) {
            entities = IntentEntities(duration: duration)
        }

        // Extrai label: "timer de 3 minutos pro café" → "café"
        if let label = extractTimerLabel(from: text) {
            entities = IntentEntities(duration: entities.duration, timerLabel: label)
        }

        return ClassifiedIntent(type: .timer, confidence: 0.85, extractedEntities: entities)
    }

    // MARK: - Reminder

    private func tryReminder(_ text: String, original: String) -> ClassifiedIntent? {
        let reminderKeywords = ["lembra", "lembrete", "avisa", "notifica", "nao esquece"]
        guard reminderKeywords.contains(where: { text.contains($0) }) else { return nil }

        var entities = IntentEntities()

        // Extrai horário absoluto: "às 8 da manhã", "às 14h"
        if let date = extractAbsoluteTime(from: text) {
            entities = IntentEntities(dateTime: date)
        }

        // Extrai título do lembrete removendo verbos de comando
        let title = extractReminderTitle(from: original)
        entities = IntentEntities(
            dateTime: entities.dateTime,
            reminderTitle: title.isEmpty ? nil : title
        )

        return ClassifiedIntent(type: .reminder, confidence: 0.88, extractedEntities: entities)
    }

    // MARK: - Note

    private func tryNote(_ text: String, original: String) -> ClassifiedIntent? {
        let noteKeywords = ["anot", "salva", "guarda", "escreve", "nota", "lembra disso"]
        guard noteKeywords.contains(where: { text.contains($0) }) else { return nil }

        // Detecta destino de integração: "manda pro notion"
        var connectorID: String? = nil
        if text.contains("notion")  { connectorID = "notion" }
        if text.contains("calendar") || text.contains("agenda") { connectorID = "gcal" }

        let content = extractNoteContent(from: original)
        let entities = IntentEntities(noteContent: content, connectorID: connectorID)

        return ClassifiedIntent(type: .note, confidence: 0.87, extractedEntities: entities)
    }

    // MARK: - Habit

    private func tryHabit(_ text: String) -> ClassifiedIntent? {
        let habitKeywords = ["bebi agua", "tomei agua", "agua", "postura", "levantei", "pausa", "como estou"]
        guard habitKeywords.contains(where: { text.contains($0) }) else { return nil }
        return ClassifiedIntent(type: .habit, confidence: 0.82)
    }

    // MARK: - Settings

    private func trySettings(_ text: String, original: String) -> ClassifiedIntent? {
        let settingsKeywords = ["muda", "configura", "ativa", "desativa", "nome do pet", "personalidade"]
        guard settingsKeywords.contains(where: { text.contains($0) }) else { return nil }

        var entities = IntentEntities()

        // "muda seu nome para Rex"
        if text.contains("nome"), let name = extractPetName(from: original) {
            entities = IntentEntities(petName: name)
        }

        return ClassifiedIntent(type: .settings, confidence: 0.75, extractedEntities: entities)
    }

    // MARK: - Entity Extraction Helpers

    private func extractDuration(from text: String) -> TimeInterval? {
        // Padrão: número + unidade de tempo
        let pattern = #"(\d+)\s*(minuto|segundo|hora)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let value = Double(text[numRange])
        else { return nil }

        let unit = String(text[unitRange])
        switch unit {
        case "segundo": return value
        case "minuto":  return value * 60
        case "hora":    return value * 3600
        default:        return nil
        }
    }

    private func extractAbsoluteTime(from text: String) -> Date? {
        // Padrão simples: "às HH" ou "às HHh" ou "às HH:MM"
        let pattern = #"as\s+(\d{1,2})(?::(\d{2}))?\s*(?:da\s+(manha|tarde|noite)|h)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hourRange = Range(match.range(at: 1), in: text),
              let hour = Int(text[hourRange])
        else { return nil }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        components.second = 0

        // Ajusta tarde/noite
        if let periodRange = Range(match.range(at: 3), in: text) {
            let period = String(text[periodRange])
            if (period == "tarde" || period == "noite") && hour < 12 {
                components.hour = hour + 12
            }
        }

        return Calendar.current.date(from: components)
    }

    private func extractReminderTitle(from original: String) -> String {
        let removePatterns = ["me lembra", "lembra de", "lembrete de", "avisa quando", "me avisa"]
        var result = original
        for pattern in removePatterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: .caseInsensitive
            )
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractNoteContent(from original: String) -> String {
        let removePatterns = ["anota:", "anota", "salva nota", "guarda isso:", "guarda isso"]
        var result = original
        for pattern in removePatterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: .caseInsensitive
            )
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTimerLabel(from text: String) -> String? {
        // "timer de X minutos pro/para LABEL"
        let pattern = #"(?:pro|para)\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let labelRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractPetName(from original: String) -> String? {
        let pattern = #"(?:nome para|nome pro|chamar de|chama de)\s+(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: original, range: NSRange(original.startIndex..., in: original)),
              let nameRange = Range(match.range(at: 1), in: original)
        else { return nil }
        return String(original[nameRange])
    }
}
