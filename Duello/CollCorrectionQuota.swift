//
//  CollCorrectionQuota.swift
//  Duello
//
//  Quota de corrections d'un compte (`utils/correctionQuota.ts`) : moteur local.
//
//  Une correction est l'unité facturée du produit. Trois gestes en consomment
//  exactement une : un défi joué, un exercice soumis en entier, une question
//  isolée soumise depuis le lecteur. Les dix premières sont offertes au premier
//  compte de l'appareil, puis une correction est offerte toutes les 48 heures.
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/utils/correctionQuota.ts
//        `FREE_CORRECTION_ALLOWANCE`, `FREE_CORRECTION_INTERVAL_MS`,
//        `CorrectionQuotaState`, `CorrectionAccess`, `CorrectionAvailability`,
//        `emptyCorrectionQuota`, `parseCorrectionQuota`, `serializeCorrectionQuota`,
//        `remainingFreeCorrections`, `nextFreeCorrectionAt`,
//        `evaluateCorrectionAccess`, `consumeCorrection`, `formatCorrectionWait`.
//
//  L'instantané serveur (`parseAuthoritativeCorrectionQuota`) est déjà porté par
//  `PremQuotaService` ; le contrôleur d'état vit dans
//  `CollCorrectionQuotaController.swift`. Cible : iOS 16.
//
import Foundation

/// État durable du quota (`CorrectionQuotaState`).
struct CollCorrectionQuotaState: Codable, Equatable {
    /// Toujours 1 (`schemaVersion: 1`).
    var schemaVersion: Int = 1
    /// Corrections déjà consommées, sans plafond.
    var used: Int
    /// Dernière correction consommée, origine des 48 heures d'attente.
    var lastConsumedAt: Double?
}

/// Accès décidé pour une correction (`CorrectionAccess`).
enum CollCorrectionAccess: Equatable {
    /// Abonnement actif : aucune limite.
    case subscription
    /// Une des dix corrections offertes au premier compte de l'appareil.
    case freeAllowance(remaining: Int)
    /// Correction offerte débloquée par les 48 heures écoulées.
    case freeRefill
    /// Plus rien à consommer : le paywall doit s'afficher.
    case paywall(nextFreeAt: Double, waitMs: Double)
}

/// Accès fermé tant que l'autorité serveur n'a pas répondu
/// (`CorrectionAvailability`).
enum CollCorrectionAvailability: Equatable {
    case access(CollCorrectionAccess)
    case unavailable(message: String)
}

/// Moteur local du quota de corrections (`utils/correctionQuota.ts`).
enum CollCorrectionQuota {
    /// `FREE_CORRECTION_ALLOWANCE` : les dix corrections du premier compte.
    static let allowance = 10
    /// `FREE_CORRECTION_INTERVAL_MS` : 48 heures.
    static let freeIntervalMilliseconds: Double = 48 * 60 * 60 * 1000

    /// `emptyCorrectionQuota` : état technique vide.
    static func empty() -> CollCorrectionQuotaState {
        CollCorrectionQuotaState(schemaVersion: 1, used: 0, lastConsumedAt: nil)
    }

    /// `parseCorrectionQuota` : une valeur illisible repart d'un état vide.
    static func parse(_ raw: String?) -> CollCorrectionQuotaState {
        guard let raw, let data = raw.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data),
              let object = parsed as? [String: Any]
        else { return empty() }
        let last = positiveInteger(object["lastConsumedAt"])
        return CollCorrectionQuotaState(
            schemaVersion: 1,
            used: positiveInteger(object["used"]),
            lastConsumedAt: last > 0 ? Double(last) : nil
        )
    }

    /// `serializeCorrectionQuota` : forme persistée.
    static func serialize(_ state: CollCorrectionQuotaState) -> String? {
        guard let data = try? JSONEncoder().encode(state) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// `remainingFreeCorrections` : corrections offertes encore disponibles.
    static func remainingFree(_ state: CollCorrectionQuotaState) -> Int {
        max(0, allowance - state.used)
    }

    /// `nextFreeCorrectionAt` : instant de la prochaine correction offerte, ou
    /// `nil` tant que l'allocation initiale n'est pas épuisée.
    static func nextFreeAt(_ state: CollCorrectionQuotaState) -> Double? {
        guard state.used >= allowance, let last = state.lastConsumedAt else { return nil }
        return last + freeIntervalMilliseconds
    }

    /// `evaluateCorrectionAccess` : abonnement, allocation offerte, recharge des
    /// 48 heures, ou paywall.
    static func evaluate(
        _ state: CollCorrectionQuotaState,
        now: Double,
        subscribed: Bool
    ) -> CollCorrectionAccess {
        if subscribed { return .subscription }
        let remaining = remainingFree(state)
        if remaining > 0 { return .freeAllowance(remaining: remaining) }
        guard let nextAt = nextFreeAt(state), nextAt > now else { return .freeRefill }
        return .paywall(nextFreeAt: nextAt, waitMs: nextAt - now)
    }

    /// `consumeCorrection` : l'appelant a déjà vérifié l'accès, cette fonction
    /// enregistre seulement.
    static func consume(_ state: CollCorrectionQuotaState, now: Double) -> CollCorrectionQuotaState {
        CollCorrectionQuotaState(schemaVersion: 1, used: state.used + 1, lastConsumedAt: now)
    }

    /// `formatCorrectionWait` : délai lisible avant la prochaine correction
    /// offerte — « maintenant », des minutes, puis des heures.
    static func formatWait(_ waitMs: Double) -> String {
        if waitMs <= 0 { return "maintenant" }
        let minutes = Int((waitMs / 60_000).rounded(.up))
        if minutes < 60 { return "\(minutes) min" }
        let hours = Int((waitMs / 3_600_000).rounded(.up))
        return "\(hours) h"
    }

    /// `positiveInteger` : entier strictement positif, `0` sinon.
    private static func positiveInteger(_ value: Any?) -> Int {
        guard let number = value as? NSNumber, number.doubleValue.isFinite, number.doubleValue > 0
        else { return 0 }
        return Int(number.doubleValue.rounded(.down))
    }
}
