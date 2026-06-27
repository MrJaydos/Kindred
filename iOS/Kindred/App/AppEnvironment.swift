import Foundation

/// Central wiring point. Swap mock ↔ real by changing this one object.
/// All engines and views receive their dependencies from here — no global singletons.
@MainActor
final class AppEnvironment: ObservableObject {
    let behaviorSource: any BehaviorSource
    let peerTransport: any PeerTransport
    let integrityChecker: any IntegrityChecker
    let remoteBackstop: any RemoteBackstop

    let evolutionConfig: EvolutionConfig
    let battleConfig: BattleConfig

    init(
        behaviorSource: any BehaviorSource,
        peerTransport: any PeerTransport,
        integrityChecker: any IntegrityChecker,
        remoteBackstop: any RemoteBackstop = NoOpRemoteBackstop(),
        evolutionConfig: EvolutionConfig,
        battleConfig: BattleConfig
    ) {
        self.behaviorSource = behaviorSource
        self.peerTransport = peerTransport
        self.integrityChecker = integrityChecker
        self.remoteBackstop = remoteBackstop
        self.evolutionConfig = evolutionConfig
        self.battleConfig = battleConfig
    }

    /// Builds the prototype environment: all mocks, configs loaded from bundle.
    static func makePrototype() -> AppEnvironment {
        let evolutionConfig = EvolutionConfig.loadFromBundle()
        let battleConfig = BattleConfig.loadFromBundle()
        let integrity = IntegrityCheckerImpl()
        return AppEnvironment(
            behaviorSource: MockBehaviorSource(),
            peerTransport: MockPeerTransport(),
            integrityChecker: integrity,
            evolutionConfig: evolutionConfig,
            battleConfig: battleConfig
        )
    }
}
