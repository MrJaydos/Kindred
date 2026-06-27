import Foundation

/// Typed wrapper around evolution_config.json.
/// Loaded from the bundle by default; RemoteBackstop may override individual values later.
struct EvolutionConfig: Codable, Sendable {

    struct TraitConfig: Codable, Sendable {
        let axes: [String]
        let accumulation: String
        let recencyHalfLifeDays: Double
        let maxDailyDelta: Double
    }

    struct CareMistakeConfig: Codable, Sendable {
        let callWindowMinutes: Int
        let resetOnEvolution: Bool
        let earlyDeathThreshold: Int
        let emptyNeedDeathHours: Double
    }

    struct StageConfig: Codable, Sendable {
        let id: String
        let hatchSeconds: Double?
        let afterHatch: Bool?
        let mattersForEvolution: Bool?
        let reachDays: Double?
        let branchSelect: Bool?
        let minAwakeHours: Double?
        let gated: Bool?
    }

    struct LifespanConfig: Codable, Sendable {
        let naturalMin: Double
        let naturalMax: Double
        let pausedDuringSleep: Bool
    }

    struct NeglectOverrideConfig: Codable, Sendable {
        let neglectGte: Double
        let careMistakesGte: Int
        let branch: String
    }

    struct DominantAxisConfig: Codable, Sendable {
        let minValue: Double
        let minLeadOverSecond: Double
        let map: [String: String]
    }

    struct BranchSelectionConfig: Codable, Sendable {
        let order: [String]
        let neglectOverride: NeglectOverrideConfig
        let dominantAxis: DominantAxisConfig
        let fallback: String
        let wildcardChance: Double
    }

    struct ApexGateConfig: Codable, Sendable {
        let minCareMistakesMax: Int
        let minWinRatio: Double
        let minBattles: Int
        let dominantAxisGte: Double
    }

    struct BoonEffectsConfig: Codable, Sendable {
        let evoGateBonusPctPerPoint: Double
        let startingAxisNudgeMaxPerPoint: Double
    }

    struct TraitedEggConfig: Codable, Sendable {
        let requireLivedPastLifespan: Bool
        let requireStageAtLeast: String
        let lifetimeCareMistakesMax: Int
        let boonByStage: [String: Int]
        let boonCap: Int
        let boonEffects: BoonEffectsConfig
    }

    let version: Int
    let traits: TraitConfig
    let careMistakes: CareMistakeConfig
    let stages: [StageConfig]
    let lifespanDays: LifespanConfig
    let branchSelection: BranchSelectionConfig
    let apexGate: ApexGateConfig
    let traitedEgg: TraitedEggConfig

    static func loadFromBundle() -> EvolutionConfig {
        guard let url = Bundle.main.url(forResource: "evolution_config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(EvolutionConfig.self, from: data) else {
            fatalError("evolution_config.json missing or malformed — check the Config group in the bundle")
        }
        return config
    }
}
