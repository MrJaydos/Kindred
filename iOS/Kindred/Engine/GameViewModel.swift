import Foundation
import SwiftUI

// MARK: - Game state

enum GamePhase {
    case permissionPriming
    case living          // creature is alive
    case eggWaiting(Egg) // creature just died, egg is ready to hatch
}

// MARK: - ViewModel

@MainActor
final class GameViewModel: ObservableObject {

    // MARK: Published state

    @Published private(set) var creature: Creature
    @Published private(set) var lineage: Lineage = Lineage()
    @Published private(set) var pendingCall: NeedCall?
    @Published private(set) var phase: GamePhase = .permissionPriming
    @Published private(set) var lastEvolutionEvent: EvolutionEvent?

    // Debug controls — only meaningful in DEBUG builds but present in release (hidden by view)
    @Published var debugTimeScale: Double = 60     // game-minutes per real-second
    @Published var showDebugOverlay: Bool = false
    @Published var awakeHoursSinceAdult: Double = 0

    // MARK: Private

    private let evolutionEngine: EvolutionEngine
    private let env: AppEnvironment
    private var timer: Timer?
    private var lastTickDate: Date = Date()
    private var careMistakesThisStage: Int = 0
    private var lastDailySignalDate: Date = Date()
    private var gameDayAccumulator: Double = 0   // accumulated game-minutes since last daily tick

    // MARK: Init

    init(env: AppEnvironment) {
        self.env = env
        self.evolutionEngine = EvolutionEngine(
            evolutionConfig: env.evolutionConfig,
            battleConfig: env.battleConfig
        )
        self.creature = Creature()
    }

    // MARK: - Lifecycle

    func startGame() {
        phase = .living
        lastTickDate = Date()
        startTimer()
    }

    func acknowledgePermissions() {
        startGame()
    }

    // MARK: - Care Actions

    func perform(_ action: CareAction) {
        guard case .living = phase, creature.isAlive else { return }
        CareEngine.perform(action, on: &creature)
        if let call = pendingCall, callAnswers(action: action, call: call) {
            pendingCall = nil
        }
    }

    // MARK: - Debug: manual ticks

    /// Force one full game-day of signal application (debug panel use only).
    func debugForceDailyTick() {
        let signals = env.behaviorSource.currentSignals
        evolutionEngine.applyDailySignals(to: &creature, signals: signals)
    }

    /// Force a stage evaluation right now (debug panel use only).
    func debugForceStageCheck() {
        checkStageTransition()
    }

    /// Hatch a new creature from the waiting egg.
    func hatchEgg() {
        guard case .eggWaiting(let egg) = phase else { return }
        let boon = min(lineage.totalBoon + egg.kind.boon, env.evolutionConfig.traitedEgg.boonCap)
        var newCreature = Creature(lineageID: lineage.id, boon: boon)
        newCreature.birthDate = Date()
        creature = newCreature
        careMistakesThisStage = 0
        awakeHoursSinceAdult = 0
        pendingCall = nil
        phase = .living
        startTimer()
    }

    // MARK: - Timer Loop

    private func startTimer() {
        timer?.invalidate()
        lastTickDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard case .living = phase, creature.isAlive else { return }

        let now = Date()
        let realSecondsElapsed = now.timeIntervalSince(lastTickDate)
        lastTickDate = now

        // Convert real seconds → game minutes using time scale
        let gameMinutesElapsed = realSecondsElapsed * debugTimeScale / 60.0

        // Need decay + call detection
        let callWindowMinutes = env.evolutionConfig.careMistakes.callWindowMinutes
        if let newCall = CareEngine.tick(
            creature: &creature,
            pendingCall: pendingCall,
            gameMinutesElapsed: gameMinutesElapsed,
            callWindowMinutes: callWindowMinutes
        ) {
            pendingCall = newCall
        }

        // Check if active call has expired (unanswered) → care mistake
        if let call = pendingCall, call.isExpired {
            pendingCall = nil
            careMistakesThisStage += 1
            creature.lifetimeCareMistakes += 1
            env.behaviorSource.recordCareMistake()
        }

        // Accumulate game time for daily signal tick
        gameDayAccumulator += gameMinutesElapsed
        let gameMinutesPerDay = 1440.0
        if gameDayAccumulator >= gameMinutesPerDay {
            gameDayAccumulator -= gameMinutesPerDay
            let signals = env.behaviorSource.currentSignals
            evolutionEngine.applyDailySignals(to: &creature, signals: signals)
        }

        // Awake hours accumulate (simplified: assume always awake in prototype)
        if creature.stage == .adult || creature.stage == .apex {
            awakeHoursSinceAdult += gameMinutesElapsed / 60.0
        }

        // Check stage transition
        checkStageTransition()
    }

    private func checkStageTransition() {
        guard creature.isAlive else { return }
        let event = evolutionEngine.evaluateStage(
            creature: &creature,
            careMistakesThisStage: careMistakesThisStage,
            awakeHoursSinceAdult: awakeHoursSinceAdult
        )
        guard let event = event else { return }

        lastEvolutionEvent = event
        switch event {
        case .stagePromotion(_, let to, _):
            if to == .adult {
                // Reset mistakes and awake hours on adult transition
                careMistakesThisStage = 0
                awakeHoursSinceAdult = 0
                env.behaviorSource.resetCareMistakes()
            }
        case .earlyDeath(let egg), .naturalDeath(let egg):
            timer?.invalidate()
            timer = nil
            lineage.record(creature: creature, boonContributed: egg.kind.boon)
            phase = .eggWaiting(egg)
        }
    }

    // MARK: - Private Helpers

    private func callAnswers(action: CareAction, call: NeedCall) -> Bool {
        switch (action, call.need) {
        case (.feed,  .hunger):    return true
        case (.rest,  .energy):    return true
        case (.clean, .hygiene):   return true
        case (.play,  .happiness): return true
        default: return false
        }
    }

    // MARK: - Computed helpers for views

    var trendingBranch: Branch {
        evolutionEngine.selectBranch(traits: creature.traits, careMistakes: careMistakesThisStage)
    }

    var neglect: Double {
        creature.traits.neglect(careMistakes: careMistakesThisStage)
    }

    var stageCareMistakes: Int { careMistakesThisStage }
}
