import Foundation

// MARK: - Enumerations

enum Stage: String, Codable, Sendable, CaseIterable {
    case egg
    case blob
    case juvenile
    case adult
    case apex
}

enum Branch: String, Codable, Sendable, CaseIterable {
    case swift_     = "SWIFT"
    case feral      = "FERAL"
    case bonded     = "BONDED"
    case stalwart   = "STALWART"
    case distant    = "DISTANT"
    case drifter    = "DRIFTER"
}

// MARK: - Trait Axes

/// The four accumulating axes that define the creature. Each is 0–100.
struct TraitVector: Codable, Sendable {
    var vigor:        Double = 50
    var nocturnality: Double = 50
    var bond:         Double = 50
    var discipline:   Double = 50

    /// Derived: inverse of Bond + care-mistake influence. Computed on access.
    func neglect(careMistakes: Int) -> Double {
        let bondInverse = 100 - bond
        let mistakePressure = min(Double(careMistakes) * 5, 50)
        return min((bondInverse * 0.6 + mistakePressure * 0.4), 100)
    }
}

// MARK: - Stat Block

/// Battle stats derived from branch bias + trait axes + lineage boon.
/// Persisted on Creature; never recomputed mid-battle.
struct StatBlock: Codable, Sendable {
    var hp:      Double  // 1–100
    var attack:  Double
    var defense: Double
    var speed:   Double
    var stamina: Double

    static let neutral = StatBlock(hp: 50, attack: 50, defense: 50, speed: 50, stamina: 50)
}

// MARK: - Needs

struct CreatureNeeds: Codable, Sendable {
    /// 0–100: 100 = full, 0 = empty → triggers call → if unanswered → careMistake
    var hunger:    Double = 80
    var energy:    Double = 80
    var hygiene:   Double = 80
    var happiness: Double = 80

    var isCritical: Bool {
        hunger < 15 || energy < 15
    }
}

// MARK: - Creature

struct Creature: Identifiable, Codable, Sendable {
    let id: UUID
    var stage: Stage
    var branch: Branch?        // nil until adult branch selection
    var traits: TraitVector
    var stats: StatBlock
    var needs: CreatureNeeds
    var lineageID: UUID?       // reference to parent Lineage

    var birthDate: Date
    var lastFedDate: Date
    var lastInteractionDate: Date

    var lifetimeCareMistakes: Int
    var wins: Int
    var losses: Int

    var isAlive: Bool

    // MARK: Convenience

    var winRatio: Double {
        let total = wins + losses
        guard total >= 1 else { return 0 }
        return Double(wins) / Double(total)
    }

    init(id: UUID = UUID(), lineageID: UUID? = nil, boon: Int = 0) {
        self.id = id
        self.stage = .egg
        self.branch = nil
        self.traits = TraitVector()
        self.stats = StatBlock.neutral
        self.needs = CreatureNeeds()
        self.lineageID = lineageID
        self.birthDate = Date()
        self.lastFedDate = Date()
        self.lastInteractionDate = Date()
        self.lifetimeCareMistakes = 0
        self.wins = 0
        self.losses = 0
        self.isAlive = true
        applyBoon(boon)
    }

    private mutating func applyBoon(_ boon: Int) {
        guard boon > 0 else { return }
        // Each boon point adds ≤0.5 pts to the dominant axis at start (never predetermines)
        let nudge = min(Double(boon) * 0.5, 3)
        traits.vigor += nudge  // neutral starting nudge; EvolutionEngine will shape it further
    }
}
