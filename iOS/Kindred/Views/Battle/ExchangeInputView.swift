import SwiftUI

struct ExchangeInputView: View {
    @ObservedObject var battle: BattleViewModel

    var body: some View {
        VStack(spacing: KSpacing.lg) {
            exchangeHeader
            timingSection
            mashSection
        }
        .padding(KSpacing.lg)
        .background(KColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.lg))
    }

    // MARK: - Header

    private var exchangeHeader: some View {
        HStack {
            Text("Exchange \(battle.currentExchangeIndex + 1) of \(battle.totalExchanges)")
                .font(KTypeScale.bodyBold)
                .foregroundStyle(KColor.textPrimary)
            Spacer()
            Text(String(format: "%.1fs", battle.windowTimeRemaining))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(battle.windowTimeRemaining < 0.8 ? KColor.danger : KColor.textSecondary)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Timing section

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: KSpacing.xs) {
            HStack {
                Text("TIMING")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(KColor.textMuted)
                Spacer()
                // Feedback label replaces the instruction once tapped
                if battle.hasTimingTapped {
                    timingFeedbackLabel
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else {
                    Text("Tap when marker hits the zone")
                        .font(.system(size: 10))
                        .foregroundStyle(KColor.textMuted)
                }
            }
            .animation(.spring(duration: 0.2), value: battle.hasTimingTapped)

            timingBar
        }
    }

    private var timingFeedbackLabel: some View {
        let (text, color) = feedbackStyle(battle.timingFeedback)
        return Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
    }

    private func feedbackStyle(_ fb: String?) -> (String, Color) {
        switch fb {
        case "Perfect!": return ("Perfect!", KColor.success)
        case "Good":     return ("Good",     KColor.accent)
        case "Late":     return ("Late",     KColor.warning)
        default:         return ("Miss",     KColor.danger)
        }
    }

    // MARK: - Timing bar

    private var timingBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(KColor.surfaceDim)
                    .frame(height: 32)

                // Sweet spot zone — labeled
                let zoneLeft  = CGFloat(battle.sweetSpotCenter - battle.sweetSpotHalfWidth) * proxy.size.width
                let zoneWidth = CGFloat(battle.sweetSpotHalfWidth * 2) * proxy.size.width
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(KColor.success.opacity(battle.hasTimingTapped ? 0.25 : 0.5))
                        .frame(width: max(4, zoneWidth), height: 32)
                    if zoneWidth > 28 {
                        Text("ZONE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(KColor.success.opacity(battle.hasTimingTapped ? 0.4 : 0.9))
                    }
                }
                .offset(x: max(0, zoneLeft))
                .animation(.none, value: battle.sweetSpotCenter)

                // Moving marker
                let markerX = CGFloat(battle.markerPosition) * proxy.size.width - 4
                RoundedRectangle(cornerRadius: 3)
                    .fill(battle.hasTimingTapped ? KColor.textMuted : KColor.accent)
                    .frame(width: 8, height: 40)
                    .offset(x: max(0, min(proxy.size.width - 8, markerX)))
                    .animation(.none, value: battle.markerPosition)
            }
        }
        .frame(height: 40)
        .contentShape(Rectangle())
        .onTapGesture { battle.handleTimingTap() }
        .overlay(alignment: .trailing) {
            if battle.hasTimingTapped {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(KColor.success)
                    .offset(x: 24)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.2), value: battle.hasTimingTapped)
    }

    // MARK: - Mash section

    private var mashSection: some View {
        let maxMash      = battle.totalExchanges * 2 + 2   // matches config.skill.maxMash = 12
        let staminaRatio = battle.playerStamina / max(1, battle.playerStats.stamina)
        let tapRatio     = Double(battle.playerTapCount) / Double(max(1, maxMash))

        return VStack(alignment: .leading, spacing: KSpacing.xs) {
            HStack {
                Text("MASH")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(KColor.textMuted)
                Spacer()
                Text(staminaRatio < 0.25
                     ? "Stamina low — hits weakening"
                     : "Extra taps = extra power (costs stamina)")
                    .font(.system(size: 10))
                    .foregroundStyle(staminaRatio < 0.25 ? KColor.warning : KColor.textMuted)
            }

            Button { battle.handleMashTap() } label: {
                HStack(spacing: KSpacing.sm) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(staminaRatio > 0.25 ? .white : KColor.warning)
                    Text(battle.playerTapCount > 0 ? "×\(battle.playerTapCount)" : "MASH")
                        .font(KTypeScale.bodyBold)
                        .foregroundStyle(.white)
                    Spacer()
                    // Tiny stamina bar inside button
                    GeometryReader { p in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.2))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(staminaRatio < 0.25 ? KColor.warning : Color.white.opacity(0.8))
                                .frame(width: p.size.width * CGFloat(staminaRatio))
                                .animation(.spring(duration: 0.3), value: staminaRatio)
                        }
                    }
                    .frame(width: 48, height: 5)
                }
                .padding(.vertical, KSpacing.md)
                .padding(.horizontal, KSpacing.md)
                .background(
                    LinearGradient(
                        colors: [KColor.accent.opacity(0.9 + tapRatio * 0.1), KColor.accent.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .opacity(staminaRatio < 0.12 ? 0.5 : 1.0)
                )
                .clipShape(RoundedRectangle(cornerRadius: KRadius.md))
                .scaleEffect(battle.playerTapCount > 0 ? 0.97 : 1.0)
                .animation(.spring(duration: 0.08), value: battle.playerTapCount)
            }
            .buttonStyle(.plain)
            .disabled(battle.playerTapCount >= maxMash || staminaRatio <= 0)
        }
    }
}
