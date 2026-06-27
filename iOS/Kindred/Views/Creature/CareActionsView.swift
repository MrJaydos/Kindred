import SwiftUI

struct CareActionsView: View {
    @EnvironmentObject private var game: GameViewModel

    /// Called after every successful action — used by parent to bounce the creature.
    var onAction: () -> Void = {}

    @State private var feedTrigger  = 0
    @State private var cleanTrigger = 0
    @State private var restTrigger  = 0
    @State private var playTrigger  = 0

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
            NeedBar(label: "Hunger",  value: game.creature.needs.hunger,    color: .orange)
            NeedBar(label: "Energy",  value: game.creature.needs.energy,    color: .blue)
            NeedBar(label: "Hygiene", value: game.creature.needs.hygiene,   color: .teal)
            NeedBar(label: "Mood",    value: game.creature.needs.happiness, color: .yellow)
        }
    }

    // MARK: - Action buttons

    private var actionsRow: some View {
        HStack(spacing: KSpacing.lg) {
            ActionButton(
                label: "Feed", icon: "fork.knife",
                particleTrigger: $feedTrigger, particleSymbol: "fork.knife", particleColor: .orange
            ) {
                game.perform(.feed); feedTrigger += 1; onAction()
            }
            ActionButton(
                label: "Clean", icon: "sparkles",
                particleTrigger: $cleanTrigger, particleSymbol: "sparkles", particleColor: .cyan
            ) {
                game.perform(.clean); cleanTrigger += 1; onAction()
            }
            ActionButton(
                label: "Rest", icon: "moon.fill",
                particleTrigger: $restTrigger, particleSymbol: "zzz", particleColor: Color(red: 0.5, green: 0.6, blue: 1.0)
            ) {
                game.perform(.rest); restTrigger += 1; onAction()
            }
            ActionButton(
                label: "Play", icon: "figure.play",
                particleTrigger: $playTrigger, particleSymbol: "star.fill", particleColor: .yellow
            ) {
                game.perform(.play); playTrigger += 1; onAction()
            }
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
                    RoundedRectangle(cornerRadius: 4).fill(KColor.surfaceDim)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(height: proxy.size.height * CGFloat(value / 100))
                        .animation(.spring(duration: 0.4), value: value)
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
    @Binding var particleTrigger: Int
    let particleSymbol: String
    let particleColor: Color
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
        .overlay {
            ParticleBurst(symbol: particleSymbol, color: particleColor, trigger: particleTrigger)
        }
    }
}
