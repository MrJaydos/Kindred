import Foundation
import SwiftData

// MARK: - SwiftData Models
// These are thin persistence wrappers. The engine works entirely with value-type
// structs (Creature, Lineage, Roster); these @Model classes are the storage layer only.

@Model
final class CreatureRecord {
    @Attribute(.unique) var id: UUID
    var encodedData: Data   // JSON-encoded Creature struct
    var isActive: Bool

    init(creature: Creature) throws {
        self.id = creature.id
        self.encodedData = try JSONEncoder().encode(creature)
        self.isActive = creature.isAlive
    }

    func decode() throws -> Creature {
        try JSONDecoder().decode(Creature.self, from: encodedData)
    }

    func update(from creature: Creature) throws {
        encodedData = try JSONEncoder().encode(creature)
        isActive = creature.isAlive
    }
}

@Model
final class LineageRecord {
    @Attribute(.unique) var id: UUID
    var encodedData: Data

    init(lineage: Lineage) throws {
        self.id = lineage.id
        self.encodedData = try JSONEncoder().encode(lineage)
    }

    func decode() throws -> Lineage {
        try JSONDecoder().decode(Lineage.self, from: encodedData)
    }

    func update(from lineage: Lineage) throws {
        encodedData = try JSONEncoder().encode(lineage)
    }
}

@Model
final class RosterRecord {
    // One roster per app — id is always a fixed sentinel
    @Attribute(.unique) var id: String
    var encodedData: Data

    init(roster: Roster) throws {
        self.id = "main"
        self.encodedData = try JSONEncoder().encode(roster)
    }

    func decode() throws -> Roster {
        try JSONDecoder().decode(Roster.self, from: encodedData)
    }

    func update(from roster: Roster) throws {
        encodedData = try JSONEncoder().encode(roster)
    }
}
