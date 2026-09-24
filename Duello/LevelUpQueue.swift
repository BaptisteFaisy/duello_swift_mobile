//
//  LevelUpQueue.swift
//  Duello
//
//  File des paliers franchis par le compte actif — unité U5 « Montée de niveau ».
//
//  Fichier source Expo porté (sémantique et libellés repris) :
//    - src/hooks/useLevelUpQueue.ts   (`mergeQueuedLevels`, `readLocalActivityXp`,
//                                      `useLevelUpQueue`)
//
//  Doctrine « seam honnête » : côté Expo, le hook lit et surveille directement
//  `AccountStorage` (`readLocalAccountStorageItems` + `subscribeToAccountStorage`
//  sur la clé `ACTIVITY_STORAGE_KEYS.activity`). L'app Swift n'a pas de magasin
//  clé/valeur asynchrone équivalent : `ProgressStore` (`ObservableObject`,
//  `@Published totalXp`) est l'autorité XP en mémoire et publie déjà chaque
//  écriture (`ProgressStore+Training.creditXp`). La couture est donc explicite —
//  `LevelUpXpSource` expose l'observation des totaux, et `ProgressStore` s'y
//  conforme par une extension (aucun fichier existant modifié).
//
//  Réductions assumées (2026-09-24) :
//    - Le hook relit le stockage local à chaque écriture ; ici le flux `@Published`
//      fournit la valeur après écriture. Une lecture qui échoue côté Expo
//      (`nextXp === undefined`) est conservée par le type `Double?` : `nil` est
//      ignoré, sans célébrer ni avancer le total observé. `ProgressStore` ne
//      produisant jamais `nil`, cette branche reste défensive.
//    - La sérialisation des relectures (`pendingReload`) n'a pas d'équivalent :
//      `objectWillChange` est observé sur le fil principal et le total est relu
//      au tour suivant de la boucle principale, sans course.
//    - `readLocalActivityXp` renvoie `undefined` en cas d'échec de lecture ; le
//      contrat `Double?` le représente (`nil`), sans lever.
//
//  `crossedXpLevels` n'est PAS réimplémenté ici : la couture est
//  `ChartXpLevelProgress.crossedLevels` (`ChartXpSeries.swift:133`).
//
//  Cible : iOS 16, SwiftUI + Combine + Foundation ; aucune dépendance externe.
//
import Combine
import Foundation

/// `mergeQueuedLevels` de `useLevelUpQueue.ts` : ajoute les paliers encore
/// jamais vus, sans doublon ni réordonnancement.
func mergeQueuedLevels(_ current: [Int], _ additions: [Int]) -> [Int] {
    let unseen = additions.filter { !current.contains($0) }
    return unseen.isEmpty ? current : current + unseen
}

/// Source d'XP observée par la file (l'`AccountStorage` du hook, réduit).
protocol LevelUpXpSource {
    /// Observe les totaux d'XP successifs ; `nil` = lecture impossible (à
    /// ignorer), comme `readLocalActivityXp` qui renvoie `undefined`. L'objet
    /// rendu annule l'observation.
    func observeXp(_ handler: @escaping (Double?) -> Void) -> AnyCancellable
}

/// `useLevelUpQueue` : suit les écritures XP du compte sans célébrer son
/// chargement initial, et expose le palier courant à célébrer.
final class LevelUpQueue: ObservableObject {
    /// Paliers franchis encore à célébrer, dans l'ordre (`queuedLevels`).
    @Published private(set) var queuedLevels: [Int] = []

    private var cancellables = Set<AnyCancellable>()
    /// Dernier total observé (`observedXp`) ; `nil` avant la première lecture.
    private var observedXp: Double?

    /// `queuedLevels[0]` : le palier affiché, `nil` quand la file est vide.
    var level: Int? { queuedLevels.first }

    /// `finishCurrent` : retire le palier courant, révélant le suivant.
    func finishCurrent() {
        queuedLevels = Array(queuedLevels.dropFirst())
    }

    /// Démarre l'observation d'une source (l'`useEffect` du hook). Réentrant :
    /// un nouvel appel remplace l'observation précédente.
    func start(observing source: LevelUpXpSource) {
        cancellables.removeAll()
        observedXp = nil
        source
            .observeXp { [weak self] nextXp in self?.apply(nextXp) }
            .store(in: &cancellables)
    }

    /// `reload` : ignore le chargement initial, célèbre les écritures suivantes.
    private func apply(_ nextXp: Double?) {
        guard let nextXp else { return }   // `nextXp === undefined`
        if let observedXp {
            let crossed = ChartXpLevelProgress.crossedLevels(
                previousXp: observedXp,
                currentXp: nextXp
            )
            queuedLevels = mergeQueuedLevels(queuedLevels, crossed)
        }
        observedXp = nextXp
    }
}

/// `AccountStorage` du hook réduit à l'autorité XP de l'app Swift : le total
/// publié par `ProgressStore` est la valeur observée.
extension ProgressStore: LevelUpXpSource {
    /// Le total courant est émis une fois à l'abonnement, comme le
    /// `CurrentValueSubject` de `$totalXp` : c'est le « chargement initial » que
    /// la file ignore. Ensuite, `objectWillChange` émet **avant** la mutation :
    /// le total est donc relu au tour suivant de la boucle principale.
    func observeXp(_ handler: @escaping (Double?) -> Void) -> AnyCancellable {
        handler(totalXp)
        return objectWillChange.sink { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async { handler(self.totalXp) }
        }
    }
}
