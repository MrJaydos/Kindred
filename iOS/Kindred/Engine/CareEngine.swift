import Foundation

// MARK: - Need types

enum NeedType: String, CaseIterable {
    case hunger    = "Hunger"
    case energy    = "Energy"
    case hygiene   = "Hygiene"
    case happiness = "Happiness"
}

struct NeedCall: Identifiable {
    let id = UUID()
    let need: NeedType
    let firedAt: Date
    let expiresAt: Date

    var isExpired: Bool { Date() >= expiresAt }
}

// MARK: - Decay rates (game-minutes per point lost, at 1× time scale)

private enum DecayRates {
    static let hunger:    Double = 30   // 1 point per 30 game-minutes
    static let energy:    Double = 45
    static let hygiene:   Double = 60
    static let happiness: Double = 30
}

// MARK: - Care action effects

enum CareAction {
    case feed
    case clean
    case rest
    case play
}

// MARK: - Engine

/// Pure helper — no timers, no state.  GameViewModel drives the tick loop.
enum CareEngine {

    /// Apply `gameMinutesElapsed` worth of need decay to the creature.
    /// Returns the updated creature and any newly fired care call.
    static func tick(
        creature: inout Creature,
        pendingCall: NeedCall?,
        gameMinutesElapsed: Double,
        callWindowMinutes: Int
    ) -> NeedCall? {
        decayNeeds(creature: &creature, minutes: gameMinutesElapsed)
        // Only fire a new call if no unanswered call is already active
        guard pendingCall == nil else { return nil }
        return detectCall(in: creature, windowMinutes: callWindowMinutes)
    }

    /// Apply a care action; returns whether it was accepted (some actions have conditions).
    @discardableResult
    static func perform(_ action: CareAction, on creature: inout Creature) -> Bool {
        switch action {
        case .feed:
            let overflow = max(0, creature.needs.hunger + 40 - 100)
            creature.needs.hunger = min(100, creature.needs.hunger + 40)
            if overflow > 0 {
                // Overfeed penalty: tiny discipline nudge downward (not a care mistake)
                creature.traits.discipline = max(0, creature.traits.discipline - 1)
            }
        case .clean:
            creature.needs.hygiene = 100
        case .rest:
            creature.needs.energy = min(100, creature.needs.energy + 30)
        case .play:
            creature.needs.happiness = min(100, creature.needs.happiness + 30)
            // Play improves bond slightly (not capped to daily delta — this is a direct nudge)
            creature.traits.bond = min(100, creature.traits.bond + 0.5)
        }
        creature.lastInteractionDate = Date()
        return true
    }

    // MARK: - Private

    private static func decayNeeds(creature: inout Creature, minutes: Double) {
        creature.needs.hunger    = max(0, creature.needs.hunger    - minutes / DecayRates.hunger)
        creature.needs.energy    = max(0, creature.needs.energy    - minutes / DecayRates.energy)
        creature.needs.hygiene   = max(0, creature.needs.hygiene   - minutes / DecayRates.hygiene)
        creature.needs.happiness = max(0, creature.needs.happiness - minutes / DecayRates.happiness)
    }

    private static func detectCall(in creature: Creature, windowMinutes: Int) -> NeedCall? {
        let threshold = 20.0
        let pairs: [(NeedType, Double)] = [
            (.hunger,    creature.needs.hunger),
            (.energy,    creature.needs.energy),
            (.hygiene,   creature.needs.hygiene),
            (.happiness, creature.needs.happiness)
        ]
        // Priority: most critical need first
        let critical = pairs.filter { $0.1 <= threshold }
        guard let first = critical.min(by: { $0.1 < $1.1 }) else { return nil }
        let now = Date()
        return NeedCall(
            need: first.0,
            firedAt: now,
            expiresAt: now.addingTimeInterval(Double(windowMinutes) * 60)
        )
    }
}
