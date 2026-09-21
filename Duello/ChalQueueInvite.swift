//
//  ChalQueueInvite.swift
//  Duello
//
//  Lot « Extras de défi » — file d'attente d'un défi : mode « invitation privée »
//  (extension de `ChalQueueController`, aucun type renommé).
//
//  Fichier source Expo porté (états et enchaînements repris mot pour mot) :
//    - src/hooks/useChallengeQueue.ts   (`invite`, `finish`, `settle`,
//                                        `watchInvitation`, `createDirectChallengeInvitation`)
//
//  Le défi reste un duel : plusieurs amis peuvent être invités d'un coup, la
//  première acceptation ouvre la partie et libère les autres. Chaque invitation
//  est suivie indépendamment jusqu'à sa réponse. L'état partagé est interne au
//  module uniquement pour cette extension.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import Combine

extension ChalQueueController {
    /// Entre dans la file d'une invitation privée (`invite`).
    func invite(_ request: QueueRequest, targets: [ChalInviteTarget]) {
        stopTimers()
        releasePending()
        generation += 1
        let gen = generation
        entry = request
        status = .searching
        mode = .invitation
        invitedName = SocInviteCopy.invitedNamesSummary(targets.map(\.displayName))
        inviteOutcome = nil
        match = nil
        waitedMs = 0
        queued = 1
        offline = false
        serverWindow = nil
        scheduledStartAt = nil
        trainingFallbackReached = false
        startWaitClock(generation: gen)
        for target in targets {
            createInvitation(for: target, request: request, generation: gen)
        }
    }

    /// Crée une invitation directe pour un ami, puis la suit jusqu'à sa réponse.
    func createInvitation(
        for target: ChalInviteTarget,
        request: QueueRequest,
        generation gen: Int
    ) {
        Task { [weak self] in
            guard let self, let token = self.token else { return }
            do {
                let created = try await ChalAPI.create(
                    challenger: request,
                    targetId: target.id,
                    chapterNames: target.chapterNames,
                    token: token
                )
                guard gen == self.generation else {
                    if created.state == "pending" {
                        await ChalAPI.cancel(
                            invitationId: created.invitationId,
                            userId: request.userId,
                            token: token
                        )
                    }
                    return
                }
                if created.state == "unavailable" {
                    self.finish(.unavailable(name: target.displayName))
                    return
                }
                let active = ChalActiveInvitation(
                    invitationId: created.invitationId,
                    displayName: target.displayName
                )
                self.invitations.append(active)
                self.watchInvitation(active, request: request, generation: gen)
            } catch {
                guard gen == self.generation else { return }
                self.finish(.error(name: target.displayName))
            }
        }
    }

    /// Suit une invitation jusqu'à sa réponse, indépendamment des autres
    /// (`watchInvitation` + `settle`).
    func watchInvitation(
        _ active: ChalActiveInvitation,
        request: QueueRequest,
        generation gen: Int
    ) {
        Task { [weak self] in
            while !Task.isCancelled {
                guard let self, gen == self.generation, let token = self.token else { return }
                do {
                    let state = try await ChalAPI.poll(
                        invitationId: active.invitationId, userId: request.userId, token: token
                    )
                    guard gen == self.generation else { return }
                    self.offline = false
                    switch state {
                    case .accepted(let found):
                        // La première acceptation ouvre la partie : les autres
                        // propositions s'annulent d'elles-mêmes.
                        for other in self.invitations {
                            await ChalAPI.cancel(invitationId: other.invitationId, userId: request.userId, token: token)
                        }
                        self.adoptMatch(found)
                        return
                    case .pending:
                        break
                    case .declined:
                        self.finish(.declined(name: active.displayName))
                        return
                    case .unavailable:
                        self.finish(.unavailable(name: active.displayName))
                        return
                    case .expired:
                        self.finish(.expired(name: active.displayName))
                        return
                    }
                } catch {
                    guard gen == self.generation else { return }
                    // L'invitation existe déjà côté serveur : une coupure ne l'annule pas.
                    self.offline = true
                }
                try? await Task.sleep(nanoseconds: ChalMatchmaking.queuePollIntervalNanoseconds)
            }
        }
    }

    /// Clôt une recherche d'invitation sur son issue (`finish`).
    func finish(_ outcome: InviteOutcome) {
        stopTimers()
        invitations = []
        entry = nil
        status = .idle
        mode = nil
        invitedName = nil
        offline = false
        inviteOutcome = outcome
    }
}
