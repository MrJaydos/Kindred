import Foundation

enum EggKind: Codable, Sendable {
    case plain
    case traited(boon: Int)

    var boon: Int {
        switch self {
        case .plain: return 0
        case .traited(let b): return b
        }
    }

    var isTraited: Bool {
        if case .traited = self { return true }
        return false
    }
}

struct Egg: Identifiable, Codable, Sendable {
    let id: UUID
    let kind: EggKind
    let parentCreatureID: UUID
    let lineageID: UUID
    let createdAt: Date

    init(kind: EggKind, parentCreatureID: UUID, lineageID: UUID) {
        self.id = UUID()
        self.kind = kind
        self.parentCreatureID = parentCreatureID
        self.lineageID = lineageID
        self.createdAt = Date()
    }
}
