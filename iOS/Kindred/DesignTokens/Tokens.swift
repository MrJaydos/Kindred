import SwiftUI

enum KColor {
    // Backgrounds
    static let background    = Color(hex: "#F5F4F0")
    static let surface       = Color(hex: "#FFFFFF")
    static let surfaceDim    = Color(hex: "#EDECE8")

    // Foregrounds
    static let textPrimary   = Color(hex: "#1A1917")
    static let textSecondary = Color(hex: "#6B6A66")
    static let textMuted     = Color(hex: "#AEADA8")

    // Accent — restrained single hue, branch tints derived from this
    static let accent        = Color(hex: "#3D5A80")
    static let accentSoft    = Color(hex: "#E8EEF4")

    // Branch palette (UI tints only — never label a branch in-game)
    static let branchSwift    = Color(hex: "#4A90D9")
    static let branchFeral    = Color(hex: "#8B5CF6")
    static let branchBonded   = Color(hex: "#F59E0B")
    static let branchStalwart = Color(hex: "#10B981")
    static let branchDistant  = Color(hex: "#6B7280")
    static let branchDrifter  = Color(hex: "#9CA3AF")

    // Semantic
    static let danger        = Color(hex: "#EF4444")
    static let warning       = Color(hex: "#F59E0B")
    static let success       = Color(hex: "#10B981")
}

enum KSpacing {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 16
    static let lg: CGFloat  = 24
    static let xl: CGFloat  = 32
    static let xxl: CGFloat = 48
}

enum KRadius {
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 16
    static let lg: CGFloat  = 24
    static let full: CGFloat = 9999
}

enum KTypeScale {
    static let caption   = Font.system(size: 12, weight: .regular)
    static let body      = Font.system(size: 15, weight: .regular)
    static let bodyBold  = Font.system(size: 15, weight: .semibold)
    static let title3    = Font.system(size: 20, weight: .semibold)
    static let title2    = Font.system(size: 24, weight: .bold)
    static let title     = Font.system(size: 32, weight: .bold)
}

// MARK: - Hex convenience
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
