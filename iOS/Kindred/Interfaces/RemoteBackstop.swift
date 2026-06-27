import Foundation

/// Result of a remote config fetch.
enum RemoteConfigResult: Sendable {
    case updated(evolutionConfig: Data?, battleConfig: Data?)
    case noChange
    case unavailable
}

/// Result of an async anti-cheat attestation.
enum AttestationResult: Sendable {
    case accepted
    case rejected(reason: String)
    case unavailable
}

/// Optional server seam — a no-op by default. The core loop never depends on this.
///
/// The Coolify server (if configured) may provide:
///   - Opt-in encrypted lineage backups
///   - Asynchronous anti-cheat attestation
///   - Remote evolution/battle config overrides (bundled local copy is always the fallback)
///
/// IMPORTANT: two players must be able to meet, battle, and use the roster with this seam
/// returning .unavailable for every call. Never put anything on the critical path here.
protocol RemoteBackstop: AnyObject, Sendable {
    /// Fetch updated config files, if available. Never blocks the UI.
    func fetchRemoteConfig() async -> RemoteConfigResult

    /// Asynchronously attest a signed receipt. Fire-and-forget; outcome is informational only.
    func attest(signedReceipt: Data) async -> AttestationResult

    /// Upload an encrypted lineage backup. Opt-in only; user must explicitly enable.
    func backupLineage(_ encryptedData: Data, creatureID: UUID) async throws

    /// Restore an encrypted lineage backup. Returns nil if unavailable.
    func restoreLineage(creatureID: UUID) async -> Data?
}

/// Default implementation: always unavailable. Used unless the user opts in and
/// the server is reachable. Never call this on the critical path.
final class NoOpRemoteBackstop: RemoteBackstop, @unchecked Sendable {
    func fetchRemoteConfig() async -> RemoteConfigResult { .unavailable }
    func attest(signedReceipt: Data) async -> AttestationResult { .unavailable }
    func backupLineage(_ encryptedData: Data, creatureID: UUID) async throws {}
    func restoreLineage(creatureID: UUID) async -> Data? { nil }
}
