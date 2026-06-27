import Foundation
import SwiftUI

// MARK: - Phase

enum BattlePhase: Equatable {
    case countdown(Int)
    case inputWindow(exchange: Int)
    case resolving
    case showingResult(exchange: Int, playerDmgReceived: Double, opponentDmgReceived: Double)
    case finished

    static func == (lhs: BattlePhase, rhs: BattlePhase) -> Bool {
        switch (lhs, rhs) {
        case (.countdown(let a),      .countdown(let b)):      return a == b
        case (.inputWindow(let a),    .inputWindow(let b)):    return a == b
        case (.resolving,             .resolving):             return true
        case (.showingResult(let a, _, _), .showingResult(let b, _, _)): return a == b
        case (.finished,              .finished):              return true
        default: return false
        }
    }
}

// MARK: - BattleViewModel

@MainActor
final class BattleViewModel: ObservableObject {

    // MARK: Published

    @Published private(set) var phase: BattlePhase = .countdown(3)
    @Published private(set) var playerHP: Double
    @Published private(set) var opponentHP: Double
    @Published private(set) var playerStamina: Double
    @Published private(set) var opponentStamina: Double
    @Published private(set) var markerPosition: Double = 0   // 0–1 left→right
    @Published private(set) var sweetSpotCenter: Double = 0.5
    @Published private(set) var sweetSpotHalfWidth: Double = 0.15
    @Published private(set) var playerTapCount: Int = 0
    @Published private(set) var hasTimingTapped: Bool = false
    @Published private(set) var windowTimeRemaining: Double = 0
    @Published private(set) var isVoided: Bool = false
    @Published private(set) var exchanges: [ExchangeRecord] = []

    // MARK: Immutable identity

    let playerStats: StatBlock
    let opponentState: SignedCreatureState
    let seed: UInt64

    var playerMaxHP:   Double { playerStats.hp   * config.structure.hpPoolMultiplier }
    var opponentMaxHP: Double { opponentStats.hp * config.structure.hpPoolMultiplier }
    var totalExchanges: Int   { config.structure.exchanges }
    var currentExchangeIndex: Int { exchanges.count }

    var playerWon: Bool? {
        guard case .finished = phase else { return nil }
        if isVoided { return nil }
        if playerHP <= 0 && opponentHP <= 0 {
            return playerStats.speed >= opponentStats.speed
        }
        if playerHP <= 0 { return false }
        if opponentHP <= 0 { return true }
        let pPct = playerHP / playerMaxHP
        let oPct = opponentHP / opponentMaxHP
        if abs(pPct - oPct) < 0.001 { return playerStats.speed >= opponentStats.speed }
        return pPct > oPct
    }

    /// Called by GameViewModel once the battle finishes.
    var onComplete: ((Bool?, Bool) -> Void)?

    // MARK: Private

    private var opponentStats: StatBlock { opponentState.statBlock }
    private let resolver: BattleResolver
    private let transport: any PeerTransport
    private let config: BattleConfig
    private var markerTimer: Timer?
    private var timingTapOffsetMs: Int = 99999   // default = complete miss
    private var windowOpenDate: Date?
    private var battleTask: Task<Void, Never>?

    // MARK: Init

    init(
        playerStats: StatBlock,
        opponentState: SignedCreatureState,
        seed: UInt64,
        config: BattleConfig,
        transport: any PeerTransport
    ) {
        self.playerStats    = playerStats
        self.opponentState  = opponentState
        self.seed           = seed
        self.config         = config
        self.transport      = transport
        self.resolver       = BattleResolver(config: config)
        self.playerHP       = playerStats.hp   * config.structure.hpPoolMultiplier
        self.opponentHP     = opponentState.statBlock.hp * config.structure.hpPoolMultiplier
        self.playerStamina  = playerStats.stamina
        self.opponentStamina = opponentState.statBlock.stamina
    }

    // MARK: - Start

    func start() {
        battleTask = Task { await runBattle() }
    }

    func cancel() {
        battleTask?.cancel()
        markerTimer?.invalidate()
    }

    // MARK: - Player input

    func handleTimingTap() {
        guard case .inputWindow = phase, !hasTimingTapped, let openDate = windowOpenDate else { return }
        let elapsedMs = Int(Date().timeIntervalSince(openDate) * 1000)
        let sweetMs   = Int(sweetSpotCenter * Double(config.structure.windowMs))
        timingTapOffsetMs = elapsedMs - sweetMs
        hasTimingTapped = true
    }

    func handleMashTap() {
        guard case .inputWindow = phase else { return }
        if playerTapCount < config.skill.maxMash {
            playerTapCount += 1
        }
    }

    // MARK: - Battle loop

    private func runBattle() async {
        for i in stride(from: 3, through: 1, by: -1) {
            phase = .countdown(i)
            try? await Task.sleep(for: .seconds(1))
        }

        for i in 0..<totalExchanges {
            guard !Task.isCancelled else { return }
            guard playerHP > 0 && opponentHP > 0 else { break }
            await runExchange(index: i)
            guard playerHP > 0 && opponentHP > 0 else { break }
            try? await Task.sleep(for: .milliseconds(900))
        }

        phase = .finished
        onComplete?(playerWon, isVoided)
    }

    private func runExchange(index: Int) async {
        // Seed the sweet spot position deterministically from battle seed + exchange index
        var rng = SeededRandom(seed: seed &+ UInt64(index) &* 0x9E3779B97F4A7C15)
        sweetSpotCenter = rng.nextDouble(in: 0.2...0.8)
        let sweetSpotMs  = config.skill.sweetSpotBaseMs + playerStats.speed * config.skill.sweetSpotPerSpeedMs
        sweetSpotHalfWidth = (sweetSpotMs / Double(config.structure.windowMs)) / 2

        // Reset exchange state
        playerTapCount    = 0
        hasTimingTapped   = false
        timingTapOffsetMs = config.structure.windowMs   // default miss
        markerPosition    = 0
        windowOpenDate    = Date()
        windowTimeRemaining = Double(config.structure.windowMs) / 1000

        phase = .inputWindow(exchange: index)
        startMarkerAnimation()

        // Wait the full window
        try? await Task.sleep(for: .milliseconds(config.structure.windowMs))
        stopMarkerAnimation()
        markerPosition = 1.0
        phase = .resolving

        // Opponent input from transport (mock generates it)
        let opponentInput: ExchangeInputSummary
        do {
            opponentInput = try await transport.receive()
        } catch {
            opponentInput = ExchangeInputSummary(tapCount: 5, timingOffsetMs: 200, guardOffsetMs: 0, exchangeIndex: index)
        }

        let playerInput = ExchangeInputSummary(
            tapCount: playerTapCount,
            timingOffsetMs: timingTapOffsetMs,
            guardOffsetMs: 0,
            exchangeIndex: index
        )

        try? await transport.send(input: playerInput)

        let result = resolver.resolveExchange(
            exchangeIndex: index,
            playerStats: playerStats,
            opponentStats: opponentStats,
            playerInput: playerInput,
            opponentInput: opponentInput,
            playerHP: playerHP,
            opponentHP: opponentHP,
            playerStamina: playerStamina,
            opponentStamina: opponentStamina
        )

        // State-hash check (real BLE impl would compare with peer; mock always agrees)
        let record = ExchangeRecord(
            exchangeIndex: index,
            playerInput: playerInput,
            opponentInput: opponentInput,
            playerHPAfter: result.playerHPAfter,
            opponentHPAfter: result.opponentHPAfter,
            stateHash: result.stateHash
        )
        exchanges.append(record)

        phase = .showingResult(
            exchange: index,
            playerDmgReceived: result.opponentDamageDealt,
            opponentDmgReceived: result.playerDamageDealt
        )

        withAnimation(.spring(duration: 0.4)) {
            playerHP        = result.playerHPAfter
            opponentHP      = result.opponentHPAfter
            playerStamina   = result.playerStaminaAfter
            opponentStamina = result.opponentStaminaAfter
        }
    }

    // MARK: - Marker animation (30 Hz)

    private func startMarkerAnimation() {
        let startDate      = Date()
        let totalDurationS = Double(config.structure.windowMs) / 1000.0

        markerTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(startDate)
                if elapsed >= totalDurationS {
                    self.markerPosition      = 1.0
                    self.windowTimeRemaining = 0
                    self.markerTimer?.invalidate()
                    self.markerTimer = nil
                } else {
                    self.markerPosition      = elapsed / totalDurationS
                    self.windowTimeRemaining = totalDurationS - elapsed
                }
            }
        }
    }

    private func stopMarkerAnimation() {
        markerTimer?.invalidate()
        markerTimer = nil
    }
}
