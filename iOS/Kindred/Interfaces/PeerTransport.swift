import Foundation

/// A snapshot of creature state exchanged at pairing time.
/// Signed by IntegrityChecker before transmission; verified by the recipient.
struct SignedCreatureState: Codable, Sendable {
    let statBlock: StatBlock
    let branch: Branch
    let stage: Stage
    let lineageBoon: Int
    let creatureID: UUID
    let hmac: Data  // Signed by Secure Enclave / Keystore stub
}

/// Per-exchange input summary sent in lockstep over BLE.
/// Both devices exchange these, then run the resolver independently.
struct ExchangeInputSummary: Codable, Sendable {
    let tapCount: Int          // clamped to maxMash
    let timingOffsetMs: Int    // ms from center of sweet spot (signed)
    let guardOffsetMs: Int     // ms from center of guard window (signed)
    let exchangeIndex: Int
}

/// Result of a paired battle session.
struct BattleOutcome: Sendable {
    let didWin: Bool
    let exchangeCount: Int
    let voided: Bool    // true if a state-hash mismatch was detected
    let opponentState: SignedCreatureState
}

/// Peer discovery and pairing state.
enum PeerState: Sendable {
    case idle
    case discovering
    case pairing
    case paired(peerID: UUID)
    case disconnected
}

/// Transport layer for proximity-based creature battles.
///
/// Real implementation: NFC tap to exchange seeds + signed state,
/// then BLE for lockstep per-exchange input summaries.
/// Uses open BLE/NFC standards intentionally so iOS and Android can interoperate.
///
/// Mock implementation: simulates the entire exchange on one device.
@MainActor
protocol PeerTransport: AnyObject {
    var peerState: PeerState { get }

    /// Begin advertising / scanning for nearby tamers.
    func discover() async throws

    /// Initiate pairing (NFC tap in real impl; button press in mock).
    /// Returns the opponent's signed creature state and shared battle seed.
    func pairViaTap(localState: SignedCreatureState) async throws -> (opponentState: SignedCreatureState, seed: UInt64)

    /// Send this exchange's input summary to the peer.
    func send(input: ExchangeInputSummary) async throws

    /// Receive the peer's input summary for the current exchange.
    func receive() async throws -> ExchangeInputSummary

    /// Tear down the connection cleanly.
    func disconnect()
}
