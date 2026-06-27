import SwiftUI

struct TamerDetailView: View {
    let tamer: MetTamer

    var body: some View {
        ScrollView {
            VStack(spacing: KSpacing.lg) {
                creatureCard
                recordCard
                actionsCard
            }
            .padding(KSpacing.md)
        }
        .navigationTitle(tamer.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .background(KColor.background)
    }

    // MARK: - Creature card

    private var creatureCard: some View {
        VStack(spacing: KSpacing.md) {
            CreatureRenderer(creature: makeCreature())
                .frame(width: 140, height: 140)

            VStack(spacing: KSpacing.xs) {
                if let branch = tamer.lastSeenCreature.branch {
                    Text(branch.rawValue)
                        .font(KTypeScale.title3)
                        .foregroundStyle(KColor.textPrimary)
                }
                Text(tamer.lastSeenCreature.stage.rawValue.capitalized)
                    .font(KTypeScale.body)
                    .foregroundStyle(KColor.textSecondary)
                if tamer.lastSeenCreature.lineageBoon > 0 {
                    Text("Lineage boon: +\(tamer.lastSeenCreature.lineageBoon)")
                        .font(KTypeScale.caption)
                        .foregroundStyle(KColor.accent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(KSpacing.lg)
        .background(KColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.lg))
    }

    // MARK: - Record card

    private var recordCard: some View {
        VStack(alignment: .leading, spacing: KSpacing.sm) {
            Text("Head-to-head")
                .font(KTypeScale.bodyBold)
                .foregroundStyle(KColor.textPrimary)

            HStack(spacing: KSpacing.xl) {
                statCell(label: "Wins", value: "\(tamer.winsAgainst)", color: KColor.success)
                statCell(label: "Losses", value: "\(tamer.lossesAgainst)", color: KColor.danger)
                statCell(label: "Record", value: tamer.headToHeadRecord, color: KColor.textPrimary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                metRow("First met", date: tamer.firstMetAt)
                metRow("Last met",  date: tamer.lastMetAt)
            }
        }
        .padding(KSpacing.md)
        .background(KColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.lg))
    }

    private func statCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(KTypeScale.title3)
                .foregroundStyle(color)
            Text(label)
                .font(KTypeScale.caption)
                .foregroundStyle(KColor.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func metRow(_ label: String, date: Date) -> some View {
        HStack {
            Text(label)
                .font(KTypeScale.caption)
                .foregroundStyle(KColor.textMuted)
            Spacer()
            Text(date, style: .date)
                .font(KTypeScale.caption)
                .foregroundStyle(KColor.textSecondary)
        }
    }

    // MARK: - Actions card (gated)

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: KSpacing.sm) {
            Text("Actions")
                .font(KTypeScale.bodyBold)
                .foregroundStyle(KColor.textPrimary)

            Text("These require a fresh bump to become available.")
                .font(KTypeScale.caption)
                .foregroundStyle(KColor.textMuted)

            HStack(spacing: KSpacing.md) {
                gatedButton("Rematch",  icon: "bolt.fill")
                gatedButton("Breed",    icon: "leaf.fill")
                gatedButton("Trade",    icon: "arrow.left.arrow.right")
            }
        }
        .padding(KSpacing.md)
        .background(KColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.lg))
    }

    private func gatedButton(_ label: String, icon: String) -> some View {
        VStack(spacing: KSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(KColor.textMuted)
            Text(label)
                .font(KTypeScale.caption)
                .foregroundStyle(KColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KSpacing.sm)
        .background(KColor.surfaceDim)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: KRadius.sm)
                .stroke(KColor.textMuted.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func makeCreature() -> Creature {
        var c = Creature()
        c.stage  = tamer.lastSeenCreature.stage
        c.branch = tamer.lastSeenCreature.branch
        return c
    }
}
