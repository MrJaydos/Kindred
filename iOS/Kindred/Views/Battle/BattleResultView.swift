import SwiftUI

struct BattleResultView: View {
    let battle: BattleViewModel
    let playerCreature: Creature
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: KSpacing.xl) {
            Spacer()

            // Result headline
            resultHeadline

            // Creature — grows or shrinks slightly based on outcome
            CreatureRenderer(creature: playerCreature)
                .frame(width: 180, height: 180)
                .scaleEffect(scale)
                .animation(.spring(duration: 0.6), value: battle.playerWon)

            // Stats summary
            exchangeSummary

            Spacer()

            dismissButton
        }
        .padding(KSpacing.xl)
        .background(KColor.background)
    }

    // MARK: - Headline

    private var resultHeadline: some View {
        Group {
            if battle.isVoided {
                label("Battle Voided", sub: "A mismatch was detected.", color: KColor.warning)
            } else if let won = battle.playerWon {
                if won {
                    label("Victory", sub: "Added to your roster.", color: KColor.success)
                } else {
                    label("Defeated", sub: "But your creature carries it forward.", color: KColor.danger)
                }
            } else {
                label("Draw", sub: "Both creatures gave everything.", color: KColor.accent)
            }
        }
    }

    private func label(_ title: String, sub: String, color: Color) -> some View {
        VStack(spacing: KSpacing.xs) {
            Text(title)
                .font(KTypeScale.title2)
                .foregroundStyle(color)
            Text(sub)
                .font(KTypeScale.body)
                .foregroundStyle(KColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Exchange summary

    private var exchangeSummary: some View {
        VStack(spacing: KSpacing.sm) {
            Text("Battle summary")
                .font(KTypeScale.caption)
                .foregroundStyle(KColor.textMuted)

            ForEach(Array(battle.exchanges.enumerated()), id: \.offset) { idx, record in
                HStack {
                    Text("Exchange \(idx + 1)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(KColor.textSecondary)
                    Spacer()
                    Text("HP \(String(format: "%.0f", record.playerHPAfter)) vs \(String(format: "%.0f", record.opponentHPAfter))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(KColor.textMuted)
                }
            }
        }
        .padding(KSpacing.md)
        .background(KColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.md))
    }

    // MARK: - Dismiss

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Text("Continue")
                .font(KTypeScale.bodyBold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(KSpacing.md)
                .background(KColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: KRadius.md))
        }
    }

    private var scale: CGFloat {
        guard let won = battle.playerWon else { return 1.0 }
        return won ? 1.05 : 0.95
    }
}
