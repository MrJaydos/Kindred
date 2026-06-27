import SwiftUI

#if DEBUG

struct DebugOverlayView: View {
    @EnvironmentObject private var game: GameViewModel
    @EnvironmentObject private var env: AppEnvironment

    private var mock: MockBehaviorSource? { env.behaviorSource as? MockBehaviorSource }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sheetHeader
                    .padding(.horizontal, KSpacing.lg)
                    .padding(.top, KSpacing.sm)

                DebugSection("CONTROLS") {
                    timeScaleRow
                    Divider().padding(.vertical, KSpacing.xs)
                    actionButtonRow
                }

                if let mock {
                    DebugSection("BEHAVIOR PRESET") {
                        Picker("", selection: Binding(
                            get: { mock.selectedPreset },
                            set: { mock.selectedPreset = $0 }
                        )) {
                            ForEach(BehaviorPreset.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                DebugSection("AXES  →  TRENDING: \(game.trendingBranch.rawValue)") {
                    AxisRow("Vigor",        value: game.creature.traits.vigor)
                    AxisRow("Nocturnality", value: game.creature.traits.nocturnality)
                    AxisRow("Bond",         value: game.creature.traits.bond)
                    AxisRow("Discipline",   value: game.creature.traits.discipline)
                    AxisRow("Neglect",      value: game.neglect, color: KColor.danger)
                }

                DebugSection("CARE MISTAKES") {
                    HStack(spacing: KSpacing.xl) {
                        statPill("This stage", "\(game.stageCareMistakes)")
                        statPill("Lifetime",   "\(game.creature.lifetimeCareMistakes)")
                        statPill("Warning",    "\(game.careWarningLevel)")
                    }
                }

                if let mock {
                    DebugSection("SIGNAL OVERRIDES  (−1 = preset)") {
                        SignalSlider("Steps",      value: Binding(get: { mock.manualSteps },            set: { mock.manualSteps = $0 }))
                        SignalSlider("Night Act",  value: Binding(get: { mock.manualNightActivity },    set: { mock.manualNightActivity = $0 }))
                        SignalSlider("Sleep Reg",  value: Binding(get: { mock.manualSleepRegularity },  set: { mock.manualSleepRegularity = $0 }))
                        SignalSlider("Bond",       value: Binding(get: { mock.manualInteractionCount }, set: { mock.manualInteractionCount = $0 }))
                    }
                }

                Spacer(minLength: KSpacing.xxl)
            }
        }
        .background(KColor.background)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: KSpacing.sm) {
            Text("DEBUG")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(KColor.danger)
            Text("·")
                .foregroundStyle(KColor.textMuted)
            Text(game.creature.stage.rawValue.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(KColor.textMuted)
            if let branch = game.creature.branch {
                Text("·")
                    .foregroundStyle(KColor.textMuted)
                Text(branch.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(KColor.textSecondary)
            }
            Spacer()
            Text("day \(String(format: "%.2f", game.gameDaysAlive))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(KColor.textMuted)
        }
        .padding(.bottom, KSpacing.xs)
    }

    // MARK: - Time scale

    private var timeScaleRow: some View {
        VStack(alignment: .leading, spacing: KSpacing.sm) {
            HStack {
                Label("Time scale", systemImage: "timer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KColor.textPrimary)
                Spacer()
                Text("\(Int(game.debugTimeScale))×")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(KColor.accent)
                    .frame(minWidth: 44, alignment: .trailing)
            }
            Slider(value: $game.debugTimeScale, in: 1...3600, step: 1)
                .tint(KColor.accent)
            HStack(spacing: KSpacing.xl) {
                statPill("Game days", String(format: "%.2f", game.gameDaysAlive))
                statPill("Awake hrs",  String(format: "%.1f", game.awakeHoursSinceAdult))
            }
            // Quick preset buttons for common time scales
            HStack(spacing: KSpacing.sm) {
                ForEach([1, 60, 360, 1440, 3600], id: \.self) { scale in
                    Button("\(scale)×") {
                        game.debugTimeScale = Double(scale)
                    }
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Int(game.debugTimeScale) == scale ? .white : KColor.accent)
                    .padding(.horizontal, KSpacing.sm)
                    .padding(.vertical, 6)
                    .background(Int(game.debugTimeScale) == scale ? KColor.accent : KColor.accentSoft)
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Action buttons

    private var actionButtonRow: some View {
        HStack(spacing: KSpacing.sm) {
            DebugButton("Daily tick",    icon: "sun.max")    { game.debugForceDailyTick() }
            DebugButton("Stage check",  icon: "arrow.up")   { game.debugForceStageCheck() }
            DebugButton("Force death",  icon: "xmark.circle", tint: KColor.danger) { game.debugForceDeath() }
        }
    }

    // MARK: - Helpers

    private func statPill(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(KColor.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(KColor.textMuted)
        }
    }
}

// MARK: - Section wrapper

private struct DebugSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KSpacing.sm) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(KColor.textMuted)
                .padding(.bottom, 2)
            content()
        }
        .padding(KSpacing.md)
        .background(KColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.md))
        .padding(.horizontal, KSpacing.md)
        .padding(.top, KSpacing.sm)
    }
}

// MARK: - Axis row

private struct AxisRow: View {
    let label: String
    let value: Double
    var color: Color = KColor.accent

    init(_ label: String, value: Double, color: Color = KColor.accent) {
        self.label = label; self.value = value; self.color = color
    }

    var body: some View {
        HStack(spacing: KSpacing.sm) {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(KColor.textSecondary)
                .frame(width: 100, alignment: .leading)
            GeometryReader { p in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(KColor.surfaceDim)
                    RoundedRectangle(cornerRadius: 3).fill(color)
                        .frame(width: p.size.width * CGFloat(value / 100))
                        .animation(.spring(duration: 0.4), value: value)
                }
            }
            .frame(height: 10)
            Text(String(format: "%.1f", value))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(KColor.textMuted)
                .frame(width: 38, alignment: .trailing)
        }
    }
}

// MARK: - Signal slider

private struct SignalSlider: View {
    let label: String
    @Binding var value: Double

    init(_ label: String, value: Binding<Double>) {
        self.label = label; _value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(KColor.textSecondary)
                Spacer()
                Text(value < 0 ? "preset" : String(format: "%.0f", value))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(value < 0 ? KColor.textMuted : KColor.accent)
            }
            Slider(value: $value, in: -1...100, step: 1)
                .tint(KColor.accent)
        }
    }
}

// MARK: - Debug button

private struct DebugButton: View {
    let label: String
    let icon: String
    var tint: Color = KColor.accent
    let action: () -> Void

    init(_ label: String, icon: String, tint: Color = KColor.accent, _ action: @escaping () -> Void) {
        self.label = label; self.icon = icon; self.tint = tint; self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, KSpacing.sm)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: KRadius.sm))
        }
        .buttonStyle(.plain)
    }
}

#endif
