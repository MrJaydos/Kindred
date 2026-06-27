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
        .overlay(alignment: .top) {
            if let call = game.pendingCall {
                CallBanner(call: call, onRespond: { game.perform(actionFor(call: call)) })
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring, value: game.pendingCall != nil)
            }
        }
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: KSpacing.lg) {
                stageBadge
                creatureStage
                stageLabel
                CareActionsView()
                    .padding(.horizontal, KSpacing.md)
                Spacer(minLength: KSpacing.xxl)
            }
            .padding(.top, KSpacing.lg)
        }
    }

    // MARK: - Creature stage area

    private var creatureStage: some View {
        CreatureRenderer(creature: game.creature)
            .frame(width: 220, height: 220)
    }

    private var stageBadge: some View {
        Text(game.creature.stage.rawValue.capitalized)
            .font(KTypeScale.caption)
            .foregroundStyle(KColor.textMuted)
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
                stageText("It has become itself.")
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
