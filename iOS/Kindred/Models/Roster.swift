import Foundation

/// Snapshot of a creature at a moment in time — stored for display in the Roster.
struct CreatureSnapshot: Codable, Sendable {
    let stage: Stage
    let branch: Branch?
    let traits: TraitVector
    let lineageBoon: Int
    let capturedAt: Date
}

/// A tamer you have physically bumped. Actions (rematch/breed/trade) require a fresh bump.
struct MetTamer: Identifiable, Codable, Sendable {
    let id: UUID
    var displayName: String
    var lastSeenCreature: CreatureSnapshot
    var lineageEntries: [LineageEntry]
    var winsAgainst: Int
    var lossesAgainst: Int
    var firstMetAt: Date
    var lastMetAt: Date

    var headToHeadRecord: String {
        "\(winsAgainst)–\(lossesAgainst)"
    }
}

struct Roster: Codable, Sendable {
    var tamers: [MetTamer] = []

    mutating func upsert(tamer: MetTamer) {
        if let idx = tamers.firstIndex(where: { $0.id == tamer.id }) {
            tamers[idx] = tamer
        } else {
            tamers.append(tamer)
        }
    }

    /// Rank is determined by win ratio against this player, descending.
    func ranked() -> [MetTamer] {
        tamers.sorted {
            let r0 = $0.winsAgainst > 0 ? Double($0.winsAgainst) / Double($0.winsAgainst + $0.lossesAgainst) : 0
            let r1 = $1.winsAgainst > 0 ? Double($1.winsAgainst) / Double($1.winsAgainst + $1.lossesAgainst) : 0
            return r0 > r1
        }
    }
}
