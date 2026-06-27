import SwiftUI

struct ExchangeInputView: View {
    @ObservedObject var battle: BattleViewModel

    var body: some View {
        VStack(spacing: KSpacing.lg) {
            exchangeHeader
            timingBar
            mashButton
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

    // MARK: - Timing bar

    private var timingBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(KColor.surfaceDim)
                    .frame(height: 28)

                // Sweet spot zone
                let zoneLeft  = CGFloat(battle.sweetSpotCenter - battle.sweetSpotHalfWidth) * proxy.size.width
                let zoneWidth = CGFloat(battle.sweetSpotHalfWidth * 2) * proxy.size.width
                RoundedRectangle(cornerRadius: 4)
                    .fill(KColor.success.opacity(battle.hasTimingTapped ? 0.3 : 0.55))
                    .frame(width: max(4, zoneWidth), height: 28)
                    .offset(x: max(0, zoneLeft))
                    .animation(.none, value: battle.sweetSpotCenter)

                // Moving marker
                let markerX = CGFloat(battle.markerPosition) * proxy.size.width - 4
                RoundedRectangle(cornerRadius: 3)
                    .fill(markerColor)
                    .frame(width: 8, height: 36)
                    .offset(x: max(0, min(proxy.size.width - 8, markerX)))
                    .animation(.none, value: battle.markerPosition)
            }
        }
        .frame(height: 36)
        .contentShape(Rectangle())
        .onTapGesture {
            battle.handleTimingTap()
        }
        .overlay(alignment: .topTrailing) {
            if battle.hasTimingTapped {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(KColor.success)
                    .offset(y: -24)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.2), value: battle.hasTimingTapped)
    }

    private var markerColor: Color {
        battle.hasTimingTapped ? KColor.textMuted : KColor.accent
    }

    // MARK: - Mash button

    private var mashButton: some View {
        let maxMash = 12
        let ratio   = Double(battle.playerTapCount) / Double(maxMash)
        let staminaRatio = battle.playerStamina / battle.playerStats.stamina

        return Button {
            battle.handleMashTap()
        } label: {
            HStack(spacing: KSpacing.sm) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(staminaRatio > 0.3 ? .white : KColor.warning)
                Text(battle.playerTapCount > 0 ? "×\(battle.playerTapCount)" : "MASH")
                    .font(KTypeScale.bodyBold)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KSpacing.md)
            .background(
                LinearGradient(
                    colors: [KColor.accent.opacity(0.9 + ratio * 0.1), KColor.accent.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )
                .opacity(staminaRatio < 0.15 ? 0.5 : 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: KRadius.md))
            .scaleEffect(battle.playerTapCount > 0 ? 0.97 : 1.0)
            .animation(.spring(duration: 0.1), value: battle.playerTapCount)
        }
        .buttonStyle(.plain)
        .disabled(battle.playerTapCount >= maxMash)
    }
}
