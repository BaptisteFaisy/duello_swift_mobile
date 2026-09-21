//
//  PremCodeController.swift
//  Duello
//
//  Contrôleur du formulaire « code d’affiliation ».
//
//  Fichier source Expo porté : `src/hooks/usePremiumCodeRedemption.ts`. Il
//  réduit l’état pur de `PremCodeState`, normalise la saisie, bloque les
//  soumissions concurrentes et traduit les réponses du serveur en messages
//  affichables.
//
//  Le code saisi n’est jamais conservé ailleurs que dans l’état du formulaire,
//  et il est effacé dès qu’un code est accepté.
//
//  Cible : iOS 16.
//
import Foundation
import Combine

/// État et soumission du formulaire de code d’affiliation.
final class PremCodeController: ObservableObject {
    /// `PremiumCodeRedemptionState`, réduit par `PremCodeState`.
    @Published private(set) var state: PremCodeState.Redemption

    let accountId: String
    let registered: Bool

    private let email: String
    private let token: String?
    private var sequence = 0
    private var pending = false

    init(email: String, token: String?, accountId: String, registered: Bool) {
        self.email = email
        self.token = token
        self.accountId = accountId
        self.registered = registered
        self.state = PremCodeState.initial(accountId: accountId)
    }

    var code: String { state.code }
    var feedback: PremCodeState.Feedback? { state.feedback }
    var submitting: Bool { state.submitting }

    /// `canSubmit` : inscrit, sans soumission en cours, code non vide.
    var canSubmit: Bool {
        registered && !state.submitting && !PremCodeCopy.forSubmission(state.code).isEmpty
    }

    /// `setCode` : normalise la saisie et efface le message précédent.
    func setCode(_ value: String) {
        state = PremCodeState.reduce(
            state,
            .change(accountId: accountId, code: PremCodeCopy.normalize(value)))
    }

    /// `submit` : refuse hors session ou code vide, sinon appelle l’API.
    func submit() async {
        guard !pending else { return }
        sequence += 1
        let requestId = sequence
        if !registered {
            state = PremCodeState.reduce(state, reject(requestId,
                "Connecte-toi à un compte Duello pour utiliser un code d’affiliation."))
            return
        }
        let code = PremCodeCopy.forSubmission(state.code)
        if code.isEmpty {
            state = PremCodeState.reduce(state, reject(requestId,
                "Saisis un code d’affiliation avant de continuer."))
            return
        }
        pending = true
        state = PremCodeState.reduce(state, .start(accountId: accountId, requestId: requestId))
        do {
            let attribution = try await PremCodeAPI.redeem(email: email, token: token, code: code)
            await resolve(requestId, kind: .success,
                message: PremCodeCopy.successMessage(applied: attribution.applied))
        } catch {
            await resolve(requestId, kind: .error,
                message: PremCodeCopy.failureMessage(error))
        }
        pending = false
    }

    /// Action de refus local, avec le message affiché.
    private func reject(_ requestId: Int, _ message: String) -> PremCodeState.Action {
        .reject(
            accountId: accountId,
            feedback: PremCodeState.Feedback(
                announcementId: requestId, kind: .error, message: message))
    }

    /// Applique la réponse de la requête sur le fil principal.
    private func resolve(
        _ requestId: Int,
        kind: PremCodeState.FeedbackKind,
        message: String
    ) async {
        let action = PremCodeState.Action.resolve(
            accountId: accountId,
            requestId: requestId,
            feedback: PremCodeState.Feedback(
                announcementId: requestId, kind: kind, message: message))
        await MainActor.run { self.state = PremCodeState.reduce(self.state, action) }
    }
}
