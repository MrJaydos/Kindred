import SwiftUI

struct ContentRootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        ZStack {
            switch game.phase {
            case .permissionPriming:
                PermissionPrimingView()
                    .transition(.opacity)

            case .living:
                mainTabs
                    .transition(.opacity)

            case .eggWaiting(let egg):
                EggWaitingView(egg: egg)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: phaseID)
        .fullScreenCover(isPresented: $game.showBattle) {
            if let battleVM = game.activeBattle {
                BattleView(
                    battle: battleVM,
                    playerCreature: game.creature,
                    onDismiss: { game.showBattle = false }
                )
            }
        }
    }

    // MARK: - Main tabs (creature + roster)

    private var mainTabs: some View {
        TabView {
            creatureTab
                .tabItem {
                    Label("Creature", systemImage: "sparkles")
                }

            RosterView()
                .tabItem {
                    Label("Roster", systemImage: "person.2")
                }
        }
        .tint(KColor.accent)
    }

    // MARK: - Creature tab

    private var creatureTab: some View {
        NavigationStack {
            CreatureView()
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    bumpButton
                    #if DEBUG
                    debugToggle
                    #endif
                }
        }
        #if DEBUG
        .sheet(isPresented: $game.showDebugOverlay) {
            DebugOverlayView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        #endif
    }

    // MARK: - Toolbar items

    @ToolbarContentBuilder
    private var bumpButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                game.initiateBump()
            } label: {
                HStack(spacing: 4) {
                    if game.isPairing {
                        ProgressView()
                            .tint(KColor.accent)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "hand.tap.fill")
                    }
                    Text(game.isPairing ? "Pairing…" : "Bump")
                        .font(KTypeScale.bodyBold)
                }
                .foregroundStyle(KColor.accent)
            }
            .disabled(game.isPairing)
        }
    }

    @ToolbarContentBuilder
    private var debugToggle: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                game.showDebugOverlay.toggle()
            } label: {
                Image(systemName: "ladybug")
                    .foregroundStyle(game.showDebugOverlay ? KColor.danger : KColor.textMuted)
            }
        }
    }

    // MARK: - Phase ID for animation

    private var phaseID: Int {
        switch game.phase {
        case .permissionPriming: return 0
        case .living:            return 1
        case .eggWaiting:        return 2
        }
    }
}

// MARK: - Egg waiting screen

struct EggWaitingView: View {
    let egg: Egg
    @EnvironmentObject private var game: GameViewModel

    private var deceased: Creature { game.creature }

    var body: some View {
        ScrollView {
            VStack(spacing: KSpacing.xl) {
                Spacer(minLength: KSpacing.xxl)
                eggVisual
                eggHeadline
                lifeSummaryCard
                Spacer(minLength: KSpacing.lg)
                hatchButton
                    .padding(.horizontal, KSpacing.xl)
                    .padding(.bottom, KSpacing.xxl)
            }
            .padding(.horizontal, KSpacing.md)
        }
        .background(KColor.background)
    }

    // MARK: - Egg visual

    private var eggVisual: some View {
        ZStack {
            if egg.kind.isTraited {
                Circle()
                    .fill(KColor.accent.opacity(0.10))
                    .frame(width: 170, height: 170)
                Circle()
                    .strokeBorder(KColor.accent.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 170, height: 170)
            }
            Ellipse()
                .fill(egg.kind.isTraited
                      ? LinearGradient(colors: [KColor.accent.opacity(0.9), KColor.accent.opacity(0.6)],
                                       startPoint: .top, endPoint: .bottom)
                      : LinearGradient(colors: [Color(white: 0.86), Color(white: 0.74)],
                                       startPoint: .top, endPoint: .bottom))
                .frame(width: 88, height: 108)
        }
    }

    // MARK: - Headline

    private var eggHeadline: some View {
        VStack(spacing: KSpacing.xs) {
            Text(egg.kind.isTraited ? "A traited egg." : "A plain egg.")
                .font(KTypeScale.title2)
                .foregroundStyle(KColor.textPrimary)

            Text(eggNarrative)
                .font(KTypeScale.body)
                .foregroundStyle(KColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KSpacing.xl)

            if case .traited(let boon) = egg.kind, boon > 0 {
                Text("Boon carried forward: +\(boon)")
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.accent)
                    .padding(.top, KSpacing.xs)
            }
        }
    }

    private var eggNarrative: String {
        switch (egg.kind.isTraited, deceased.stage) {
        case (true, .apex):
            return "A full life, completely realized. Something rare passes on."
        case (true, .adult):
            return "Raised well and lived fully. The next life carries a faint inheritance."
        case (false, .juvenile), (false, .blob), (false, .egg):
            return "A short life. The next begins without a head-start."
        default:
            return "A life ended. The next begins."
        }
    }

    // MARK: - Life summary card

    private var lifeSummaryCard: some View {
        VStack(alignment: .leading, spacing: KSpacing.md) {
            Text("Life summary")
                .font(KTypeScale.caption)
                .foregroundStyle(KColor.textMuted)

            summaryRow("Stage reached", value: deceased.stage.rawValue.capitalized)

            if let branch = deceased.branch {
                summaryRow("Branch", value: branch.rawValue)
            }

            let total = deceased.wins + deceased.losses
            if total > 0 {
                summaryRow("Battles", value: "\(deceased.wins)W – \(deceased.losses)L")
            }

            summaryRow("Care mistakes",
                       value: "\(deceased.lifetimeCareMistakes)",
                       accent: deceased.lifetimeCareMistakes > 8)
        }
        .padding(KSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.lg))
    }

    private func summaryRow(_ label: String, value: String, accent: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(KTypeScale.body)
                .foregroundStyle(KColor.textSecondary)
            Spacer()
            Text(value)
                .font(KTypeScale.bodyBold)
                .foregroundStyle(accent ? KColor.danger : KColor.textPrimary)
        }
    }

    // MARK: - Hatch button

    private var hatchButton: some View {
        Button { game.hatchEgg() } label: {
            Text("Begin a new life")
                .font(KTypeScale.bodyBold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(KSpacing.md)
                .background(KColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: KRadius.md))
        }
    }
}
