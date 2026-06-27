import SwiftUI

/// Shown once (AppStorage flag) during the countdown of a player's first battle.
struct BattleRulesCard: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: KSpacing.xl) {
                VStack(spacing: KSpacing.xs) {
                    Text("How to battle")
                        .font(KTypeScale.title3)
                        .foregroundStyle(KColor.textPrimary)
                    Text("Each fight is 5 exchanges. Both sides move every round.")
                        .font(KTypeScale.caption)
                        .foregroundStyle(KColor.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: KSpacing.md) {
                    RuleRow(
                        icon: "scope",
                        color: KColor.success,
                        title: "Timing",
                        detail: "A marker sweeps left→right. Tap the bar when it hits the green zone. Closer to center = more damage."
                    )
                    RuleRow(
                        icon: "bolt.fill",
                        color: KColor.warning,
                        title: "Mash",
                        detail: "Tap the MASH button repeatedly to build extra power. Each tap spends stamina — don't exhaust it early."
                    )
                    RuleRow(
                        icon: "gauge.with.dots.needle.67percent",
                        color: KColor.accent,
                        title: "Stamina",
                        detail: "Stamina shown under your HP bar. A full bar hits harder in later exchanges. Pace yourself."
                    )
                    RuleRow(
                        icon: "chart.bar.fill",
                        color: KColor.textMuted,
                        title: "Stats",
                        detail: "A stronger creature is harder to beat — but good timing and pacing can close a moderate gap."
                    )
                }

                Button(action: onDismiss) {
                    Text("Got it — let's go")
                        .font(KTypeScale.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(KSpacing.md)
                        .background(KColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: KRadius.md))
                }
            }
            .padding(KSpacing.xl)
            .background(KColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: KRadius.lg))
            .padding(.horizontal, KSpacing.lg)
        }
        .transition(.opacity)
    }
}

private struct RuleRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: KSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(KTypeScale.bodyBold)
                    .foregroundStyle(KColor.textPrimary)
                Text(detail)
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
