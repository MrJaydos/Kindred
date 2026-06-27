import SwiftUI

#if DEBUG

struct DebugOverlayView: View {
    @EnvironmentObject private var game: GameViewModel
    @EnvironmentObject private var env: AppEnvironment

    // Only accessible if the behavior source is the mock
    private var mock: MockBehaviorSource? {
        env.behaviorSource as? MockBehaviorSource
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KSpacing.sm) {
                header
                Divider()
                axisSection
                Divider()
                careSection
                Divider()
                timeSection
                if let mock {
                    Divider()
                    presetSection(mock: mock)
                    Divider()
                    sliderSection(mock: mock)
                }
                Divider()
                actionButtons
            }
            .padding(KSpacing.sm)
        }
        .frame(maxWidth: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.md))
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("DEBUG")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(KColor.danger)
            Spacer()
            Text(game.creature.stage.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(KColor.textMuted)
        }
    }

    private var axisSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            debugLabel("AXES → TRENDING: \(game.trendingBranch.rawValue)")
            AxisRow("Vigor",        value: game.creature.traits.vigor)
            AxisRow("Nocturnality", value: game.creature.traits.nocturnality)
            AxisRow("Bond",         value: game.creature.traits.bond)
            AxisRow("Discipline",   value: game.creature.traits.discipline)
            AxisRow("Neglect",      value: game.neglect, color: KColor.danger)
        }
    }

    private var careSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            debugLabel("CARE MISTAKES")
            Text("This stage: \(game.stageCareMistakes)  Lifetime: \(game.creature.lifetimeCareMistakes)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(KColor.textSecondary)
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            debugLabel("TIME SCALE")
            HStack {
                Text("\(Int(game.debugTimeScale))×")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(KColor.textSecondary)
                    .frame(width: 40)
                Slider(value: $game.debugTimeScale, in: 1...3600, step: 1)
            }
            Text("Awake hrs (adult): \(String(format: "%.1f", game.awakeHoursSinceAdult)) / 72")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(KColor.textMuted)
        }
    }

    private func presetSection(mock: MockBehaviorSource) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            debugLabel("BEHAVIOR PRESET")
            Picker("", selection: Binding(get: { mock.selectedPreset }, set: { mock.selectedPreset = $0 })) {
                ForEach(BehaviorPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .scaleEffect(0.85, anchor: .leading)
        }
    }

    private func sliderSection(mock: MockBehaviorSource) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            debugLabel("MANUAL SIGNAL OVERRIDES  (–1 = preset)")
            SignalSlider("Steps",       value: Binding(get: { mock.manualSteps },            set: { mock.manualSteps = $0 }))
            SignalSlider("Night Act",   value: Binding(get: { mock.manualNightActivity },    set: { mock.manualNightActivity = $0 }))
            SignalSlider("Sleep Reg",   value: Binding(get: { mock.manualSleepRegularity },  set: { mock.manualSleepRegularity = $0 }))
            SignalSlider("Bond",        value: Binding(get: { mock.manualInteractionCount }, set: { mock.manualInteractionCount = $0 }))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: KSpacing.xs) {
            DebugButton("Force daily tick")  { game.debugForceDailyTick() }
            DebugButton("Force stage check") { game.debugForceStageCheck() }
        }
    }

    // MARK: - Helpers

    private func debugLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(KColor.textMuted)
    }
}

// MARK: - Sub-views

private struct AxisRow: View {
    let label: String
    let value: Double
    var color: Color = KColor.accent

    init(_ label: String, value: Double, color: Color = KColor.accent) {
        self.label = label; self.value = value; self.color = color
    }

    var body: some View {
        HStack(spacing: KSpacing.xs) {
            Text(label.padding(toLength: 13, withPad: " ", startingAt: 0))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(KColor.textSecondary)
            GeometryReader { p in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(KColor.surfaceDim)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: p.size.width * CGFloat(value / 100))
                }
            }
            .frame(height: 8)
            Text(String(format: "%5.1f", value))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(KColor.textMuted)
        }
    }
}

private struct SignalSlider: View {
    let label: String
    @Binding var value: Double

    init(_ label: String, value: Binding<Double>) {
        self.label = label; _value = value
    }

    var body: some View {
        HStack(spacing: KSpacing.xs) {
            Text(label.padding(toLength: 9, withPad: " ", startingAt: 0))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(KColor.textSecondary)
            Slider(value: $value, in: -1...100, step: 1)
            Text(value < 0 ? " pre" : String(format: "%3.0f", value))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(KColor.textMuted)
                .frame(width: 28)
        }
    }
}

private struct DebugButton: View {
    let label: String
    let action: () -> Void

    init(_ label: String, _ action: @escaping () -> Void) {
        self.label = label; self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(KColor.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(KColor.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: KRadius.sm))
        }
        .buttonStyle(.plain)
    }
}

#endif
