import SwiftUI

struct RosterView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        NavigationStack {
            Group {
                if game.roster.tamers.isEmpty {
                    emptyState
                } else {
                    tamerList
                }
            }
            .navigationTitle("Roster")
            .navigationBarTitleDisplayMode(.large)
            .background(KColor.background)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: KSpacing.md) {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 44))
                .foregroundStyle(KColor.textMuted)
            Text("No tamers yet.")
                .font(KTypeScale.bodyBold)
                .foregroundStyle(KColor.textPrimary)
            Text("Bump phones with someone to add them.")
                .font(KTypeScale.body)
                .foregroundStyle(KColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KSpacing.xxl)
            Spacer()
        }
    }

    // MARK: - Tamer list

    private var tamerList: some View {
        List {
            Section {
                ForEach(Array(game.roster.ranked().enumerated()), id: \.element.id) { rank, tamer in
                    NavigationLink {
                        TamerDetailView(tamer: tamer)
                    } label: {
                        TamerRow(rank: rank + 1, tamer: tamer)
                    }
                    .listRowBackground(KColor.surface)
                }
            } header: {
                Text("\(game.roster.tamers.count) tamers met in person")
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.textMuted)
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(KColor.background)
    }
}

// MARK: - Tamer row

private struct TamerRow: View {
    let rank: Int
    let tamer: MetTamer

    var body: some View {
        HStack(spacing: KSpacing.md) {
            Text("#\(rank)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(rank == 1 ? KColor.branchBonded : KColor.textMuted)
                .frame(width: 32)

            miniCreature

            VStack(alignment: .leading, spacing: 2) {
                Text(tamer.displayName)
                    .font(KTypeScale.bodyBold)
                    .foregroundStyle(KColor.textPrimary)
                Text(stageLabel)
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(tamer.headToHeadRecord)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(KColor.textPrimary)
                Text("W–L")
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.textMuted)
            }
        }
        .padding(.vertical, KSpacing.xs)
    }

    private var miniCreature: some View {
        let c = makeCreature()
        return CreatureRenderer(creature: c)
            .frame(width: 40, height: 40)
    }

    private func makeCreature() -> Creature {
        var c = Creature()
        c.stage  = tamer.lastSeenCreature.stage
        c.branch = tamer.lastSeenCreature.branch
        return c
    }

    private var stageLabel: String {
        let stage  = tamer.lastSeenCreature.stage.rawValue.capitalized
        let branch = tamer.lastSeenCreature.branch.map { " · \($0.rawValue)" } ?? ""
        let boon   = tamer.lastSeenCreature.lineageBoon > 0 ? " ✦\(tamer.lastSeenCreature.lineageBoon)" : ""
        return stage + branch + boon
    }
}
