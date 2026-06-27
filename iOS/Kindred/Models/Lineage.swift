import Foundation

struct LineageEntry: Codable, Sendable {
    let creatureID: UUID
    let stage: Stage
    let branch: Branch?
    let boonContributed: Int
    let diedAt: Date
}

struct Lineage: Identifiable, Codable, Sendable {
    let id: UUID
    var entries: [LineageEntry]

    /// Cumulative boon carried forward across generations (capped at 6 per spec).
    var totalBoon: Int {
        min(entries.reduce(0) { $0 + $1.boonContributed }, 6)
    }

    init() {
        self.id = UUID()
        self.entries = []
    }

    mutating func record(creature: Creature, boonContributed: Int) {
        let entry = LineageEntry(
            creatureID: creature.id,
            stage: creature.stage,
            branch: creature.branch,
            boonContributed: boonContributed,
            diedAt: Date()
        )
        entries.append(entry)
    }
}
