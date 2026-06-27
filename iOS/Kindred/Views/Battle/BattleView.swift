import SwiftUI

struct BattleView: View {
    @ObservedObject var battle: BattleViewModel
    let playerCreature: Creature
    var onDismiss: () -> Void

    @AppStorage("kindred.hasSeenBattleRules") private var hasSeenBattleRules = false
    @State private var showRulesCard = false

    var body: some View {
        ZStack {
            KColor.background.ignoresSafeArea()
            content

            // Rules card — shown once, during countdown
            if showRulesCard {
                BattleRulesCard {
                    withAnimation(.easeOut(duration: 0.25)) { showRulesCard = false }
                    hasSeenBattleRules = true
                }
                .animation(.easeIn(duration: 0.3), value: showRulesCard)
                .zIndex(10)
            }
        }
        .onChange(of: battle.phase) { _, new in
            // Show rules card on first countdown; dismiss automatically when input window opens
            if case .countdown(let n) = new, n == 3, !hasSeenBattleRules {
                withAnimation { showRulesCard = true }
            }
            if case .inputWindow = new {
                withAnimation(.easeOut(duration: 0.2)) { showRulesCard = false }
            }
        }
    }

    // MARK: - Phase routing

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
            if !hasSeenBattleRules {
                Text("Tap ? in the corner anytime to review the rules")
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.textMuted)
            }
            Spacer()
        }
    }

    // MARK: - Battle arena

    private var battleArena: some View {
        ZStack {
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

            // Floating damage numbers overlay
            VStack(spacing: 0) {
                opponentDamageFloat
                    .padding(.horizontal, KSpacing.md)
                    .padding(.top, KSpacing.lg)
                Spacer()
                playerDamageFloat
                    .padding(.horizontal, KSpacing.md)
                    .padding(.bottom, KSpacing.lg)
            }
            .allowsHitTesting(false)

            // Rules reminder "?" button (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation { showRulesCard = true }
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(KColor.textMuted)
                            .padding(KSpacing.md)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Opponent panel (top)

    private var opponentPanel: some View {
        HStack(spacing: KSpacing.md) {
            miniCreature(branch: battle.opponentState.branch, isPlayer: false)

            VStack(alignment: .leading, spacing: KSpacing.xs) {
                Text("Opponent")
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.textMuted)
                HPBar(current: battle.opponentHP, max: battle.opponentMaxHP, color: KColor.danger)
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
            }
            miniCreature(branch: playerCreature.branch, isPlayer: true)
        }
        .padding(KSpacing.md)
        .background(KColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.md))
    }

    // MARK: - Floating damage numbers (positioned to match the panels)

    @ViewBuilder
    private var opponentDamageFloat: some View {
        if case .showingResult(_, _, let dmg) = battle.phase, dmg > 0 {
            HStack {
                Spacer()
                FloatingDamageNumber(damage: dmg, direction: -1)  // floats upward
                    .id("opp-dmg-\(battle.exchanges.count)")
            }
            .frame(height: 80)
        } else {
            Color.clear.frame(height: 80)
        }
    }

    @ViewBuilder
    private var playerDamageFloat: some View {
        if case .showingResult(_, let dmg, _) = battle.phase, dmg > 0 {
            HStack {
                FloatingDamageNumber(damage: dmg, direction: 1)   // floats downward
                    .id("player-dmg-\(battle.exchanges.count)")
                Spacer()
            }
            .frame(height: 80)
        } else {
            Color.clear.frame(height: 80)
        }
    }

    // MARK: - Center content

    @ViewBuilder
    private var centerContent: some View {
        switch battle.phase {
        case .inputWindow:
            ExchangeInputView(battle: battle)
                .transition(.opacity)

        case .resolving:
            VStack(spacing: KSpacing.sm) {
                ProgressView().tint(KColor.accent)
                Text("Resolving…")
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.textMuted)
            }
            .frame(height: 120)

        case .showingResult(let idx, let playerDmg, let oppDmg):
            exchangeResultSummary(idx: idx, playerDmg: playerDmg, oppDmg: oppDmg)
                .frame(height: 120)
                .transition(.opacity)

        default:
            EmptyView()
        }
    }

    private func exchangeResultSummary(idx: Int, playerDmg: Double, oppDmg: Double) -> some View {
        VStack(spacing: KSpacing.xs) {
            Text("Exchange \(idx + 1)")
                .font(KTypeScale.caption)
                .foregroundStyle(KColor.textMuted)

            Group {
                if playerDmg == 0 && oppDmg == 0 {
                    Text("No damage dealt")
                } else if oppDmg > playerDmg {
                    Text("You hit harder")
                        .foregroundStyle(KColor.success)
                } else if playerDmg > oppDmg {
                    Text("You took the worse hit")
                        .foregroundStyle(KColor.warning)
                } else {
                    Text("Even exchange")
                        .foregroundStyle(KColor.textSecondary)
                }
            }
            .font(KTypeScale.bodyBold)

            if idx + 1 < battle.totalExchanges && battle.playerHP > 0 && battle.opponentHP > 0 {
                Text("Next exchange…")
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.textMuted)
                    .padding(.top, KSpacing.xs)
            }
        }
    }

    // MARK: - Helpers

    private func miniCreature(branch: Branch?, isPlayer: Bool) -> some View {
        var c = Creature()
        c.stage  = .adult
        c.branch = branch ?? .drifter
        return CreatureRenderer(creature: c)
            .frame(width: 64, height: 64)
            .scaleEffect(x: isPlayer ? 1 : -1)
    }
}

// MARK: - Floating damage number

private struct FloatingDamageNumber: View {
    let damage: Double
    let direction: CGFloat   // +1 = down (player takes hit), -1 = up (opponent takes hit)

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        Text("-\(Int(damage))")
            .font(.system(size: 26, weight: .black, design: .rounded))
            .foregroundStyle(direction > 0 ? KColor.warning : KColor.danger)
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.85)) {
                    offset  = direction * 44
                    opacity = 0
                }
            }
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
                        .fill(current / max < 0.25 ? KColor.warning : KColor.warning.opacity(0.8))
                        .frame(width: p.size.width * CGFloat(max > 0 ? min(1, current / max) : 0))
                        .animation(.spring(duration: 0.4), value: current)
                }
            }
            .frame(height: 5)
            Text("Stamina")
                .font(.system(size: 9))
                .foregroundStyle(KColor.textMuted)
        }
    }
}
