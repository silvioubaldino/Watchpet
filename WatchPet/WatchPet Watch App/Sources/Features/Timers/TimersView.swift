import WatchPetShared
// MARK: - TimersView
// Tela de timers no Apple Watch — Pomodoro, cronômetro, timers customizados.
// (AyD v2.0, Seção 3.1 — Módulo ⏱ Timer & Cronômetro)

import SwiftUI
import Combine

// MARK: - TimersViewModel

@MainActor
public final class TimersViewModel: ObservableObject {

    @Published public private(set) var activeTimer: TimerRecord?
    @Published public private(set) var elapsed: TimeInterval = 0
    @Published public private(set) var remaining: TimeInterval = 0
    @Published public private(set) var isRunning = false
    @Published public var errorMessage: String?

    private let createUC: CreateTimerUseCase
    private let completeUC: CompleteTimerUseCase
    private let timerRepo: TimerRepository

    private var countdownTask: Task<Void, Never>?

    public init(container: WatchAppContainer) {
        self.createUC = container.createTimer
        self.completeUC = container.completeTimer
        self.timerRepo = container.timerRepository
    }

    public func loadActive() async {
        activeTimer = try? await timerRepo.fetchActive()
        if let timer = activeTimer {
            remaining = timer.remaining
            elapsed = timer.elapsed
            isRunning = timer.isRunning
            if isRunning { startCountdown() }
        }
    }

    public func start(duration: TimeInterval, label: String? = nil, type: TimerType = .focus) async {
        do {
            let timer = try await createUC.execute(.init(duration: duration, label: label, type: type))
            activeTimer = timer
            elapsed = 0
            remaining = duration
            isRunning = true
            startCountdown()
            #if os(watchOS)
            WKInterfaceDevice.current().play(.start)
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func stop() async {
        guard let timer = activeTimer else { return }
        countdownTask?.cancel()
        try? await completeUC.execute(timerID: timer.id, type: timer.type)
        activeTimer = nil
        isRunning = false
        elapsed = 0
        remaining = 0
        #if os(watchOS)
        WKInterfaceDevice.current().play(.stop)
        #endif
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                guard let timer = activeTimer else { break }
                await MainActor.run {
                    self.elapsed = timer.elapsed
                    self.remaining = timer.remaining
                    if self.remaining <= 0 {
                        self.isRunning = false
                        #if os(watchOS)
                        WKInterfaceDevice.current().play(.notification)
                        #endif
                    }
                }
                if remaining <= 0 { break }
            }
        }
    }
}

// MARK: - TimersView

public struct TimersView: View {

    @StateObject private var viewModel: TimersViewModel

    public init(container: WatchAppContainer) {
        _viewModel = StateObject(wrappedValue: TimersViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let timer = viewModel.activeTimer {
                    ActiveTimerView(
                        timer: timer,
                        remaining: viewModel.remaining,
                        elapsed: viewModel.elapsed,
                        onStop: { Task { await viewModel.stop() } }
                    )
                } else {
                    timerOptions
                }
            }
            .navigationTitle("⏱ Timer")
        }
        .task { await viewModel.loadActive() }
    }

    private var timerOptions: some View {
        List {
            Section("Rápido") {
                TimerOptionRow(
                    icon: "🍅",
                    title: "Pomodoro",
                    subtitle: "25 minutos de foco",
                    color: .red
                ) {
                    Task { await viewModel.start(duration: 25 * 60, label: "Pomodoro", type: .focus) }
                }

                TimerOptionRow(
                    icon: "💧",
                    title: "Hidratação",
                    subtitle: "Lembrete em 1 hora",
                    color: .blue
                ) {
                    Task { await viewModel.start(duration: 60 * 60, label: "Água", type: .water) }
                }

                TimerOptionRow(
                    icon: "☕️",
                    title: "Pausa curta",
                    subtitle: "5 minutos",
                    color: .orange
                ) {
                    Task { await viewModel.start(duration: 5 * 60, label: "Pausa") }
                }
            }

            Section("Custom") {
                NavigationLink(destination: CustomTimerView(viewModel: viewModel)) {
                    Label("Definir tempo", systemImage: "slider.horizontal.3")
                        .font(.caption)
                }
            }
        }
        #if os(watchOS)
        .listStyle(.carousel)
        #endif
    }
}

// MARK: - ActiveTimerView

struct ActiveTimerView: View {

    let timer: TimerRecord
    let remaining: TimeInterval
    let elapsed: TimeInterval
    let onStop: () -> Void

    private var progress: Double {
        guard timer.duration > 0 else { return 0 }
        return elapsed / timer.duration
    }

    var body: some View {
        VStack(spacing: 8) {
            // Ring de progresso
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: progress)

                VStack(spacing: 2) {
                    Text(formatTime(remaining))
                        .font(.title3.monospacedDigit().bold())

                    if let label = timer.label {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 100, height: 100)

            Button("Parar", action: onStop)
                .buttonStyle(.bordered)
                .tint(.red)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }

    private var timerColor: Color {
        switch timer.type {
        case .focus:  return .red
        case .water:  return .blue
        case .custom: return .green
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }
}

// MARK: - TimerOptionRow

struct TimerOptionRow: View {

    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(icon)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption.bold())
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .tint(color)
    }
}

// MARK: - CustomTimerView

struct CustomTimerView: View {

    @ObservedObject var viewModel: TimersViewModel
    @State private var minutes: Int = 10
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("\(minutes) min")
                .font(.title2.bold())

            Picker("Minutos", selection: $minutes) {
                ForEach([1, 2, 3, 5, 10, 15, 20, 25, 30, 45, 60], id: \.self) { m in
                    Text("\(m) min").tag(m)
                }
            }
            .labelsHidden()

            Button("Iniciar") {
                Task {
                    await viewModel.start(duration: TimeInterval(minutes * 60))
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .font(.caption)
        }
        .navigationTitle("Timer Custom")
    }
}

// MARK: - Preview

#Preview("Timers — Idle") {
    TimersView(container: .preview)
}
