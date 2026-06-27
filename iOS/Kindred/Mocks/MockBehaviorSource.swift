import Foundation
import Combine

/// Preset behavior profiles for simulator testing.
enum BehaviorPreset: String, CaseIterable, Identifiable {
    case athlete     = "Athlete"
    case nightOwl    = "Night Owl"
    case neglected   = "Neglected"
    case balanced    = "Balanced"

    var id: String { rawValue }

    var signals: DailySignals {
        switch self {
        case .athlete:
            return DailySignals(steps: 95, activeEnergy: 90, nightActivityShare: 5,
                                sleepRegularity: 85, interactionCount: 75, responseLatency: 80)
        case .nightOwl:
            return DailySignals(steps: 40, activeEnergy: 35, nightActivityShare: 85,
                                sleepRegularity: 20, interactionCount: 60, responseLatency: 55)
        case .neglected:
            return DailySignals(steps: 20, activeEnergy: 15, nightActivityShare: 30,
                                sleepRegularity: 40, interactionCount: 10, responseLatency: 5)
        case .balanced:
            return DailySignals(steps: 55, activeEnergy: 50, nightActivityShare: 10,
                                sleepRegularity: 70, interactionCount: 70, responseLatency: 75)
        }
    }
}

@MainActor
final class MockBehaviorSource: BehaviorSource, ObservableObject {
    @Published var selectedPreset: BehaviorPreset = .balanced {
        didSet { recompute() }
    }

    // -1 means "use preset value"; 0–100 means manual override
    @Published var manualSteps:            Double = -1 { didSet { recompute() } }
    @Published var manualActiveEnergy:     Double = -1 { didSet { recompute() } }
    @Published var manualNightActivity:    Double = -1 { didSet { recompute() } }
    @Published var manualSleepRegularity:  Double = -1 { didSet { recompute() } }
    @Published var manualInteractionCount: Double = -1 { didSet { recompute() } }
    @Published var manualResponseLatency:  Double = -1 { didSet { recompute() } }

    private(set) var currentSignals: DailySignals
    private(set) var careMistakesThisStage: Int = 0

    init() {
        currentSignals = BehaviorPreset.balanced.signals
    }

    func recordCareMistake() { careMistakesThisStage += 1 }
    func resetCareMistakes() { careMistakesThisStage  = 0 }

    private func recompute() {
        let base = selectedPreset.signals
        currentSignals = DailySignals(
            steps:              manualSteps            >= 0 ? manualSteps            : base.steps,
            activeEnergy:       manualActiveEnergy     >= 0 ? manualActiveEnergy     : base.activeEnergy,
            nightActivityShare: manualNightActivity    >= 0 ? manualNightActivity    : base.nightActivityShare,
            sleepRegularity:    manualSleepRegularity  >= 0 ? manualSleepRegularity  : base.sleepRegularity,
            interactionCount:   manualInteractionCount >= 0 ? manualInteractionCount : base.interactionCount,
            responseLatency:    manualResponseLatency  >= 0 ? manualResponseLatency  : base.responseLatency
        )
    }
}
