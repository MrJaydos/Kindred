import Foundation
import SwiftUI

// MARK: - Game state

enum GamePhase {
    case permissionPriming
    case living          // creature is alive
    case eggWaiting(Egg) // creature just died, egg is ready to hatch
}

// MARK: - Supporting types

struct TransitionBanner: Equatable {
    let text: String
    let branch: Branch?
}

// MARK: - Tamer name generator

private let adjectives = ["Swift","Quiet","Bold","Grim","Wild","Calm","Stern","Dusk","Iron","Pale"]
private let nouns      = ["Walker","Keeper","Warden","Rover","Drifter","Seeker","Shadow","Ember","Stone","Spark"]

private func mockTamerName(for id: UUID) -> String {
    let hash = abs(id.hashValue)
    return "\(adjectives[hash % adjectives.count]) \(nouns[(hash / 10) % nouns.count])"
}

// MARK: - ViewModel

@MainActor
final class GameViewModel: ObservableObject {

    // MARK: Published state

    @Published private(set) var creature: Creature
    @Published private(set) var lineage: Lineage = Lineage()
    @Published private(set) var roster: Roster = Roster()
    @Published private(set) var pendingCall: NeedCall?
    @Published private(set) var phase: GamePhase = .permissionPriming
    @Published private(set) var lastEvolutionEvent: EvolutionEvent?
    @Published private(set) var isPairing: Bool = false
    @Published var showBattle: Bool = false
    @Published var activeBattle: BattleViewModel?

    // Stage transition banner — shown briefly in the UI on promotion
    @Published private(set) var transitionBanner: TransitionBanner? = nil

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
    private var gameDayAccumulator: Double = 0
    private(set) var gameDaysAlive: Double = 0   // game-time days since hatch (respects debugTimeScale)

    // MARK: Init

    init(env: AppEnvironment) {
        self.env = env
        self.evolutionEngine = EvolutionEngine(
            evolutionConfig: env.evolutionConfig,
            battleConfig: env.battleConfig
        )
        self.creature = Creature()
        self.roster   = loadRoster()
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

    /// Push game days past the natural-death threshold (debug panel use only).
    func debugForceDeath() {
        gameDaysAlive = env.evolutionConfig.lifespanDays.naturalMax + 1
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
        gameDaysAlive = 0
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

        // Accumulate game time
        let gameMinutesPerDay = 1440.0
        gameDayAccumulator += gameMinutesElapsed
        gameDaysAlive      += gameMinutesElapsed / gameMinutesPerDay
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
            gameDaysAlive: gameDaysAlive,
            careMistakesThisStage: careMistakesThisStage,
            awakeHoursSinceAdult: awakeHoursSinceAdult
        )
        guard let event = event else { return }

        lastEvolutionEvent = event
        switch event {
        case .stagePromotion(_, let to, let branch):
            if to == .adult {
                careMistakesThisStage = 0
                awakeHoursSinceAdult  = 0
                env.behaviorSource.resetCareMistakes()
            }
            showTransitionBanner(stage: to, branch: branch)
        case .earlyDeath(let egg), .naturalDeath(let egg):
            timer?.invalidate()
            timer = nil
            lineage.record(creature: creature, boonContributed: egg.kind.boon)
            phase = .eggWaiting(egg)
        }
    }

    private func showTransitionBanner(stage: Stage, branch: Branch?) {
        let text: String
        switch stage {
        case .blob:     text = "It hatched."
        case .juvenile: text = "Something is changing."
        case .adult:    text = "It has become itself."
        case .apex:     text = "Something rare. Hard-earned."
        case .egg:      return
        }
        transitionBanner = TransitionBanner(text: text, branch: branch)
        Task {
            try? await Task.sleep(for: .seconds(3))
            self.transitionBanner = nil
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

    // MARK: - Proximity bump

    func initiateBump() {
        guard case .living = phase, creature.isAlive, !isPairing else { return }
        Task { await doBump() }
    }

    private func doBump() async {
        isPairing = true
        defer { isPairing = false }

        let signedState: SignedCreatureState
        do {
            let tag = try env.integrityChecker.sign(statBlock: creature.stats, creatureID: creature.id)
            signedState = SignedCreatureState(
                statBlock: creature.stats,
                branch: creature.branch ?? .drifter,
                stage: creature.stage,
                lineageBoon: lineage.totalBoon,
                creatureID: creature.id,
                hmac: tag
            )
        } catch {
            return
        }

        let result: (opponentState: SignedCreatureState, seed: UInt64)
        do {
            result = try await env.peerTransport.pairViaTap(localState: signedState)
        } catch {
            return
        }

        let battleVM = BattleViewModel(
            playerStats: creature.stats,
            opponentState: result.opponentState,
            seed: result.seed,
            config: env.battleConfig,
            transport: env.peerTransport
        )
        battleVM.onComplete = { [weak self] won, voided in
            self?.onBattleComplete(won: won, voided: voided, opponentState: result.opponentState)
        }
        activeBattle = battleVM
        showBattle   = true
        battleVM.start()
    }

    func onBattleComplete(won: Bool?, voided: Bool, opponentState: SignedCreatureState) {
        showBattle   = false
        activeBattle = nil
        env.peerTransport.disconnect()
        guard !voided, let won else { return }

        // Update creature record
        if won { creature.wins  += 1 } else { creature.losses += 1 }

        // Imprint nudge (spec §7, capped per daily allowance)
        let nudge = env.battleConfig.outcome
        if won {
            let dominant = [creature.traits.vigor, creature.traits.nocturnality,
                            creature.traits.bond,  creature.traits.discipline].max() ?? 50
            if dominant == creature.traits.vigor        { creature.traits.vigor        = min(100, creature.traits.vigor        + nudge.winnerAxisNudge) }
            else if dominant == creature.traits.bond    { creature.traits.bond         = min(100, creature.traits.bond         + nudge.winnerAxisNudge) }
            else if dominant == creature.traits.discipline { creature.traits.discipline = min(100, creature.traits.discipline   + nudge.winnerAxisNudge) }
            else                                        { creature.traits.nocturnality = min(100, creature.traits.nocturnality  + nudge.winnerAxisNudge) }
        } else {
            creature.traits.discipline = min(100, creature.traits.discipline + nudge.loserDefenseNudge)
        }

        // Update roster
        let snapshot = CreatureSnapshot(
            stage: opponentState.stage,
            branch: opponentState.branch == .drifter ? nil : opponentState.branch,
            traits: TraitVector(),
            lineageBoon: opponentState.lineageBoon,
            capturedAt: Date()
        )
        let tamerID = opponentState.creatureID
        var tamer = roster.tamers.first(where: { $0.id == tamerID }) ?? MetTamer(
            id: tamerID,
            displayName: mockTamerName(for: tamerID),
            lastSeenCreature: snapshot,
            lineageEntries: [],
            winsAgainst: 0,
            lossesAgainst: 0,
            firstMetAt: Date(),
            lastMetAt: Date()
        )
        tamer.lastSeenCreature = snapshot
        tamer.lastMetAt = Date()
        if won { tamer.winsAgainst += 1 } else { tamer.lossesAgainst += 1 }
        roster.upsert(tamer: tamer)
        saveRoster()
    }

    // MARK: - Roster persistence

    private func saveRoster() {
        if let data = try? JSONEncoder().encode(roster) {
            UserDefaults.standard.set(data, forKey: "kindred.roster")
        }
    }

    private func loadRoster() -> Roster {
        guard let data = UserDefaults.standard.data(forKey: "kindred.roster"),
              let saved = try? JSONDecoder().decode(Roster.self, from: data) else {
            return Roster()
        }
        return saved
    }

    // MARK: - Computed helpers for views

    var trendingBranch: Branch {
        evolutionEngine.selectBranch(traits: creature.traits, careMistakes: careMistakesThisStage)
    }

    var neglect: Double {
        creature.traits.neglect(careMistakes: careMistakesThisStage)
    }

    var stageCareMistakes: Int { careMistakesThisStage }

    /// 0 = fine, 1 = caution (≥ 4 mistakes), 2 = danger (≥ 8 mistakes)
    var careWarningLevel: Int {
        if careMistakesThisStage >= 8  { return 2 }
        if careMistakesThisStage >= 4  { return 1 }
        return 0
    }
}
