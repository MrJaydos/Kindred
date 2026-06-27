import Foundation
import CryptoKit

/// The full input context for one exchange, from both sides.
struct ExchangeRecord: Codable, Sendable {
    let exchangeIndex: Int
    let playerInput: ExchangeInputSummary
    let opponentInput: ExchangeInputSummary
    let playerHPAfter: Double
    let opponentHPAfter: Double
    let stateHash: String  // SHA256 of (exchangeIndex + both HPs), hex-encoded
}

/// Live battle state. Both devices maintain an identical copy via lockstep.
struct BattleState: Sendable {
    let playerStats: StatBlock
    let opponentStats: StatBlock
    let seed: UInt64
    var playerHP: Double
    var opponentHP: Double
    var playerStamina: Double
    var opponentStamina: Double
    var exchanges: [ExchangeRecord]
    var isVoided: Bool = false

    init(playerStats: StatBlock, opponentStats: StatBlock, seed: UInt64, hpPoolMultiplier: Double = 4) {
        self.playerStats = playerStats
        self.opponentStats = opponentStats
        self.seed = seed
        self.playerHP = playerStats.hp * hpPoolMultiplier
        self.opponentHP = opponentStats.hp * hpPoolMultiplier
        self.playerStamina = playerStats.stamina
        self.opponentStamina = opponentStats.stamina
        self.exchanges = []
    }

    var isOver: Bool {
        isVoided || playerHP <= 0 || opponentHP <= 0 || exchanges.count >= 5
    }

    var playerWon: Bool? {
        guard isOver && !isVoided else { return nil }
        if playerHP <= 0 && opponentHP <= 0 {
            return playerStats.speed >= opponentStats.speed
        }
        if playerHP <= 0 { return false }
        if opponentHP <= 0 { return true }
        let playerPct = playerHP / (playerStats.hp * 4)
        let opponentPct = opponentHP / (opponentStats.hp * 4)
        if abs(playerPct - opponentPct) < 0.001 {
            return playerStats.speed >= opponentStats.speed
        }
        return playerPct > opponentPct
    }

    /// SHA256 hash of current state — compared in lockstep after each exchange.
    func stateHash() -> String {
        let payload = "\(exchanges.count):\(String(format: "%.4f", playerHP)):\(String(format: "%.4f", opponentHP))"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
