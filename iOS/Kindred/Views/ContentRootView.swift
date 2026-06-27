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

    var body: some View {
        VStack(spacing: KSpacing.xl) {
            Spacer()
            eggVisual
            VStack(spacing: KSpacing.md) {
                Text(egg.kind.isTraited ? "A traited egg." : "A plain egg.")
                    .font(KTypeScale.title2)
                    .foregroundStyle(KColor.textPrimary)
                Text(egg.kind.isTraited
                     ? "Raised well. The next life carries something forward."
                     : "A life ended. The next begins without a head-start."
                )
                .font(KTypeScale.body)
                .foregroundStyle(KColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KSpacing.xxl)
            }
            Spacer()
            Button { game.hatchEgg() } label: {
                Text("Hatch")
                    .font(KTypeScale.bodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(KSpacing.md)
                    .background(KColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: KRadius.md))
            }
            .padding(.horizontal, KSpacing.xl)
            .padding(.bottom, KSpacing.xxl)
        }
        .background(KColor.background)
    }

    private var eggVisual: some View {
        ZStack {
            if egg.kind.isTraited {
                Circle()
                    .fill(KColor.accent.opacity(0.12))
                    .frame(width: 160, height: 160)
            }
            Ellipse()
                .fill(egg.kind.isTraited ? KColor.accent.opacity(0.8) : Color(white: 0.82))
                .frame(width: 90, height: 110)
        }
    }
}
