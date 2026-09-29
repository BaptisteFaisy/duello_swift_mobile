//
//  CollCorrectionQuotaController.swift
//  Duello
//
//  Contrôleur du quota de corrections du compte connecté
//  (`hooks/useCorrectionQuota.ts`) : relecture, réservation, abonnement stocké.
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/hooks/useCorrectionQuota.ts (`useCorrectionQuota`,
//      `QUOTA_UNAVAILABLE_MESSAGE`, `unavailable`, `failureMessage`).
//
//  Adaptations assumées :
//    - le hook n'est plus un hook mais un `ObservableObject` (un seul compte à
//      la fois) ; l'identité et la génération de réservation sont conservées,
//      pour qu'une lecture partie pendant une réservation ne réaffiche pas le
//      compteur d'avant ;
//    - l'instantané serveur porté (`PremQuotaService`) ne porte que trois
//      champs : l'accès est recalculé par le moteur local
//      (`CollCorrectionQuota.evaluate`), le serveur restant l'autorité pour
//      `subscribed` et la réservation.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation
import SwiftUI

/// Quota de corrections du compte connecté (`useCorrectionQuota`).
@MainActor
final class CollCorrectionQuotaController: ObservableObject {
    /// `QUOTA_UNAVAILABLE_MESSAGE`.
    static let unavailableMessage = "Le serveur ne peut pas vérifier ton quota de défis pour le moment. Vérifie ta connexion, puis réessaie."
    /// `ACCOUNT_STORAGE_KEYS.correctionQuota`.
    static let storageKey = "prepapp-correction-quota:v1"

    @Published private(set) var ready = false
    @Published private(set) var error: String?
    @Published private(set) var quota: CollCorrectionQuotaState
    @Published private(set) var subscribed = false
    @Published private(set) var access: CollCorrectionAvailability
    @Published private(set) var freeTrialEligible = true
    @Published private(set) var remainingFree = 0
    @Published private(set) var nextFreeAt: Double?

    private let userId: String
    private let token: String?
    private let identity: String
    /// `reservationGeneration` : invalide une lecture dépassée par une réservation.
    private var generation = 0

    init(email: String, token: String?) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        userId = DuelloAPI.publicProfileId(email: trimmed)
        self.token = token
        identity = ConsentPremiumGate.accountId(email: trimmed)
        quota = CollCorrectionQuota.parse(UserDefaults.standard.string(forKey: Self.storageKey))
        access = .unavailable(message: Self.unavailableMessage)
    }

    /// `reload` : relit le quota du serveur ; une lecture dépassée par une
    /// réservation n'écrase pas l'affichage.
    @discardableResult
    func reload() async -> CollCorrectionAvailability {
        let requested = generation
        do {
            let snapshot = try await PremQuotaService.load(token: token, userId: userId)
            guard generation == requested else { return unavailable() }
            guard let snapshot else { return fail(Self.unavailableMessage, requested: requested) }
            subscribed = snapshot.subscribed
            freeTrialEligible = snapshot.freeTrialEligible
            remainingFree = snapshot.remainingFree
            return settle(
                CollCorrectionQuota.evaluate(
                    quota, now: CollCorrectionQuotaController.nowMilliseconds(),
                    subscribed: snapshot.subscribed
                ),
                requested: requested
            )
        } catch {
            return fail(message(from: error), requested: requested)
        }
    }

    /// `reserve` : retient une correction ; la réservation invalide toute lecture
    /// encore en vol.
    @discardableResult
    func reserve(operationKey: String) async -> CollCorrectionAvailability {
        generation += 1
        let requested = generation
        do {
            let reservation = try await ChalAPI.reserveCorrectionQuota(
                userId: userId, operationKey: operationKey, token: token
            )
            guard generation == requested else { return unavailable() }
            quota = CollCorrectionQuota.consume(
                quota, now: CollCorrectionQuotaController.nowMilliseconds()
            )
            persist()
            return settle(decision(from: reservation), requested: requested)
        } catch {
            return fail(message(from: error), requested: requested)
        }
    }

    /// Publie l'accès décidé et dérive les champs affichés.
    private func settle(
        _ decision: CollCorrectionAccess,
        requested: Int
    ) -> CollCorrectionAvailability {
        guard generation == requested else { return unavailable() }
        access = .access(decision)
        remainingFree = CollCorrectionQuota.remainingFree(quota)
        nextFreeAt = CollCorrectionQuota.nextFreeAt(quota)
        ready = true
        error = nil
        return access
    }

    /// `unavailable` : accès fermé tant que le serveur n'a pas répondu.
    private func unavailable() -> CollCorrectionAvailability {
        .unavailable(message: Self.unavailableMessage)
    }

    /// `unavailable(message)` + mémorise l'erreur quand elle est encore d'actualité.
    private func fail(_ message: String, requested: Int) -> CollCorrectionAvailability {
        if generation == requested {
            ready = true
            error = message
        }
        return .unavailable(message: message)
    }

    /// Décision tirée d'une réservation serveur (`QuotaReservation`).
    private func decision(from reservation: ChalAPI.QuotaReservation) -> CollCorrectionAccess {
        switch reservation {
        case .allowed(let reason):
            switch reason {
            case "subscription": return .subscription
            case "free-allowance": return .freeAllowance(remaining: remainingFree)
            case "free-refill": return .freeRefill
            default: return .freeRefill
            }
        case .paywall:
            let now = CollCorrectionQuotaController.nowMilliseconds()
            let next = CollCorrectionQuota.nextFreeAt(quota) ?? now
            return .paywall(nextFreeAt: next, waitMs: max(0, next - now))
        }
    }

    /// Écrit l'état du quota dans les préférences.
    private func persist() {
        guard let raw = CollCorrectionQuota.serialize(quota) else { return }
        UserDefaults.standard.set(raw, forKey: Self.storageKey)
    }

    /// `failureMessage` : message de l'erreur s'il existe, sinon le repli.
    private func message(from error: Error) -> String {
        let text = (error as? LocalizedError)?.errorDescription?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? Self.unavailableMessage : text
    }

    /// `Date.now()`, en millisecondes.
    private static func nowMilliseconds() -> Double {
        Date().timeIntervalSince1970 * 1000
    }
}
