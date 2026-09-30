//
//  ChalIntChallengesTab+ClassInvite.swift
//  Duello
//
//  Lot S01 (vague 6) — extension de l'onglet « Défis » : volet « défi de classe »
//  et branchement de la salle planifiée.
//
//  Fichier source Expo porté : `src/screens/ChallengesScreen.tsx`
//  (`joinScheduledClassChallenge`, :1868-1911, et le volet `ClassInviteModal`,
//  :2989-3006). Le producteur de la file planifiée est `ChalScheduledRoom.join`
//  (S05) ; ce fichier porte l'appel d'écran et le volet.
//
//  Découpé ici pour la règle des 500 lignes (`ChalIntChallengesTab.swift`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

extension ChalIntChallengesTab {
    /// Contenu du volet « défi de classe » (`ClassInviteModal`, tsx:2989-3006) :
    /// « Rejoindre » remonte par `onJoinChallenge` (`joinClassChallenge`,
    /// tsx:1868-1911).
    var classInviteSheet: some View {
        ChalClassInviteSheet(
            organizerId: DuelloAPI.publicProfileId(email: session.profile.email),
            prepName: session.profile.prepName,
            className: session.profile.className,
            subject: ChalHome2Launch.challengeSubjectName,
            durationMinutes: ChalMatchmaking.challengeDurationMinutes,
            token: session.token,
            onJoinChallenge: { challenge, startsAt in
                Task { await joinClassChallenge(challenge, startsAt: startsAt) }
            },
            onClose: { classInviteOpen = false }
        )
    }

    /// `joinScheduledClassChallenge` (tsx:1868-1911) : hors de la salle
    /// d'attente ouverte, rien n'est déposé ; sinon le quota est vérifié, puis
    /// la file entre en mode planifié (`ChalScheduledRoom.join`, S05).
    func joinClassChallenge(_ challenge: ScheduledClassChallenge, startsAt: Double) async {
        classInviteOpen = false
        guard ChalHome2Launch.canLaunch(profile: session.profile) else {
            launchError = "Aucun exercice commun jouable n’est disponible pour ce défi."
            return
        }
        let pools = DuelloExerciseCatalog.queuePools(for: session.profile)
        guard !pools.isEmpty else {
            launchError = "Aucun exercice disponible pour ce parcours pour l’instant."
            return
        }
        let userId = DuelloAPI.publicProfileId(email: session.profile.email)
        do {
            let allowed = try await ChalAPI.correctionQuotaAllows(
                userId: userId,
                token: session.token
            )
            guard allowed else {
                launchError = "Ton quota de défis est épuisé. Ouvre l’onglet Défis pour voir la prochaine recharge ou l’offre Premium."
                return
            }
        } catch {
            launchError = error.localizedDescription
            return
        }
        launchError = nil
        queue.token = session.token
        ChalScheduledRoom.join(
            queue: queue,
            profile: session.profile,
            challenge: challenge,
            startsAt: startsAt,
            chapters: pools.keys.sorted(),
            pools: pools,
            startedExerciseIds: startedExerciseIds,
            elo: subjectElo
        )
    }
}
