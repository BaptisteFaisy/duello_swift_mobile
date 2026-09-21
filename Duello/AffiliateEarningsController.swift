import Combine
import Foundation
import UIKit

// MARK: - État de l'espace affiliation
//
// Portage de `src/features/affiliate/useAffiliateEarningsController.ts` :
// chargement du portefeuille, avis affichés, saisie du montant, copie du code
// d'affiliation et envoi d'un retrait. Les actions de l'utilisateur sont dans
// `AffiliateEarningsActions.swift`.
//
// Différences assumées avec la source :
//   - la relance au retour au premier plan passe par `scenePhase` (il n'existe
//     pas d'`AppState` ici) ;
//   - l'annulation de la requête en vol à la fermeture de l'écran s'appuie sur
//     l'annulation de la `Task` SwiftUI qui appelle `load` (`AbortController`
//     n'existe pas côté natif) ;
//   - l'échec de copie du presse-papiers n'a pas d'équivalent observable :
//     `UIPasteboard` ne lève pas d'erreur, il n'y a donc pas de message d'échec.

/// Contrôleur de l'espace affiliation.
final class AffiliateEarningsController: ObservableObject {
    @Published private(set) var wallet: AffWallet?
    @Published private(set) var loading = true
    @Published private(set) var refreshing = false
    @Published private(set) var loadError: String?
    @Published private(set) var actionError: String?
    @Published private(set) var success: String?
    @Published private(set) var activeAction: AffFinancialAction?
    @Published private(set) var amount = ""
    @Published private(set) var publicIdCopied = false

    /// Dernière tentative de retrait, conservée pour rejouer la même clé
    /// d'idempotence quand l'élève renvoie le même montant (`attemptRef`).
    private var lastAttempt: AffWithdrawalAttempt?
    /// Garde-fou d'unicité du chargement (`loadingRef`).
    private var loadInFlight = false
    /// Retour visuel « copié », remis à zéro après 2,5 s comme la source.
    private var copyResetTask: Task<Void, Never>?
    private static let copyResetNanoseconds: UInt64 = 2_500_000_000

    // MARK: Lecture

    /// `financialActionBusy` : une action financière à la fois.
    var busy: Bool { activeAction != nil }

    var openingStripe: Bool { activeAction == .stripe }

    var withdrawing: Bool { activeAction == .withdrawal }

    /// Identifiant du retrait en cours de relance, `nil` sinon.
    var retryingId: String? {
        guard case .retry(let id) = activeAction else { return nil }
        return id
    }

    var amountMinor: Int? { AffiliateFormatting.minor(fromInput: amount) }

    var limits: AffAmountLimits? {
        guard let wallet else { return nil }
        return AffAmountLimits(
            minimum: wallet.minWithdrawalMinor,
            maximum: wallet.maxWithdrawalMinor
        )
    }

    var amountError: String? {
        AffiliateCopy.amountError(
            input: amount,
            amountMinor: amountMinor,
            wallet: wallet,
            limits: limits
        )
    }

    /// `canSubmit` : retrait ouvert, montant dans les bornes et solde suffisant.
    var canSubmit: Bool {
        guard let wallet, let amountMinor, let limits, !busy else { return false }
        return wallet.canWithdraw
            && amountMinor >= limits.minimum
            && amountMinor <= limits.maximum
            && amountMinor <= wallet.availableMinor
    }

    // MARK: Chargement

    /// `loadWallet` : relit le solde ; `quiet` n'affiche pas l'état de
    /// chargement initial et sert aux rafraîchissements silencieux. En cas
    /// d'échec, le portefeuille déjà affiché est conservé, comme la source.
    @MainActor
    func load(token: String?, quiet: Bool = false) async {
        guard !loadInFlight else { return }
        loadInFlight = true
        if quiet { refreshing = true } else { loading = true }
        do {
            wallet = try await AffiliateAPI.wallet(token: token)
            loadError = nil
        } catch {
            // Une requête annulée (écran fermé pendant le chargement) ne laisse
            // aucun avis d'échec, comme la source qui sort avant `setLoadError`.
            if !Task.isCancelled {
                loadError = AffiliateCopy.message(
                    error,
                    fallback: "Impossible de charger le solde affilié."
                )
            }
        }
        loadInFlight = false
        loading = false
        refreshing = false
    }

    // MARK: Avis

    /// `begin` : réserve l'action financière exclusive. `false` si une autre
    /// action est déjà en cours.
    func begin(_ action: AffFinancialAction) -> Bool {
        guard activeAction == nil else { return false }
        activeAction = action
        clearNotices()
        return true
    }

    /// `finish` : libère l'action si c'est bien celle qui la détient.
    func finish(_ action: AffFinancialAction) {
        guard activeAction == action else { return }
        activeAction = nil
    }

    /// `fail` : message d'échec de l'action en cours.
    func fail(_ error: Error, fallback: String) {
        actionError = AffiliateCopy.message(error, fallback: fallback)
    }

    /// `succeed` : message de confirmation de l'action en cours.
    func succeed(_ message: String) {
        success = message
    }

    /// `clear` : efface les deux avis de l'espace.
    func clearNotices() {
        actionError = nil
        success = nil
    }

    // MARK: Saisie et code d'affiliation

    /// Écrit la saisie sans toucher aux avis (`setAmountValue`).
    func updateAmount(_ value: String) {
        amount = value
    }

    /// `copyPublicId` : copie le code public et confirme visuellement 2,5 s.
    func copyPublicId() {
        guard let wallet else { return }
        clearNotices()
        UIPasteboard.general.string = wallet.publicId
        publicIdCopied = true
        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.copyResetNanoseconds)
            guard !Task.isCancelled else { return }
            self.publicIdCopied = false
        }
    }

    // MARK: Retrait

    /// `submitWithdrawal` : réserve puis verse le montant saisi, avec une clé
    /// d'idempotence stable tant que le montant ne change pas.
    @MainActor
    func submitWithdrawal(token: String?) async {
        guard let wallet, canSubmit, let amountMinor, begin(.withdrawal) else { return }
        let attempt: AffWithdrawalAttempt
        if let previous = lastAttempt, previous.amountMinor == amountMinor {
            attempt = previous
        } else {
            attempt = AffWithdrawalAttempt(
                amountMinor: amountMinor,
                idempotencyKey: AffiliateFormatting.idempotencyKey()
            )
        }
        lastAttempt = attempt
        do {
            _ = try await AffiliateAPI.requestWithdrawal(
                amountMinor: attempt.amountMinor,
                idempotencyKey: attempt.idempotencyKey,
                token: token
            )
            lastAttempt = nil
            updateAmount("")
            succeed(
                wallet.simulated
                    ? "La simulation de retrait a bien été enregistrée."
                    : "Ta demande de retrait a bien été enregistrée."
            )
        } catch {
            fail(error, fallback: "Impossible d’effectuer ce retrait.")
        }
        await load(token: token, quiet: true)
        finish(.withdrawal)
    }
}
