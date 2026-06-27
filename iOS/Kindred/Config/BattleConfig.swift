import Foundation

/// Typed wrapper around battle_config.json.
struct BattleConfig: Codable, Sendable {

    struct Structure: Codable, Sendable {
        let exchanges: Int
        let windowMs: Int
        let hpPoolMultiplier: Double
        let orderBy: String
    }

    struct SkillConfig: Codable, Sendable {
        let SKILL_CAP_OFFENSE: Double
        let SKILL_CAP_DEFENSE: Double
        let mashWeight: Double
        let timingWeight: Double
        let guardWeight: Double
        let maxMash: Int
        let staminaPerTap: Double
        let staminaRegenPerExchange: Double
        let sweetSpotBaseMs: Double
        let sweetSpotPerSpeedMs: Double
    }

    struct DamageConfig: Codable, Sendable {
        let ATK_K: Double
        let DEF_C: Double
        let HP_SCALE: Double
        let minDamage: Double
    }

    struct CritConfig: Codable, Sendable {
        let enabled: Bool
        let chance: Double
        let multiplier: Double
    }

    struct NetcodeConfig: Codable, Sendable {
        let lockstep: Bool
        let shareSignedState: Bool
        let perExchangeStateHashCheck: Bool
        let voidOnMismatch: Bool
    }

    struct OutcomeConfig: Codable, Sendable {
        let winnerAxisNudge: Double
        let loserDefenseNudge: Double
        let dailyImprintCap: Double
    }

    let version: Int
    let structure: Structure
    let statBranchBias: [String: [String: Double]]
    let apexStatBump: Double
    let skill: SkillConfig
    let damage: DamageConfig
    let crit: CritConfig
    let netcode: NetcodeConfig
    let outcome: OutcomeConfig

    func bias(for branch: Branch) -> [String: Double] {
        statBranchBias[branch.rawValue] ?? statBranchBias["DRIFTER"]!
    }

    static func loadFromBundle() -> BattleConfig {
        guard let url = Bundle.main.url(forResource: "battle_config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(BattleConfig.self, from: data) else {
            fatalError("battle_config.json missing or malformed — check the Config group in the bundle")
        }
        return config
    }
}
