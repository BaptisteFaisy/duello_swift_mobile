//
//  PremCodeAPI.swift
//  Duello
//
//  Accès réseau du lot « code premium » : rédemption d’un code d’affiliation
//  et lecture de l’abonnement distant.
//
//  Fichiers source Expo portés :
//    - `src/utils/premiumCodeRedemptionApi.ts` (`redeemPremiumCode`) ;
//    - `src/utils/premiumCodeRedemptionResponse.ts` (validation stricte de
//      l’attribution affiliée) ;
//    - `src/utils/remoteSubscription.ts` (`RemoteSubscription`, validation) ;
//    - `src/utils/socialApi.ts` (`fetchRemoteSubscription`, `publicProfileId`).
//
//  `DuelloAPI.request(...)` reste le seul transport ; ce fichier n’ajoute que
//  les points d’entrée manquants et la validation des réponses.
//
//  Cible : iOS 16.
//
import Foundation

/// Helpers réseau locaux du code d’affiliation et de l’abonnement distant.
enum PremCodeAPI {
    /// `AffiliateCodeAttribution` : identifiant **public** de l’affilié
    /// uniquement, jamais un identifiant interne.
    struct Attribution: Equatable {
        let applied: Bool
        let affiliatePublicId: String
        let attributedAt: Double
    }

    /// `RemoteSubscription` : droit Premium tel que le serveur le décrit.
    struct RemoteSubscription: Equatable {
        var paid: Bool
        var renewsAt: Double?
        var firstPaidAt: Double?
        var authoritative: Bool
        var resetAt: Double?
        var trialStartsAt: Double?

        /// `NO_REMOTE_SUBSCRIPTION`.
        static let none = RemoteSubscription(
            paid: false, renewsAt: nil, firstPaidAt: nil,
            authoritative: false, resetAt: nil, trialStartsAt: nil)
    }

    /// `redeemPremiumCode` : `POST /affiliate-codes/redeem`, corps `{ code }`.
    /// Un compte inscrit (e-mail non vide) est requis.
    static func redeem(email: String, token: String?, code: String) async throws -> Attribution {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DirectoryError(message: "Un compte inscrit est requis.", status: 403)
        }
        let body = try DuelloAPI.encodeBody(["code": code])
        let data = try await DuelloAPI.request(
            "affiliate-codes/redeem", method: "POST", token: token, body: body)
        return try parseAttribution(data)
    }

    /// `fetchRemoteSubscription` : `GET /subscription?userId=member-…`.
    static func fetchRemoteSubscription(
        email: String,
        token: String?
    ) async throws -> RemoteSubscription {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .none }
        let data = try await DuelloAPI.request(
            "subscription",
            token: token,
            query: [URLQueryItem(
                name: "userId",
                value: DuelloAPI.publicProfileId(email: trimmed))])
        return parseRemoteSubscription(data)
    }

    /// `parseAffiliateCodeAttributionResponse` : refuse toute attribution
    /// partielle ou liée à un identifiant non public.
    static func parseAttribution(_ data: Data) throws -> Attribution {
        guard let envelope = try? DuelloAPI.decoder.decode(AttributionEnvelope.self, from: data),
              let attribution = envelope.attribution,
              let attributedAt = safeTimestamp(attribution.attributedAt),
              isPublicMemberId(attribution.affiliatePublicId) else {
            throw DirectoryError(message: "Réponse d’utilisation du code d’affiliation illisible.")
        }
        return Attribution(
            applied: attribution.applied,
            affiliatePublicId: attribution.affiliatePublicId,
            attributedAt: attributedAt)
    }

    /// `parseRemoteSubscription` : valide la forme complète renvoyée par
    /// l’autorité ; une réponse douteuse devient `NO_REMOTE_SUBSCRIPTION`.
    static func parseRemoteSubscription(_ data: Data) -> RemoteSubscription {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["subscription"] as? [String: Any],
              let paid = raw["paid"] as? Bool,
              let authoritative = raw["authoritative"] as? Bool,
              let renewsAt = optionalTimestamp(raw["renewsAt"]),
              let firstPaidAt = optionalTimestamp(raw["firstPaidAt"]),
              let resetAt = optionalTimestamp(raw["resetAt"]),
              let trialStartsAt = optionalTimestamp(raw["trialStartsAt"]) else {
            return .none
        }
        return RemoteSubscription(
            paid: paid && renewsAt != nil,
            renewsAt: renewsAt,
            firstPaidAt: firstPaidAt,
            authoritative: authoritative,
            resetAt: resetAt,
            trialStartsAt: trialStartsAt)
    }

    /// Enveloppe `{ "attribution": { … } }` de la réponse de rédemption.
    private struct AttributionEnvelope: Decodable {
        let attribution: Payload?

        struct Payload: Decodable {
            let applied: Bool
            let affiliatePublicId: String
            let attributedAt: Double
        }
    }

    /// `timestamp` de la réponse d’attribution : entier sûr strictement positif.
    private static func safeTimestamp(_ value: Double) -> Double? {
        guard value > 0, value.rounded() == value, value <= 9_007_199_254_740_991 else { return nil }
        return value
    }

    /// `optionalTimestamp` : `null` explicite → `nil` ; nombre fini positif →
    /// valeur plancher ; absent ou illisible → rejet (`.none` en amont).
    private static func optionalTimestamp(_ value: Any?) -> Double?? {
        if value is NSNull { return .some(nil) }
        guard let number = value as? Double, number.isFinite, number > 0 else { return nil }
        return .some(number.rounded(.down))
    }

    /// `/^member-[a-f0-9]+$/` : jamais un identifiant interne.
    private static func isPublicMemberId(_ value: String) -> Bool {
        let prefix = "member-"
        guard value.hasPrefix(prefix) else { return false }
        let hex = value.dropFirst(prefix.count)
        let allowed = Set("0123456789abcdef")
        return !hex.isEmpty && hex.allSatisfy { allowed.contains($0) }
    }
}
