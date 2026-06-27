import Foundation
import CryptoKit

// MARK: - Per-exchange result

struct ExchangeResult: Sendable {
    let playerDamageDealt: Double
    let opponentDamageDealt: Double
    let playerHPAfter: Double
    let opponentHPAfter: Double
    let playerStaminaAfter: Double
    let opponentStaminaAfter: Double
    /// True when the faster creature KO'd the opponent before it could attack.
    let earlyKO: Bool
    /// SHA256 of post-exchange state — compared in lockstep after each exchange.
    let stateHash: String
}

// MARK: - Resolver

/// Stateless, deterministic. Both devices run this with the same inputs and reach the same result.
/// No guard, no crits in the prototype (spec §9 prototype-minimum).
final class BattleResolver {
    private let config: BattleConfig

    init(config: BattleConfig) {
        self.config = config
    }

    func resolveExchange(
        exchangeIndex: Int,
        playerStats: StatBlock,
        opponentStats: StatBlock,
        playerInput: ExchangeInputSummary,
        opponentInput: ExchangeInputSummary,
        playerHP: Double,
        opponentHP: Double,
        playerStamina: Double,
        opponentStamina: Double
    ) -> ExchangeResult {
        let sk = config.skill

        // Clamp tap counts to physical maximum
        let pTaps = min(playerInput.tapCount,   sk.maxMash)
        let oTaps = min(opponentInput.tapCount, sk.maxMash)

        // Timing quality [0, 1]
        let pTimingQ = timingQuality(offsetMs: playerInput.timingOffsetMs,   speed: playerStats.speed)
        let oTimingQ = timingQuality(offsetMs: opponentInput.timingOffsetMs, speed: opponentStats.speed)

        // Skill bonus — stamina ratio is against that creature's own max
        let pSkill = skillBonus(taps: pTaps, timingQ: pTimingQ, curStamina: playerStamina,   maxStamina: playerStats.stamina)
        let oSkill = skillBonus(taps: oTaps, timingQ: oTimingQ, curStamina: opponentStamina, maxStamina: opponentStats.stamina)

        // Effective attack (guard bonus = 0 in prototype)
        let effPAtk = playerStats.attack   * (1.0 + pSkill)
        let effOAtk = opponentStats.attack * (1.0 + oSkill)
        let effPDef = playerStats.defense
        let effODef = opponentStats.defense

        let d = config.damage
        let pDmg = max(d.minDamage, ((effPAtk * d.ATK_K) / (effODef + d.DEF_C) * d.HP_SCALE).rounded())
        let oDmg = max(d.minDamage, ((effOAtk * d.ATK_K) / (effPDef + d.DEF_C) * d.HP_SCALE).rounded())

        // Speed-ordered damage application (spec: faster strikes first, KO ends exchange)
        var pHPAfter = playerHP
        var oHPAfter = opponentHP
        var earlyKO  = false

        if playerStats.speed >= opponentStats.speed {
            oHPAfter = max(0, opponentHP - pDmg)
            if oHPAfter > 0 {
                pHPAfter = max(0, playerHP - oDmg)
            } else {
                earlyKO = true
            }
        } else {
            pHPAfter = max(0, playerHP - oDmg)
            if pHPAfter > 0 {
                oHPAfter = max(0, opponentHP - pDmg)
            } else {
                earlyKO = true
            }
        }

        // Stamina: spend taps, regen between exchanges
        let pStaminaAfter = min(playerStats.stamina,   max(0, playerStamina   - Double(pTaps) * sk.staminaPerTap + sk.staminaRegenPerExchange))
        let oStaminaAfter = min(opponentStats.stamina, max(0, opponentStamina - Double(oTaps) * sk.staminaPerTap + sk.staminaRegenPerExchange))

        return ExchangeResult(
            playerDamageDealt: pDmg,
            opponentDamageDealt: oDmg,
            playerHPAfter: pHPAfter,
            opponentHPAfter: oHPAfter,
            playerStaminaAfter: pStaminaAfter,
            opponentStaminaAfter: oStaminaAfter,
            earlyKO: earlyKO,
            stateHash: computeHash(exchange: exchangeIndex, pHP: pHPAfter, oHP: oHPAfter)
        )
    }

    // MARK: - Private helpers

    private func timingQuality(offsetMs: Int, speed: Double) -> Double {
        let sk = config.skill
        let sweetSpotWidth = sk.sweetSpotBaseMs + speed * sk.sweetSpotPerSpeedMs
        return max(0, 1.0 - min(1.0, abs(Double(offsetMs)) / (sweetSpotWidth / 2)))
    }

    private func skillBonus(taps: Int, timingQ: Double, curStamina: Double, maxStamina: Double) -> Double {
        let sk = config.skill
        let staminaRatio = maxStamina > 0 ? min(1, curStamina / maxStamina) : 0
        let mashBonus    = (Double(taps) / Double(sk.maxMash)) * sk.mashWeight * staminaRatio
        let timingBonus  = timingQ * sk.timingWeight
        return min(sk.SKILL_CAP_OFFENSE, mashBonus + timingBonus)
    }

    private func computeHash(exchange: Int, pHP: Double, oHP: Double) -> String {
        let payload = "\(exchange):\(String(format: "%.4f", pHP)):\(String(format: "%.4f", oHP))"
        let digest  = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
