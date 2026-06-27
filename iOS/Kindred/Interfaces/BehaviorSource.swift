import Foundation

/// Daily behavioral signals derived from health/motion sensors.
/// All values are pre-normalized to 0–100 by the implementation before delivery.
/// The real implementation reads CoreMotion + HealthKit; the mock provides preset lives + sliders.
struct DailySignals: Sendable {
    /// 0 (sedentary) – 100 (~12k+ steps). Feeds Vigor.
    let steps: Double
    /// 0–100, kcal vs personal rolling baseline. Feeds Vigor.
    let activeEnergy: Double
    /// 0–100, share of activity occurring between 23:00–04:00. Feeds Nocturnality.
    let nightActivityShare: Double
    /// 0–100, inverse variance of sleep-onset time. Feeds Discipline.
    let sleepRegularity: Double
    /// 0–100, care actions taken today vs target (6). Feeds Bond.
    let interactionCount: Double
    /// 0–100, how quickly the player answered "calls" today. Feeds Bond.
    let responseLatency: Double
}

/// Raw plausibility bounds — clamped here before touching any trait axis.
/// These are the integrity layer's first line of defense against injected values.
enum BehaviorBounds {
    static let stepsMax: Double          = 100_000
    static let activeEnergyMax: Double   = 10_000
    static let normalizedMin: Double     = 0
    static let normalizedMax: Double     = 100
}

@MainActor
protocol BehaviorSource: AnyObject {
    /// Most-recent daily signals. Call once per day (or on demand in debug).
    var currentSignals: DailySignals { get }

    /// Raw care-mistake count for the current stage (resets on evolution).
    var careMistakesThisStage: Int { get }

    /// Record a care-call miss. Called by CareEngine when a call window lapses.
    func recordCareMistake()

    /// Reset mistake counter (called by EvolutionEngine on each promotion).
    func resetCareMistakes()
}
