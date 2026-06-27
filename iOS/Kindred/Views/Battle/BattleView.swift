import SwiftUI

struct BattleView: View {
    @ObservedObject var battle: BattleViewModel
    let playerCreature: Creature
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            KColor.background.ignoresSafeArea()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch battle.phase {
        case .countdown(let n):
            countdownView(number: n)

        case .inputWindow, .resolving, .showingResult:
            battleArena

        case .finished:
            BattleResultView(battle: battle, playerCreature: playerCreature, onDismiss: onDismiss)
        }
    }

    // MARK: - Countdown

    private func countdownView(number: Int) -> some View {
        VStack(spacing: KSpacing.lg) {
            Spacer()
            Text(number == 1 ? "GO!" : "\(number)")
                .font(.system(size: 80, weight: .black))
                .foregroundStyle(KColor.textPrimary)
                .contentTransition(.numericText())
                .animation(.spring, value: number)
            Text("Get ready")
                .font(KTypeScale.body)
                .foregroundStyle(KColor.textMuted)
            Spacer()
        }
    }

    // MARK: - Battle arena

    private var battleArena: some View {
        VStack(spacing: 0) {
            opponentPanel
                .padding(.horizontal, KSpacing.md)
                .padding(.top, KSpacing.lg)

            Spacer()

            centerContent
                .padding(.horizontal, KSpacing.md)

            Spacer()

            playerPanel
                .padding(.horizontal, KSpacing.md)
                .padding(.bottom, KSpacing.lg)
        }
    }

    // MARK: - Opponent panel (top)

    private var opponentPanel: some View {
        HStack(spacing: KSpacing.md) {
            miniCreature(branch: opponentBranch, isPlayer: false)

            VStack(alignment: .leading, spacing: KSpacing.xs) {
                Text("Opponent")
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.textMuted)
                HPBar(current: battle.opponentHP, max: battle.opponentMaxHP, color: KColor.danger)
                if case .showingResult(_, _, let dmg) = battle.phase, dmg > 0 {
                    damageLabel("-\(Int(dmg))", color: KColor.danger)
                }
            }
        }
        .padding(KSpacing.md)
        .background(KColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.md))
    }

    // MARK: - Player panel (bottom)

    private var playerPanel: some View {
        HStack(spacing: KSpacing.md) {
            VStack(alignment: .leading, spacing: KSpacing.xs) {
                Text("You")
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.textMuted)
                HPBar(current: battle.playerHP, max: battle.playerMaxHP, color: KColor.success)
                StaminaBar(current: battle.playerStamina, max: battle.playerStats.stamina)
                if case .showingResult(_, let dmg, _) = battle.phase, dmg > 0 {
                    damageLabel("-\(Int(dmg))", color: KColor.warning)
                }
            }
            miniCreature(branch: playerCreature.branch, isPlayer: true)
        }
        .padding(KSpacing.md)
        .background(KColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.md))
    }

    // MARK: - Center content

    @ViewBuilder
    private var centerContent: some View {
        switch battle.phase {
        case .inputWindow:
            ExchangeInputView(battle: battle)

        case .resolving:
            VStack(spacing: KSpacing.sm) {
                ProgressView()
                    .tint(KColor.accent)
                Text("Resolving…")
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.textMuted)
            }
            .frame(height: 100)

        case .showingResult(let idx, _, _):
            VStack(spacing: KSpacing.sm) {
                Text("Exchange \(idx + 1) complete")
                    .font(KTypeScale.bodyBold)
                    .foregroundStyle(KColor.textPrimary)
                if idx + 1 < battle.totalExchanges && battle.playerHP > 0 && battle.opponentHP > 0 {
                    Text("Next exchange…")
                        .font(KTypeScale.caption)
                        .foregroundStyle(KColor.textMuted)
                }
            }
            .frame(height: 100)

        default:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private var opponentBranch: Branch {
        battle.opponentState.branch
    }

    private func miniCreature(branch: Branch?, isPlayer: Bool) -> some View {
        let creature = makeMiniCreature(branch: branch)
        return CreatureRenderer(creature: creature)
            .frame(width: 64, height: 64)
            .scaleEffect(x: isPlayer ? 1 : -1)
    }

    private func makeMiniCreature(branch: Branch?) -> Creature {
        var c = Creature()
        c.stage  = .adult
        c.branch = branch ?? .drifter
        return c
    }

    private func damageLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Stat bars

private struct HPBar: View {
    let current: Double
    let max: Double
    let color: Color

    var body: some View {
        GeometryReader { p in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(KColor.surfaceDim)
                RoundedRectangle(cornerRadius: 3)
                    .fill(current / max < 0.25 ? KColor.danger : color)
                    .frame(width: p.size.width * CGFloat(max > 0 ? current / max : 0))
                    .animation(.spring(duration: 0.4), value: current)
            }
        }
        .frame(height: 8)
    }
}

private struct StaminaBar: View {
    let current: Double
    let max: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 9))
                .foregroundStyle(KColor.textMuted)
            GeometryReader { p in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(KColor.surfaceDim)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(KColor.warning.opacity(0.8))
                        .frame(width: p.size.width * CGFloat(max > 0 ? min(1, current / max) : 0))
                        .animation(.spring(duration: 0.4), value: current)
                }
            }
            .frame(height: 5)
        }
    }
}
