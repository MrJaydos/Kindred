import Foundation
import CryptoKit

/// Outcome of a save-state verification.
enum IntegrityResult: Sendable {
    case valid
    case signatureMismatch
    case clockRollbackDetected(rollbackSeconds: Double)
    case stateTampered
}

/// Anti-cheat seam. All methods are synchronous and on-device.
///
/// Real implementation: HMAC key stored in iOS Secure Enclave / Android Keystore.
/// Prototype: uses CryptoKit HMAC with an in-memory symmetric key (clearly marked).
protocol IntegrityChecker: AnyObject, Sendable {
    /// Sign a creature stat block for transmission at battle pairing.
    /// Returns the HMAC tag to embed in SignedCreatureState.
    func sign(statBlock: StatBlock, creatureID: UUID) throws -> Data

    /// Verify a received SignedCreatureState's HMAC.
    func verify(state: SignedCreatureState) -> IntegrityResult

    /// Check for monotonic clock violations (time-travel / rollback).
    /// Pass the last-saved timestamp; returns .valid or .clockRollbackDetected.
    func checkClock(lastSavedDate: Date) -> IntegrityResult

    /// Sign the full save-state blob. Returns the HMAC tag; store alongside the save.
    func signSave(data: Data) throws -> Data

    /// Verify a save-state blob against its stored tag.
    func verifySave(data: Data, tag: Data) -> IntegrityResult
}
