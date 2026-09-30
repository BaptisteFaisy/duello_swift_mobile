//
//  SubjVeryHardAchievers.swift
//  Duello
//
//  Cache partagé des réussites « très difficiles » (niveaux 5 et 6) : la
//  pastille de premier réussisseur des fiches d'entraînement (préfixe `Subj`).
//
//  Fichiers source Expo portés :
//    - `src/screens/SubjectsScreen.tsx` (`:4663-4774`) : `veryHardAchievements`
//      alimenté par `fetchVeryHardExerciseAchievements`, rafraîchi tant que
//      l'écran est actif ;
//    - `src/utils/socialApi.ts` (`:841`) : `fetchVeryHardExerciseAchievements`
//      (lots de 40, plafond 200), déjà porté par `SocialApiProfileExtras`.
//
//  La liste des réussites reste une donnée **servie** : hors ligne, le cache
//  demeure vide et la carte retombe sur la réussite locale optimiste
//  (`achieversFor` de `TrainIntItems+Prereq.swift`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Réussites « très difficiles » par exercice (`veryHardAchievements`).
///
/// Une seule instance partagée : la liste est servie à toutes les fiches d'un
/// chapitre, et les identifiants déjà demandés ne relancent pas l'appel — le
/// rafraîchissement périodique de la source n'est pas repris, une fiche n'étant
/// pas un écran de premier plan permanent.
final class SubjVeryHardAchievers: ObservableObject {
    /// Instance partagée du catalogue (`veryHardAchievements`).
    static let shared = SubjVeryHardAchievers()

    /// Identités publiques servies, par identifiant d'exercice.
    @Published private(set) var byItemId: [String: [SubjItemAchiever]] = [:]

    /// Identifiants déjà demandés : une même fiche ne relance pas l'appel.
    private var requested: Set<String> = []
    /// Un seul appel en vol à la fois, comme le rafraîchissement périodique RN.
    private var inFlight = false

    private init() {}

    /// Demande les réussites des exercices pas encore interrogés. Sans effet
    /// quand rien n'est nouveau ou qu'un appel est déjà en cours ; les erreurs
    /// réseau sont avalées, les cartes restant utilisables hors ligne.
    func ensureLoaded(exerciseIds: [String], token: String?) {
        let wanted = exerciseIds.filter { !$0.isEmpty && !requested.contains($0) }
        guard !wanted.isEmpty, !inFlight else { return }
        wanted.forEach { requested.insert($0) }
        inFlight = true
        Task { @MainActor [weak self] in
            do {
                let fetched = try await SocialApiProfileExtras.fetchVeryHardExerciseAchievements(
                    exerciseIds: wanted, token: token
                )
                guard let self else { return }
                self.inFlight = false
                guard !fetched.isEmpty else { return }
                var next = self.byItemId
                for (itemId, list) in fetched {
                    next[itemId] = list.map { SubjItemAchiever($0) }
                }
                self.byItemId = next
            } catch {
                guard let self else { return }
                self.inFlight = false
                // Échec réseau : une nouvelle tentative reste possible au
                // prochain rendu (hors ligne, les cartes retombent sur la
                // réussite locale optimiste).
                wanted.forEach { self.requested.remove($0) }
            }
        }
    }

    /// Premier profil publié d'un exercice (`achievers[0]`).
    func firstAchiever(for itemId: String) -> SubjItemAchiever? {
        byItemId[itemId]?.first
    }
}
