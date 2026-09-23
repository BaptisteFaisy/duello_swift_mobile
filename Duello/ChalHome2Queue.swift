//
//  ChalHome2Queue.swift
//  Duello
//
//  Lot 11-B — accueil des défis : la file d'attente et le lancement d'un défi.
//
//  Fichier source Expo porté (champs, seuils et enchaînements repris mot pour
//  mot) :
//    - src/screens/ChallengesScreen.tsx
//        · `inviteMember` (lignes 1789-1840) : construit la `QueueRequest` puis
//          appelle `queue.invite(...)` avec les cibles choisies ;
//        · `joinScheduledClassChallenge` (lignes 1849-1894) : appelle
//          `queue.enter(...)` pour une salle planifiée ;
//        · `MAX_CHALLENGE_EXERCISES` (utils/matchmaking.ts, ligne 102) = 3.
//
//  Réutilise sans les recréer : `ChalQueueController` (états et enchaînements),
//  `QueueRequest`, `ChalInviteTarget`, la carte de recherche `ChalRunSearchingCard`
//  et la carte d'adversaire `ChalRunOpponentCard` (lot 11-C, `ChalRunReveal.swift`),
//  `DuelloPrimaryButton` et `Theme`. Les cartes d'attente et d'adversaire trouvé
//  ne sont **pas** redupliquées : elles sont seulement pilotées ici.
//
//  Écart assumé : la source envoie `MAX_CHALLENGE_EXERCISES = 3` ; le portage
//  existant (`ChallengesView.swift`) en envoie 1. Cette constante suit la source.
//
//  Hors périmètre (signalé dans la réponse) : le quota de corrections
//  (`useCorrectionQuota`), la salle planifiée (`scheduledChallengeId` /
//  `scheduledStartAt`, absents de `QueueRequest`) et la cote de matière
//  (`useSubjectElo`) ne sont pas portés : l'appelant fournit la cote.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Constantes et fabriques du lancement d'un défi (`inviteMember`,
/// `joinScheduledClassChallenge`).
enum ChalHome2Launch {
    /// Matière unique des défis (`getChallengeTrackSubjects` filtre sur maths).
    static let challengeSubjectName = "Mathématiques"
    /// Filières pourvues de banques réelles côté serveur.
    static let supportedTracks: Set<String> = ["ECG", "MPSI"]
    /// Nombre maximal d'exercices d'un défi (`MAX_CHALLENGE_EXERCISES`).
    static let maxExercisesPerChallenge = 3
    /// Cote par défaut quand le compte n'en publie pas encore.
    static let initialElo = 1000

    /// Vrai quand la filière du compte ouvre les défis.
    static func canLaunch(profile: UserProfile) -> Bool {
        supportedTracks.contains(profile.track)
    }

    /// Construit la requête déposée dans la file (`queue.invite` / `queue.enter`).
    /// `chapters` porte les clés de chapitres jouées, `pools` leurs exercices.
    static func request(
        profile: UserProfile,
        chapters: [String],
        pools: [String: [String]],
        startedExerciseIds: [String],
        subject: String = challengeSubjectName,
        elo: Int = initialElo
    ) -> QueueRequest {
        QueueRequest(
            userId: DuelloAPI.publicProfileId(email: profile.email),
            displayName: profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            prepName: profile.prepName.trimmingCharacters(in: .whitespacesAndNewlines),
            track: profile.track,
            year: profile.year,
            specialty: profile.specialty.isEmpty ? nil : profile.specialty,
            subject: subject,
            chapters: chapters,
            exercisePools: pools,
            startedExerciseIds: startedExerciseIds,
            allowStartedExercises: false,
            maxExercises: maxExercisesPerChallenge,
            elo: elo
        )
    }

    /// Cibles d'invitation : nom affiché et chapitres communs jouables
    /// (`chapters.filter { invitedChapterKeys.contains($0.key) }`).
    static func targets(
        members: [SocSocialProfile],
        chapters: [SocChallengeChapter],
        chapterKeys: [String]
    ) -> [ChalInviteTarget] {
        let keys = Set(chapterKeys)
        // Le filtre porte sur la clé complète du chapitre, comme la source.
        let names = chapters.filter { keys.contains($0.key) }.map(\.name)
        return members.map {
            ChalInviteTarget(id: $0.id, displayName: $0.displayName, chapterNames: names)
        }
    }
}

/// Surface de la file d'attente de l'onglet « Défis » : le bouton d'entrée au
/// repos, la carte de recherche pendant l'attente, la carte d'adversaire à
/// l'appariement. Elle ne fait qu'afficher l'état de `ChalQueueController`.
@MainActor
struct ChalHome2QueuePanel: View {
    @ObservedObject var queue: ChalQueueController
    var subject: String
    var durationMinutes: Int
    /// Faux quand le compte ne peut pas encore défier (quota, session expirée).
    var disabled: Bool = false
    /// Entrée dans la file (construction de la `QueueRequest` par l'appelant).
    var onEnter: () -> Void

    var body: some View {
        Group {
            switch queue.status {
            case .idle:
                // La source n'affiche **rien** au repos : l'entrée en file passe
                // par les boutons Défi-Exercice / Défi-Cours de
                // `ChallengeHomeActions` (qui ouvrent, dans Expo, le volet
                // d'invitation). Le portage fait retomber ces boutons sur la
                // file aléatoire — pas de bouton d'entrée séparé, il serait un
                // ajout visible (`Trouver un adversaire`).
                EmptyView()
            case .searching:
                ChalRunSearchingCard(search: search, onCancel: { queue.cancel() })
            case .matched:
                if let match = queue.match {
                    ChalRunOpponentCard(match: match)
                }
            }
        }
    }

    /// Instantané de la file pour la carte de recherche (`queue` de la source).
    private var search: ChalRunQueueSearch {
        ChalRunQueueSearch(
            scheduled: queue.mode == .scheduled,
            queued: queue.queued,
            waitedMs: queue.waitedMs,
            scheduledStartAt: queue.scheduledStartAt,
            offline: queue.offline,
            invitedName: queue.invitedName,
            subject: queue.match?.subject ?? subject,
            durationMinutes: queue.match?.durationMinutes ?? durationMinutes
        )
    }
}
