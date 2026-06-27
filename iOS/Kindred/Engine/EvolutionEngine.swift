import Foundation

// MARK: - Events

enum EvolutionEvent {
    case stagePromotion(from: Stage, to: Stage, branch: Branch?)
    case earlyDeath(egg: Egg)
    case naturalDeath(egg: Egg)
}

// MARK: - Engine

/// Stateless. Operates on Creature value types; the caller (GameViewModel) owns mutations.
final class EvolutionEngine {
    private let evolutionConfig: EvolutionConfig
    private let battleConfig: BattleConfig

    init(evolutionConfig: EvolutionConfig, battleConfig: BattleConfig) {
        self.evolutionConfig = evolutionConfig
        self.battleConfig = battleConfig
    }

    // MARK: - Daily Signal Application

    /// Apply one game-day's worth of signals to the creature's trait axes.
    /// No-op during the blob stage (spec: "nothing the player does matters yet").
    func applyDailySignals(to creature: inout Creature, signals: DailySignals) {
        guard creature.stage != .egg && creature.stage != .blob else { return }

        let halfLife = evolutionConfig.traits.recencyHalfLifeDays
        let weight   = 1.0 - pow(0.5, 1.0 / halfLife)
        let maxDelta = evolutionConfig.traits.maxDailyDelta

        // Signals that feed the same axis are averaged
        let vigorTarget        = (signals.steps + signals.activeEnergy) / 2
        let nocturnalityTarget = signals.nightActivityShare
        let disciplineTarget   = signals.sleepRegularity
        let bondTarget         = (signals.interactionCount + signals.responseLatency) / 2

        creature.traits.vigor        = accumulate(current: creature.traits.vigor,        target: vigorTarget,        weight: weight, maxDelta: maxDelta)
        creature.traits.nocturnality = accumulate(current: creature.traits.nocturnality, target: nocturnalityTarget, weight: weight, maxDelta: maxDelta)
        creature.traits.discipline   = accumulate(current: creature.traits.discipline,   target: disciplineTarget,   weight: weight, maxDelta: maxDelta)
        creature.traits.bond         = accumulate(current: creature.traits.bond,         target: bondTarget,         weight: weight, maxDelta: maxDelta)
    }

    // MARK: - Stage Evaluation

    /// Check whether the creature should advance a stage or die.
    /// Called once per real second by GameViewModel; time scaling is applied by the caller.
    func evaluateStage(
        creature: inout Creature,
        careMistakesThisStage: Int,
        awakeHoursSinceAdult: Double
    ) -> EvolutionEvent? {
        guard creature.isAlive else { return nil }

        let now = Date()
        let realSecondsAlive = now.timeIntervalSince(creature.birthDate)
        let gameDaysAlive    = realSecondsAlive / 86400   // in real mode; caller applies scale

        switch creature.stage {
        case .egg:
            let hatchSeconds = evolutionConfig.stages.first { $0.id == "egg" }?.hatchSeconds ?? 60
            if realSecondsAlive >= hatchSeconds {
                creature.stage = .blob
                return .stagePromotion(from: .egg, to: .blob, branch: nil)
            }

        case .blob:
            let reachDays = evolutionConfig.stages.first { $0.id == "juvenile" }?.reachDays ?? 1.0
            if gameDaysAlive >= reachDays {
                creature.stage = .juvenile
                return .stagePromotion(from: .blob, to: .juvenile, branch: nil)
            }

        case .juvenile:
            // Early death check applies at all post-blob stages
            if shouldDieEarly(careMistakes: careMistakesThisStage) {
                return processDeath(creature: &creature, isNatural: false)
            }
            let reachDays = evolutionConfig.stages.first { $0.id == "adult" }?.reachDays ?? 3.5
            if gameDaysAlive >= reachDays {
                let branch = selectBranch(traits: creature.traits, careMistakes: careMistakesThisStage)
                creature.branch = branch
                creature.stage  = .adult
                creature.stats  = computeStats(traits: creature.traits, branch: branch, lineageBoon: 0, isApex: false)
                return .stagePromotion(from: .juvenile, to: .adult, branch: branch)
            }

        case .adult:
            if shouldDieEarly(careMistakes: careMistakesThisStage) {
                return processDeath(creature: &creature, isNatural: false)
            }
            if gameDaysAlive >= evolutionConfig.lifespanDays.naturalMax {
                return processDeath(creature: &creature, isNatural: true)
            }
            if let branch = creature.branch,
               meetsApexGate(creature: creature, branch: branch, awakeHours: awakeHoursSinceAdult, careMistakes: careMistakesThisStage) {
                creature.stage = .apex
                applyApexBumps(to: &creature)
                return .stagePromotion(from: .adult, to: .apex, branch: branch)
            }

        case .apex:
            if gameDaysAlive >= evolutionConfig.lifespanDays.naturalMax {
                return processDeath(creature: &creature, isNatural: true)
            }
        }

        return nil
    }

    // MARK: - Branch Selection (also callable from debug overlay)

    func selectBranch(traits: TraitVector, careMistakes: Int) -> Branch {
        let neglect    = traits.neglect(careMistakes: careMistakes)
        let neglectCfg = evolutionConfig.branchSelection.neglectOverride

        // 1. Neglect override
        if neglect >= neglectCfg.neglectGte || careMistakes >= neglectCfg.careMistakesGte {
            return .distant
        }

        // 2. Dominant-axis check
        let axisCfg = evolutionConfig.branchSelection.dominantAxis
        let axes: [(axis: String, value: Double)] = [
            ("vigor",        traits.vigor),
            ("nocturnality", traits.nocturnality),
            ("bond",         traits.bond),
            ("discipline",   traits.discipline)
        ]
        let sorted = axes.sorted { $0.value > $1.value }
        let top    = sorted[0]
        let second = sorted[1]

        if top.value >= axisCfg.minValue && (top.value - second.value) >= axisCfg.minLeadOverSecond {
            if let branchRaw = axisCfg.map[top.axis], let branch = Branch(rawValue: branchRaw) {
                return branch
            }
        }

        // 3. Fallback
        return .drifter
    }

    // MARK: - Stat Computation

    func computeStats(traits: TraitVector, branch: Branch, lineageBoon: Int, isApex: Bool) -> StatBlock {
        let bias = battleConfig.bias(for: branch)

        func stat(_ key: String, axis: Double) -> Double {
            let base = 50.0 * (bias[key] ?? 1.0)
            let axisNudge = (axis - 50) * 0.25
            let boonNudge = Double(lineageBoon) * 0.5
            return min(100, max(1, base + axisNudge + boonNudge))
        }

        var block = StatBlock(
            hp:      stat("hp",      axis: traits.discipline),
            attack:  stat("attack",  axis: traits.vigor),
            defense: stat("defense", axis: traits.discipline),
            speed:   stat("speed",   axis: traits.vigor),
            stamina: stat("stamina", axis: (traits.vigor + traits.bond) / 2)
        )

        if isApex {
            let bump = battleConfig.apexStatBump
            // Bump the two stats that match the branch's highest-bias keys
            let sortedBias = (bias).sorted { $0.value > $1.value }
            for entry in sortedBias.prefix(2) {
                switch entry.key {
                case "hp":      block.hp      = min(100, block.hp      + bump)
                case "attack":  block.attack  = min(100, block.attack  + bump)
                case "defense": block.defense = min(100, block.defense + bump)
                case "speed":   block.speed   = min(100, block.speed   + bump)
                case "stamina": block.stamina = min(100, block.stamina + bump)
                default: break
                }
            }
        }

        return block
    }

    // MARK: - Egg Determination

    func determineEgg(creature: Creature, isNatural: Bool) -> Egg {
        let cfg     = evolutionConfig.traitedEgg
        let lineageID = creature.lineageID ?? UUID()
        let daysSinceBirth = Date().timeIntervalSince(creature.birthDate) / 86400
        let livedPast = daysSinceBirth >= evolutionConfig.lifespanDays.naturalMin

        let qualifies = isNatural
            && livedPast
            && (creature.stage == .adult || creature.stage == .apex)
            && creature.lifetimeCareMistakes <= cfg.lifetimeCareMistakesMax

        if qualifies {
            let boon = cfg.boonByStage[creature.stage.rawValue] ?? 0
            return Egg(kind: .traited(boon: boon), parentCreatureID: creature.id, lineageID: lineageID)
        }
        return Egg(kind: .plain, parentCreatureID: creature.id, lineageID: lineageID)
    }

    // MARK: - Private Helpers

    private func accumulate(current: Double, target: Double, weight: Double, maxDelta: Double) -> Double {
        let rawDelta    = (target - current) * weight
        let cappedDelta = max(-maxDelta, min(maxDelta, rawDelta))
        return max(0, min(100, current + cappedDelta))
    }

    private func shouldDieEarly(careMistakes: Int) -> Bool {
        careMistakes >= evolutionConfig.careMistakes.earlyDeathThreshold
    }

    private func meetsApexGate(creature: Creature, branch: Branch, awakeHours: Double, careMistakes: Int) -> Bool {
        let cfg = evolutionConfig.apexGate
        guard awakeHours >= 72 else { return false }

        let dominantAxis = max(creature.traits.vigor, creature.traits.nocturnality,
                               creature.traits.bond,  creature.traits.discipline)
        guard dominantAxis >= cfg.dominantAxisGte else { return false }

        // DISTANT has a parallel apex that ignores win ratio and care gates
        if branch == .distant { return true }

        guard careMistakes <= cfg.minCareMistakesMax else { return false }
        let total = creature.wins + creature.losses
        guard total >= cfg.minBattles else { return false }
        guard creature.winRatio >= cfg.minWinRatio else { return false }
        return true
    }

    private func processDeath(creature: inout Creature, isNatural: Bool) -> EvolutionEvent {
        creature.isAlive = false
        let egg = determineEgg(creature: creature, isNatural: isNatural)
        return isNatural ? .naturalDeath(egg: egg) : .earlyDeath(egg: egg)
    }

    private func applyApexBumps(to creature: inout Creature) {
        guard let branch = creature.branch else { return }
        creature.stats = computeStats(
            traits: creature.traits, branch: branch,
            lineageBoon: 0, isApex: true
        )
    }
}
