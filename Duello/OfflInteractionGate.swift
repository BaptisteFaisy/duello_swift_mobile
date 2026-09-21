//
//  OfflInteractionGate.swift
//  Duello
//
//  Portillon d'interaction : travail réseau requis ou non pendant une navigation.
//
//  Fichier source Expo porté : `src/content/contentInteractionGate.ts`
//  (`CONTENT_INTERACTION_IDLE_GRACE_MS`, `setContentInteractionActive`,
//  `waitForContentInteractionIdle`).
//
//  Règle pure : tant qu'une navigation (swipe) est active, les traitements de
//  banques qui alimentent le réseau de fond doivent attendre la fin du geste.
//  Le pager ne signale que les changements d'état du geste, jamais chaque
//  déplacement du doigt. Un délai de grâce court suit le relâchement, le temps
//  que la page d'arrivée soit montée.
//
//  Cible : iOS 16.
//
import Foundation

/// Règle pure : le réseau est-il requis par un état de téléchargement ?
enum OfflInteractionGate {
    /// `CONTENT_INTERACTION_IDLE_GRACE_MS`.
    static let idleGraceMs = OfflDownloadConfig.interactionIdleGraceMs

    /// `true` tant qu'une interaction impose de différer le travail de fond.
    static func shouldDeferBackgroundWork(interactionActive: Bool) -> Bool {
        interactionActive
    }

    /// `true` si l'état exige le réseau (contrôle ou téléchargement en cours).
    static func requiresNetwork(status: OfflContentDownloadStatus) -> Bool {
        switch status {
        case .checking, .downloading: return true
        case .idle, .complete, .error: return false
        }
    }
}

/// Machine à états du portillon (équivalent natif des variables de module).
final class OfflInteractionGateController {
    private let lock = NSLock()
    private var active = false
    private var releaseTask: Task<Void, Never>?
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// `setContentInteractionActive`.
    func setActive(_ value: Bool) {
        lock.lock()
        if value {
            releaseTask?.cancel()
            releaseTask = nil
            guard !active else { lock.unlock(); return }
            active = true
            lock.unlock()
            return
        }
        guard active, releaseTask == nil else { lock.unlock(); return }
        lock.unlock()
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(OfflInteractionGate.idleGraceMs) * 1_000_000)
            guard let self, !Task.isCancelled else { return }
            self.release()
        }
        lock.lock()
        releaseTask = task
        lock.unlock()
    }

    /// `waitForContentInteractionIdle` : attend la fin du swipe avant de reprendre.
    func waitForIdle() async {
        while isActive {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                lock.lock()
                if !active {
                    lock.unlock()
                    continuation.resume()
                    return
                }
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }

    private var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return active
    }

    private func release() {
        lock.lock()
        releaseTask = nil
        active = false
        let pending = waiters
        waiters.removeAll()
        lock.unlock()
        for continuation in pending { continuation.resume() }
    }
}
