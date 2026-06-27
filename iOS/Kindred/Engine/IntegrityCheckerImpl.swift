import Foundation
import CryptoKit

/// Prototype integrity checker.
/// Uses an ephemeral in-memory symmetric key — replace with Secure Enclave
/// key generation in the production pass.
final class IntegrityCheckerImpl: IntegrityChecker, @unchecked Sendable {
    // PROTOTYPE: ephemeral key, not stored. Replace with SecureEnclave.P256.Signing.PrivateKey.
    private let key = SymmetricKey(size: .bits256)

    func sign(statBlock: StatBlock, creatureID: UUID) throws -> Data {
        let payload = payload(for: statBlock, creatureID: creatureID)
        let mac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        return Data(mac)
    }

    func verify(state: SignedCreatureState) -> IntegrityResult {
        let payload = payload(for: state.statBlock, creatureID: state.creatureID)
        let expected = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        guard Data(expected) == state.hmac else { return .signatureMismatch }
        return .valid
    }

    func checkClock(lastSavedDate: Date) -> IntegrityResult {
        let now = Date()
        let delta = now.timeIntervalSince(lastSavedDate)
        if delta < -60 {
            return .clockRollbackDetected(rollbackSeconds: abs(delta))
        }
        return .valid
    }

    func signSave(data: Data) throws -> Data {
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(mac)
    }

    func verifySave(data: Data, tag: Data) -> IntegrityResult {
        let expected = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(expected) == tag ? .valid : .signatureMismatch
    }

    // MARK: Private

    private func payload(for statBlock: StatBlock, creatureID: UUID) -> Data {
        let str = "\(creatureID):\(statBlock.hp):\(statBlock.attack):\(statBlock.defense):\(statBlock.speed):\(statBlock.stamina)"
        return Data(str.utf8)
    }
}
