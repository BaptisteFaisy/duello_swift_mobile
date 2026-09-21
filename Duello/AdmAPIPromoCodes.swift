//
//  AdmAPIPromoCodes.swift
//  Duello
//
//  Codes promotionnels côté administration.
//
//  Fichier source Expo porté : src/admin/adminApi.ts (`listAdminPromoCodes`,
//  `createAdminPromoCode`, `setAdminPromoCodeDisabled`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

extension AdmAPI {
    /// `GET /admin/promo-codes` (`listAdminPromoCodes`).
    static func listPromoCodes(token: String) async throws -> [AdmPromoCodeStat] {
        let data = try await request("admin/promo-codes", token: token)
        let envelope = try? DuelloAPI.decoder.decode(PromoCodesEnvelope.self, from: data)
        return envelope?.codes ?? []
    }

    /// `POST /admin/promo-codes` (`createAdminPromoCode`).
    static func createPromoCode(token: String, input: AdmPromoCodeCreateInput) async throws {
        let body = try DuelloAPI.encodeBody(input)
        _ = try await request("admin/promo-codes", token: token, method: "POST", body: body)
    }

    /// `PATCH /admin/promo-codes` (`setAdminPromoCodeDisabled`).
    static func setPromoCodeDisabled(
        token: String,
        codeHint: String,
        disabled: Bool
    ) async throws {
        let body = try DuelloAPI.encodeBody(PromoCodeToggle(codeHint: codeHint, disabled: disabled))
        _ = try await request("admin/promo-codes", token: token, method: "PATCH", body: body)
    }

    /// Enveloppe `{ codes: [...] }`.
    private struct PromoCodesEnvelope: Decodable {
        var codes: [AdmPromoCodeStat]?
    }

    /// Corps de `PATCH /admin/promo-codes`.
    private struct PromoCodeToggle: Encodable {
        var codeHint: String
        var disabled: Bool
    }
}
