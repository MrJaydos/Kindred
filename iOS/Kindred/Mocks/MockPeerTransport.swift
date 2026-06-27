import Foundation

/// Simulates the full proximity-bump + lockstep battle flow on one device.
/// Drop-in for real NFC + BLE — no game-logic changes needed when the real transport arrives.
@MainActor
final class MockPeerTransport: PeerTransport {
    private(set) var peerState: PeerState = .idle

    /// AI quality for the simulated opponent's inputs (0 = worst, 1 = perfect timing).
    var opponentSkillLevel: Double = 0.5

    func discover() async throws {
        peerState = .discovering
        try await Task.sleep(for: .milliseconds(800))
        peerState = .idle
    }

    func pairViaTap(localState: SignedCreatureState) async throws -> (opponentState: SignedCreatureState, seed: UInt64) {
        peerState = .pairing
        try await Task.sleep(for: .milliseconds(600))

        let opponentID = UUID()
        let opponentStats = StatBlock(hp: 52, attack: 48, defense: 50, speed: 54, stamina: 50)
        // Opponent HMAC is left empty in the mock — integrity verification is skipped for simulated opponents
        let opponentState = SignedCreatureState(
            statBlock: opponentStats,
            branch: .drifter,
            stage: .adult,
            lineageBoon: 0,
            creatureID: opponentID,
            hmac: Data()
        )

        // Shared seed = hash of both contributions (simulated here as a random value)
        let seed = UInt64.random(in: .min ... .max)
        peerState = .paired(peerID: opponentID)
        return (opponentState, seed)
    }

    func send(input: ExchangeInputSummary) async throws {
        // In the mock, send is a no-op — we generate the opponent's input in receive()
    }

    func receive() async throws -> ExchangeInputSummary {
        try await Task.sleep(for: .milliseconds(50))

        // Simulate opponent input quality based on opponentSkillLevel
        let timingOffset = Int(Double.random(in: -200...200) * (1 - opponentSkillLevel))
        let guardOffset  = Int(Double.random(in: -200...200) * (1 - opponentSkillLevel))
        let taps = Int(Double.random(in: 4...12) * opponentSkillLevel)

        return ExchangeInputSummary(
            tapCount: taps,
            timingOffsetMs: timingOffset,
            guardOffsetMs: guardOffset,
            exchangeIndex: 0  // BattleResolver sets the real index
        )
    }

    func disconnect() {
        peerState = .idle
    }
}
