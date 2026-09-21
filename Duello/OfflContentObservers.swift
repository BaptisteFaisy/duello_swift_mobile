//
//  OfflContentObservers.swift
//  Duello
//
//  Modèles observables du contenu hors ligne.
//
//  Fichiers source Expo portés :
//   - `src/hooks/useOfflineContentCache.ts` et
//     `src/hooks/offlineContentCacheTypes.ts` : le cache HTTP complet est propre
//     à la PWA ; le socle natif reste embarqué, l'état est donc « unsupported » ;
//   - `src/hooks/useContentRevision.ts` : révision du contenu servi séparément,
//     à observer dans toute vue qui lit une banque.
//
//  Les mises à jour de `@Published` sont ramenées sur le fil principal.
//
//  Cible : iOS 16.
//
import Combine
import Foundation

/// État du cache hors connexion (natif : non pris en charge, socle embarqué).
final class OfflOfflineCacheModel: ObservableObject {
    @Published private(set) var state: OfflOfflineCacheState = .unsupported

    /// `start` : le cache HTTP complet de la PWA n'a pas d'équivalent natif.
    func start() async {
        state = .unsupported
    }

    /// `refresh` : conserve l'état « unsupported ».
    func refresh() async {
        state = .unsupported
    }
}

/// Révision observable du registre de contenu (`useContentRevision`).
final class OfflContentRevisionObserver: ObservableObject {
    @Published private(set) var revision: Int

    private var unsubscribe: (() -> Void)?

    init(enabled: Bool = true) {
        revision = OfflSync.contentRevision
        guard enabled else { return }
        unsubscribe = OfflSync.subscribeToContent { [weak self] in
            let value = OfflSync.contentRevision
            DispatchQueue.main.async { self?.revision = value }
        }
    }

    deinit {
        unsubscribe?()
    }
}
