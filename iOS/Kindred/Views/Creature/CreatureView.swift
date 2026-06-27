import SwiftUI

struct CreatureView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            scrollContent

            #if DEBUG
            if game.showDebugOverlay {
                DebugOverlayView()
                    .padding(KSpacing.md)
            }
            #endif
        }
        .background(KColor.background)
        // Care-call banner
        .overlay(alignment: .top) {
            if let call = game.pendingCall {
                CallBanner(call: call, onRespond: { game.perform(actionFor(call: call)) })
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring, value: game.pendingCall != nil)
            }
        }
        // Stage-transition overlay
        .overlay {
            if let banner = game.transitionBanner {
                StageTransitionOverlay(banner: banner)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: game.transitionBanner)
            }
        }
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: KSpacing.lg) {
                // Care-mistake warning strip
                if game.careWarningLevel > 0 {
                    CareWarningStrip(level: game.careWarningLevel, mistakes: game.stageCareMistakes)
                        .padding(.horizontal, KSpacing.md)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                stageBadge
                creatureStage
                stageLabel

                // Lineage boon badge
                if game.lineage.totalBoon > 0 {
                    LineageBoonBadge(boon: game.lineage.totalBoon)
                }

                CareActionsView()
                    .padding(.horizontal, KSpacing.md)

                Spacer(minLength: KSpacing.xxl)
            }
            .padding(.top, KSpacing.lg)
            .animation(.easeInOut(duration: 0.3), value: game.careWarningLevel)
        }
    }

    // MARK: - Creature stage area

    private var creatureStage: some View {
        CreatureRenderer(creature: game.creature)
            .frame(width: 220, height: 220)
    }

    private var stageBadge: some View {
        HStack(spacing: KSpacing.xs) {
            Text(game.creature.stage.rawValue.capitalized)
                .font(KTypeScale.caption)
                .foregroundStyle(KColor.textMuted)
            if let branch = game.creature.branch {
                Text("·")
                    .foregroundStyle(KColor.textMuted)
                    .font(KTypeScale.caption)
                Text(branch.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(branchColor(branch))
            }
        }
        .padding(.horizontal, KSpacing.sm)
        .padding(.vertical, KSpacing.xs)
        .background(KColor.surfaceDim)
        .clipShape(Capsule())
    }

    private var stageLabel: some View {
        Group {
            switch game.creature.stage {
            case .egg:
                stageText("Something is stirring…")
            case .blob:
                stageText("A shapeless thing. It watches you.")
            case .juvenile:
                stageText("Growing. Beginning to take form.")
            case .adult:
                if let branch = game.creature.branch {
                    stageText(adultFlavor(branch))
                } else {
                    stageText("It has become itself.")
                }
            case .apex:
                stageText("Something rare. Hard-earned.")
            }
        }
    }

    private func stageText(_ s: String) -> some View {
        Text(s)
            .font(KTypeScale.body)
            .foregroundStyle(KColor.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, KSpacing.xxl)
    }

    // MARK: - Flavor

    private func adultFlavor(_ branch: Branch) -> String {
        switch branch {
        case .swift_:   return "Quick and restless. It doesn't stay still."
        case .feral:    return "Nocturnal. Something feral lives behind its eyes."
        case .bonded:   return "It knows you. It trusts you."
        case .stalwart: return "Steady. It endures."
        case .distant:  return "It is its own creature now. Cold, but alive."
        case .drifter:  return "Unremarkable. Adaptable. Quietly itself."
        }
    }

    private func branchColor(_ branch: Branch) -> Color {
        switch branch {
        case .swift_:   return KColor.branchSwift
        case .feral:    return KColor.branchFeral
        case .bonded:   return KColor.branchBonded
        case .stalwart: return KColor.branchStalwart
        case .distant:  return KColor.branchDistant
        case .drifter:  return KColor.branchDrifter
        }
    }

    // MARK: - Helpers

    private func actionFor(call: NeedCall) -> CareAction {
        switch call.need {
        case .hunger:    return .feed
        case .energy:    return .rest
        case .hygiene:   return .clean
        case .happiness: return .play
        }
    }
}

// MARK: - Stage transition overlay

struct StageTransitionOverlay: View {
    let banner: TransitionBanner
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: KSpacing.md) {
                if let branch = banner.branch {
                    Circle()
                        .fill(branchColor(branch).opacity(0.25))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 32))
                                .foregroundStyle(branchColor(branch))
                        )
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundStyle(KColor.accent)
                }
                Text(banner.text)
                    .font(KTypeScale.title3)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(KSpacing.xl)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) { opacity = 1 }
        }
    }

    private func branchColor(_ branch: Branch) -> Color {
        switch branch {
        case .swift_:   return KColor.branchSwift
        case .feral:    return KColor.branchFeral
        case .bonded:   return KColor.branchBonded
        case .stalwart: return KColor.branchStalwart
        case .distant:  return KColor.branchDistant
        case .drifter:  return KColor.branchDrifter
        }
    }
}

// MARK: - Care warning strip

private struct CareWarningStrip: View {
    let level: Int       // 1 = caution, 2 = danger
    let mistakes: Int

    var body: some View {
        HStack(spacing: KSpacing.sm) {
            Image(systemName: level == 2 ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                .foregroundStyle(level == 2 ? KColor.danger : KColor.warning)
            Text(level == 2
                 ? "Your creature is struggling. \(mistakes) missed calls."
                 : "Your creature needs more care. \(mistakes) missed calls."
            )
            .font(KTypeScale.caption)
            .foregroundStyle(KColor.textPrimary)
            Spacer()
        }
        .padding(KSpacing.sm)
        .background((level == 2 ? KColor.danger : KColor.warning).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: KRadius.sm))
    }
}

// MARK: - Lineage boon badge

private struct LineageBoonBadge: View {
    let boon: Int

    var body: some View {
        HStack(spacing: KSpacing.xs) {
            Image(systemName: "seal.fill")
                .font(.system(size: 11))
                .foregroundStyle(KColor.accent)
            Text("Bloodline boon ×\(boon)")
                .font(KTypeScale.caption)
                .foregroundStyle(KColor.accent)
        }
        .padding(.horizontal, KSpacing.sm)
        .padding(.vertical, KSpacing.xs)
        .background(KColor.accentSoft)
        .clipShape(Capsule())
    }
}

// MARK: - Call Banner

private struct CallBanner: View {
    let call: NeedCall
    let onRespond: () -> Void

    var body: some View {
        HStack {
            Image(systemName: iconFor(call.need))
                .foregroundStyle(KColor.warning)
            Text("Your creature needs \(call.need.rawValue.lowercased()).")
                .font(KTypeScale.bodyBold)
                .foregroundStyle(KColor.textPrimary)
            Spacer()
            Button("Help", action: onRespond)
                .font(KTypeScale.bodyBold)
                .foregroundStyle(KColor.accent)
        }
        .padding(KSpacing.md)
        .background(KColor.surface.shadow(.drop(radius: 4)))
    }

    private func iconFor(_ need: NeedType) -> String {
        switch need {
        case .hunger:    return "fork.knife"
        case .energy:    return "moon.fill"
        case .hygiene:   return "sparkles"
        case .happiness: return "figure.play"
        }
    }
}
