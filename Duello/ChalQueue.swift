//
//  ChalQueue.swift
//  Duello
//
//  Lot « Extras de défi » — file d'attente d'un défi, vue du téléphone (cœur).
//
//  Fichier source Expo porté (états, garde-fous et enchaînements repris mot
//  pour mot) :
//    - src/hooks/useChallengeQueue.ts
//      (`ChallengeQueueStatus`, `ChallengeSearchMode`, `ChallengeInviteOutcome`,
//       `enter`, `cancel`, `release`, `adoptMatch`, `releasePending`,
//       `fallbackToTraining`, le suivi d'invitations)
//
//  Le joueur prend un ticket sur le serveur, qui l'apparie avec un autre joueur
//  réellement en train de chercher. Le compte à rebours de l'attente tourne à
//  part : une requête qui traîne ne fige pas l'écran. Une génération
//  (`generation`) invalide tout ce qui revient d'une recherche annulée.
//
//  Découpé en deux modules à responsabilité claire (règle des 500 lignes) :
//  `ChalQueueInvite.swift` porte le mode « invitation privée ». L'état partagé
//  est interne au module uniquement pour cette extension (aucun autre appelant
//  ne le modifie) ; l'interface publique reste `enter` / `cancel` / `release`.
//
//  Repli d'entraînement : passé `TRAINING_FALLBACK_MS` sans adversaire, le
//  contrôleur signale `trainingFallbackReached` puis fabrique le match
//  d'entraînement (`ChalTrainingMatchFactory.buildTrainingMatch`, porté de
//  `buildTrainingMatch`) avec la requête courante, **avant** que `cancel()`
//  n'efface `entry` ; `nil` (aucun exercice jouable) laisse l'état d'échec
//  (repli au repos). Un rendez-vous de classe reste une vraie salle multijoueur
//  et ne se transforme jamais en entraînement.
//
//  Le `QueueRequest` actuel ne porte pas de champ de salle planifiée : `Mode`
//  conserve `.scheduled` pour rester aligné sur la source, sans le produire.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import Combine

/// File d'attente d'un défi (`useChallengeQueue`).
@MainActor
final class ChalQueueController: ObservableObject {
    /// État de la recherche (`ChallengeQueueStatus`).
    enum Status: Equatable { case idle, searching, matched }
    /// Mode de recherche (`ChallengeSearchMode`).
    enum Mode: Equatable { case random, invitation, scheduled }
    /// Issue d'une invitation privée (`ChallengeInviteOutcome`).
    enum InviteOutcome: Equatable {
        case declined(name: String)
        case unavailable(name: String)
        case expired(name: String)
        case error(name: String)
    }

    @Published var status: Status = .idle
    @Published var mode: Mode?
    @Published var invitedName: String?
    @Published var inviteOutcome: InviteOutcome?
    /// Partie trouvée, à jouer telle quelle : même exo et même chrono des deux côtés.
    @Published var match: MatchView?
    @Published var waitedMs: Double = 0
    /// Joueurs en attente sur cette matière, celui-ci compris.
    @Published var queued: Int = 1
    /// Vrai quand le serveur ne répond pas pendant l'attente courante.
    @Published var offline: Bool = false
    @Published var scheduledStartAt: Double?
    /// Vrai quand l'attente a dépassé `TRAINING_FALLBACK_MS` sans adversaire.
    @Published var trainingFallbackReached = false

    /// Fenêtre annoncée par le serveur ; `nil` ⇒ la fourchette locale prend le relais.
    var serverWindow: Int?
    /// Fenêtre de cote affichée, de part et d'autre.
    var eloWindow: Int { serverWindow ?? ChalMatchmaking.eloWindow(waitedMs: waitedMs) }

    /// Jeton de session, posé par l'écran avant toute entrée dans la file.
    var token: String?

    // État de la recherche courante : tout ce qui revient d'une recherche
    // annulée est ignoré grâce à `generation`.
    var generation = 0
    var entry: QueueRequest?
    var ticket: String?
    var invitations: [ChalActiveInvitation] = []
    var pollTask: Task<Void, Never>?
    var waitTask: Task<Void, Never>?

    // MARK: Entrée dans la file

    /// Entre dans la file aléatoire (`enter`).
    func enter(_ request: QueueRequest) {
        stopTimers()
        releasePending()
        generation += 1
        entry = request
        status = .searching
        mode = .random
        invitedName = nil
        inviteOutcome = nil
        match = nil
        waitedMs = 0
        queued = 1
        offline = false
        serverWindow = nil
        trainingFallbackReached = false
        scheduledStartAt = nil
        runSearch(request)
    }

    // MARK: Sortie de la file

    /// Annule la recherche et rend toute attente distante (`cancel`).
    func cancel() {
        generation += 1
        stopTimers()
        releasePending()
        entry = nil
        status = .idle
        mode = nil
        invitedName = nil
        inviteOutcome = nil
        match = nil
        waitedMs = 0
        offline = false
        serverWindow = nil
        scheduledStartAt = nil
    }

    /// Sort de l'écran d'attente une fois la partie prise en charge (`release`).
    func release() {
        generation += 1
        stopTimers()
        entry = nil
        status = .idle
        mode = nil
        invitedName = nil
        match = nil
        waitedMs = 0
        offline = false
        serverWindow = nil
        scheduledStartAt = nil
    }

    // MARK: Interne (partagé avec `ChalQueueInvite.swift`)

    /// Arrête les horloges de la recherche courante (`stopTimers`).
    func stopTimers() {
        pollTask?.cancel()
        waitTask?.cancel()
        pollTask = nil
        waitTask = nil
    }

    /// Rend toute attente distante : file aléatoire ou invitations privées.
    func releasePending() {
        if let pending = ticket, let token {
            Task { await DuelloAPI.leaveQueue(ticket: pending, token: token) }
        }
        ticket = nil
        let pendingInvitations = invitations
        invitations = []
        guard let userId = entry?.userId, let token else { return }
        for active in pendingInvitations {
            Task { await ChalAPI.cancel(invitationId: active.invitationId, userId: userId, token: token) }
        }
    }

    /// Prend en charge la partie trouvée, où qu'elle vienne (`adoptMatch`).
    func adoptMatch(_ found: MatchView) {
        generation += 1
        stopTimers()
        ticket = nil
        invitations = []
        entry = nil
        match = found
        status = .matched
    }

    /// Horloge de l'attente, commune aux deux modes (`setInterval` de la source).
    func startWaitClock(generation gen: Int) {
        let started = Date()
        waitTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, gen == self.generation else { return }
                self.waitedMs = Date().timeIntervalSince(started) * 1000
            }
        }
    }

    /// Recherche aléatoire : horloge d'attente, puis interrogation de la file.
    func runSearch(_ request: QueueRequest) {
        let gen = generation
        let started = Date()
        waitTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, gen == self.generation else { return }
                self.waitedMs = Date().timeIntervalSince(started) * 1000
                // `QueueRequest` ne porte pas de salle planifiée (cf. en-tête) :
                // seul le dépassement du délai déclenche le repli entraînement.
                guard self.waitedMs >= ChalMatchmaking.trainingFallbackMs else { continue }
                self.trainingFallbackReached = true
                // Fabrique l'entraînement avec la requête courante **avant**
                // `cancel()`, qui efface `entry`. `buildTrainingMatch` renvoie
                // `nil` sans exercice jouable : on garde alors l'état d'échec
                // (repli au repos) plutôt que de fabriquer un faux adversaire.
                let fallback = self.entry.flatMap {
                    ChalTrainingMatchFactory.buildTrainingMatch(
                        $0,
                        now: Date().timeIntervalSince1970 * 1000,
                        durationMinutes: ChalMatchmaking.challengeDurationMinutes
                    )
                }
                self.cancel()
                if let fallback {
                    self.match = fallback.matchView()
                    self.status = .matched
                }
                return
            }
        }
        startPolling(generation: gen)
    }

    /// Interroge la file tant que la recherche courante est vivante
    /// (`step` de la source).
    func startPolling(generation gen: Int) {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, gen == self.generation,
                      let request = self.entry, let token = self.token else { return }
                do {
                    let state: QueueState
                    if let ticket = self.ticket {
                        state = try await DuelloAPI.pollQueue(ticket: ticket, token: token)
                    } else {
                        state = try await DuelloAPI.joinQueue(request, token: token)
                    }
                    guard gen == self.generation else { return }
                    self.offline = false
                    switch state {
                    case .matched(_, let found):
                        self.ticket = nil
                        self.adoptMatch(found)
                        return
                    case .waiting(let ticket, _, let window, let queued):
                        self.ticket = ticket
                        self.queued = queued
                        self.serverWindow = window
                    case .expired:
                        // Ticket expiré : on reprend une place au tour suivant.
                        self.ticket = nil
                    }
                } catch {
                    guard gen == self.generation else { return }
                    self.ticket = nil
                    if let status = (error as? DirectoryError)?.status, status < 500 {
                        // Une demande refusée ne passera pas au tour suivant.
                        self.cancel()
                        return
                    }
                    // Serveur muet : l'attente continue, l'entraînement prendra le relais.
                    self.offline = true
                    self.serverWindow = nil
                }
                try? await Task.sleep(nanoseconds: ChalMatchmaking.queuePollIntervalNanoseconds)
            }
        }
    }
}
