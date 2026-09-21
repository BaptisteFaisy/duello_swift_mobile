//
//  PremCodeState.swift
//  Duello
//
//  Réduction d’état du formulaire « code d’affiliation ».
//
//  Fichier source Expo porté : `src/utils/premiumCodeRedemptionState.ts`.
//  Le réducteur est pur : il garde l’état d’un compte hors de l’écran pendant
//  un changement d’identité, et n’applique une réponse que si elle appartient
//  à la requête en cours.
//
//  Cible : iOS 16.
//
import Foundation

/// État, actions et réducteur du formulaire de code d’affiliation.
enum PremCodeState {
    /// `PremiumCodeFeedbackKind`.
    enum FeedbackKind: String, Equatable {
        case error
        case success
    }

    /// `PremiumCodeFeedback` : le message affiché et son rang d’annonce.
    struct Feedback: Equatable {
        let announcementId: Int
        let kind: FeedbackKind
        let message: String
    }

    /// `PremiumCodeRedemptionState`.
    struct Redemption: Equatable {
        var accountId: String
        var code: String
        var feedback: Feedback?
        var requestId: Int?
        var submitting: Bool
    }

    /// `PremiumCodeRedemptionAction`.
    enum Action: Equatable {
        case reset(accountId: String)
        case change(accountId: String, code: String)
        case reject(accountId: String, feedback: Feedback)
        case start(accountId: String, requestId: Int)
        case resolve(accountId: String, requestId: Int, feedback: Feedback)
    }

    /// `initialPremiumCodeState`.
    static func initial(accountId: String) -> Redemption {
        Redemption(accountId: accountId, code: "", feedback: nil, requestId: nil, submitting: false)
    }

    /// `premiumCodeStateForAccount` : empêche l’état de l’ancien compte
    /// d’apparaître pendant le changement d’identité.
    static func forAccount(_ state: Redemption, accountId: String) -> Redemption {
        state.accountId == accountId ? state : initial(accountId: accountId)
    }

    /// `reducePremiumCodeState`.
    static func reduce(_ state: Redemption, _ action: Action) -> Redemption {
        switch action {
        case .reset(let accountId):
            return initial(accountId: accountId)
        case .resolve(let accountId, let requestId, let feedback):
            guard state.accountId == accountId, state.requestId == requestId else { return state }
            var next = state
            if feedback.kind == .success { next.code = "" }
            next.feedback = feedback
            next.requestId = nil
            next.submitting = false
            return next
        case .change(let accountId, let code):
            var current = forAccount(state, accountId: accountId)
            current.code = code
            current.feedback = nil
            return current
        case .reject(let accountId, let feedback):
            var current = forAccount(state, accountId: accountId)
            current.feedback = feedback
            return current
        case .start(let accountId, let requestId):
            var current = forAccount(state, accountId: accountId)
            current.feedback = nil
            current.requestId = requestId
            current.submitting = true
            return current
        }
    }
}
