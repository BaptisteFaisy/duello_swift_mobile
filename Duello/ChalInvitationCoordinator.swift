//
//  ChalInvitationCoordinator.swift
//  Duello
//
//  Lot « Extras de défi » — relève des invitations de défi depuis la racine.
//
//  Fichier source Expo porté (libellés et enchaînements repris mot pour mot) :
//    - src/components/ChallengeInvitationCoordinator.tsx
//      (`INVITATION_POLL_MS`, `refresh`, `respond`, la vérification du quota,
//       la construction de la cible `QueueRequest`, la génération de réponse)
//
//  L'onglet Défis peut être fermé : le popup apparaît malgré tout sur l'écran
//  actuellement consulté. Une réponse réseau arrivée après un changement de
//  génération n'ouvre ni ne ferme rien : `generation` invalide l'ancienne relève.
//
//  Adaptations assumées : les écouteurs `AppState` et `expo-notifications` de la
//  source ne sont pas rejoués ici (le premier relève est fait au démarrage de la
//  boucle, l'appelant peut rappeler `refresh()` au retour au premier plan). Le
//  lot `PushNotif` couvre les notifications. La cible de défi reçoit les
//  exercices déjà commencés (`startedExerciseIds`) et un résolveur de cote par
//  matière (`subjectEloFor`), faute d'`AccountStorage`/`useSubjectElo` ici.
//
//  V1 (2026-10-02, écart A8-07 P1) : la cible porte la cote **de la matière du
//  défi** (`getSubjectElo(subjectElos, challenge.subject)`,
//  `ChallengeInvitationCoordinator.tsx:198`) et non plus la moyenne globale.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import Combine

/// Relève et réponse aux invitations de défi (`ChallengeInvitationCoordinator`).
@MainActor
final class ChalInvitationCoordinator: ObservableObject {
    /// Fréquence courte pour qu'une invitation apparaisse comme un événement
    /// direct (`INVITATION_POLL_MS`).
    static let pollIntervalNanoseconds: UInt64 = 10_000_000_000

    @Published var invitation: ChalIncomingInvitation?
    @Published var responding = false
    @Published var error: String?

    private var generation = 0
    private var pollTask: Task<Void, Never>?
    private var profile = UserProfile()
    private var token: String?
    private var busy = false
    /// Résout la cote d'une matière (`getSubjectElo`, `subjectElo.ts:198` =
    /// `subjectElos[subject] ?? INITIAL_SUBJECT_ELO`). Fourni par l'appelant,
    /// faute d'`AccountStorage`/`useSubjectElo` ici.
    private var subjectEloFor: (String) -> Int = { _ in ProgressStore.initialElo }
    private var startedExerciseIds: [String] = []
    private var onAccepted: ((MatchView) -> Void)?

    /// Démarre la relève périodique ; `busy` interdit toute apparition de popup.
    func start(
        profile: UserProfile,
        busy: Bool,
        token: String?,
        subjectEloFor: @escaping (String) -> Int = { _ in ProgressStore.initialElo },
        startedExerciseIds: [String] = [],
        onAccepted: @escaping (MatchView) -> Void
    ) {
        stop()
        self.profile = profile
        self.busy = busy
        self.token = token
        self.subjectEloFor = subjectEloFor
        self.startedExerciseIds = startedExerciseIds
        self.onAccepted = onAccepted
        generation += 1
        responding = false
        error = nil
        invitation = nil
        let gen = generation
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, gen == self.generation else { return }
                await self.refresh()
                guard gen == self.generation else { return }
                try? await Task.sleep(nanoseconds: Self.pollIntervalNanoseconds)
            }
        }
    }

    /// Arrête la relève (écran quitté, changement de compte).
    func stop() {
        generation += 1
        pollTask?.cancel()
        pollTask = nil
    }

    /// Relève les invitations ; `busy` est transmis au serveur, qui décide de ne
    /// rien proposer, puis la relève est vidée localement. Une relève manquée
    /// sera retentée au prochain passage, un popup déjà visible restant
    /// utilisable.
    func refresh() async {
        guard let token else { return }
        let gen = generation
        do {
            let incoming = try await ChalAPI.fetchIncoming(
                email: profile.email,
                busy: busy,
                token: token
            )
            guard gen == generation else { return }
            if busy {
                invitation = nil
                return
            }
            invitation = Self.reconcile(current: invitation, incoming: incoming)
        } catch {
            // Une relève manquée sera retentée au prochain passage.
        }
    }

    /// Répond à l'invitation affichée (`respond`).
    func respond(_ decision: ChalInvitationDecision) {
        guard let current = invitation, !responding else { return }
        responding = true
        error = nil
        let gen = generation
        Task { [weak self] in
            guard let self else { return }
            let failure = await self.performRespond(decision, invitation: current)
            guard gen == self.generation else { return }
            self.responding = false
            self.error = failure
        }
    }

    // MARK: Interne

    /// Exécute la réponse et applique son résultat. Renvoie un message d'erreur
    /// à afficher, `nil` en cas de succès.
    private func performRespond(
        _ decision: ChalInvitationDecision,
        invitation current: ChalIncomingInvitation
    ) async -> String? {
        guard let token else { return "Impossible de répondre pour le moment." }
        let userId = DuelloAPI.publicProfileId(email: profile.email)
        var target: QueueRequest?
        if decision == .accepted {
            do {
                let allowed = try await ChalAPI.correctionQuotaAllows(userId: userId, token: token)
                guard allowed else {
                    return "Ton quota de défis est épuisé. Ouvre l’onglet Défis pour voir la prochaine recharge ou l’offre Premium."
                }
            } catch {
                return error.localizedDescription
            }
            guard let prepared = buildTarget(invitation: current, userId: userId) else {
                return "Ce défi ne correspond pas à ton option de mathématiques, ou ses exercices ne sont pas encore disponibles."
            }
            target = prepared
        }
        do {
            let state = try await ChalAPI.respond(
                invitationId: current.id,
                userId: userId,
                decision: decision,
                target: target,
                token: token
            )
            generation += 1
            invitation = nil
            if decision == .accepted, case .accepted(let found) = state {
                onAccepted?(found)
            } else {
                await refresh()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Construit la cible du défi accepté, bornée aux chapitres de l'invitation
    /// (`challengeExercisePoolsFor` + `QueueRequest`).
    private func buildTarget(
        invitation current: ChalIncomingInvitation,
        userId: String
    ) -> QueueRequest? {
        let keys = current.challenge.keys
        let pools = DuelloExerciseCatalog.queuePools(for: profile)
        let filtered = pools.filter { keys.contains($0.key) }
        guard !filtered.isEmpty else { return nil }
        return QueueRequest(
            userId: userId,
            displayName: profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            prepName: profile.prepName.trimmingCharacters(in: .whitespacesAndNewlines),
            track: profile.track,
            year: profile.year,
            specialty: profile.specialty.isEmpty ? nil : profile.specialty,
            subject: current.challenge.subject,
            chapters: keys,
            exercisePools: filtered,
            startedExerciseIds: startedExerciseIds,
            allowStartedExercises: false,
            maxExercises: nil,
            // Cote de la **matière du défi** (`getSubjectElo(subjectElos,
            // challenge.subject)`, `ChallengeInvitationCoordinator.tsx:198`).
            elo: subjectEloFor(current.challenge.subject)
        )
    }

    /// Conserve l'invitation affichée tant qu'elle est encore proposée, sinon
    /// passe à la première disponible.
    private static func reconcile(
        current: ChalIncomingInvitation?,
        incoming: [ChalIncomingInvitation]
    ) -> ChalIncomingInvitation? {
        guard let current else { return incoming.first }
        return incoming.first { $0.id == current.id } ?? incoming.first
    }
}
