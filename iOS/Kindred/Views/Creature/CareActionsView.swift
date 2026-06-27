import SwiftUI

struct CareActionsView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(spacing: KSpacing.md) {
            needsRow
            actionsRow
        }
        .padding(KSpacing.md)
        .background(KColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.lg))
    }

    // MARK: - Needs bars

    private var needsRow: some View {
        HStack(spacing: KSpacing.md) {
            NeedBar(label: "Hunger",    value: game.creature.needs.hunger,    color: .orange)
            NeedBar(label: "Energy",    value: game.creature.needs.energy,    color: .blue)
            NeedBar(label: "Hygiene",   value: game.creature.needs.hygiene,   color: .teal)
            NeedBar(label: "Mood",      value: game.creature.needs.happiness, color: .yellow)
        }
    }

    // MARK: - Action buttons

    private var actionsRow: some View {
        HStack(spacing: KSpacing.lg) {
            ActionButton(label: "Feed",  icon: "fork.knife")      { game.perform(.feed) }
            ActionButton(label: "Clean", icon: "sparkles")         { game.perform(.clean) }
            ActionButton(label: "Rest",  icon: "moon.fill")        { game.perform(.rest) }
            ActionButton(label: "Play",  icon: "figure.play")      { game.perform(.play) }
        }
    }
}

// MARK: - Sub-views

private struct NeedBar: View {
    let label: String
    let value: Double    // 0–100
    let color: Color

    var body: some View {
        VStack(spacing: KSpacing.xs) {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(KColor.surfaceDim)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(height: proxy.size.height * CGFloat(value / 100))
                }
            }
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(label)
                .font(KTypeScale.caption)
                .foregroundStyle(KColor.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var barColor: Color {
        value < 20 ? KColor.danger : (value < 40 ? KColor.warning : color)
    }
}

private struct ActionButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: KSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(KColor.accent)
                Text(label)
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
