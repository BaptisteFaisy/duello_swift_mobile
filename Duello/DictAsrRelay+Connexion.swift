//
//  DictAsrRelay+Connexion.swift
//  Duello
//
//  Résolution de la route WebSocket du relais ASR et attentes associées :
//  ouverture de la socket (`connectTimeout`) et fin de flux (`done` /
//  `finishTimeout`). Ces membres touchent l'état `internal` de `DictAsrRelay`
//  déclaré dans `DictAsrRelay.swift` (continuations et délai de connexion).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

extension DictAsrRelay {
    // MARK: Endpoint par moteur

    /// Route WebSocket du relais pour un moteur voulu — `realtimeAsrWebSocketUrl`.
    ///
    /// La source ne sert qu'une seule route vocale (`<endpoint>/asr`) : le relais
    /// y choisit lui-même Fun-ASR, Qwen-ASR puis Scribe v2. `kind` désigne donc
    /// le moteur *préféré* du client ; `DictEngineKind.device` n'emprunte pas le
    /// relais et rend `nil` (repli sur le moteur natif de l'appareil).
    static func endpoint(for kind: DictEngineKind, relayEndpoint: String) throws -> URL? {
        guard kind != .device else { return nil }
        guard let url = URL(string: try DictPolicy.realtimeAsrUrl(relayEndpoint)) else {
            throw DictError.invalidRelay
        }
        return url
    }

    /// Route WebSocket effective de la configuration.
    static func webSocketURL(for config: DictRelayConfig) throws -> URL {
        guard let url = try endpoint(for: config.kind, relayEndpoint: config.endpoint) else {
            throw DictError.invalidRelay
        }
        return url
    }

    // MARK: Attente de fin

    /// Attend la fin du relais (`done` ou délai de finalisation) — `stop()` async.
    func attendreFin() async {
        if finAtteinte { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            if finAtteinte { continuation.resume(); return }
            finContinuation = continuation
        }
    }

    // MARK: Connexion / fin (continuations)

    func attendreConnexion() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connexionContinuation = continuation
            connectTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.connectTimeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.signalerConnexion(erreur: DictError.engineUnavailable)
            }
        }
    }

    func signalerConnexion(erreur: Error?) {
        guard let continuation = connexionContinuation else { return }
        connexionContinuation = nil
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        if let erreur { continuation.resume(throwing: erreur) } else { continuation.resume() }
    }

    func signalerFin() {
        finAtteinte = true
        if let continuation = finContinuation {
            finContinuation = nil
            continuation.resume()
        }
    }
}
