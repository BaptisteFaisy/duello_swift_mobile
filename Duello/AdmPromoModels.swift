//
//  AdmPromoModels.swift
//  Duello
//
//  Codes promotionnels et exception d'inscription, côté administration.
//
//  Fichiers source Expo portés :
//    - src/admin/adminApi.ts                (`AdminPromoCodeStat`,
//      `AdminPromoCodeCreateInput`, `AdminRegistrationIpAccess`)
//    - src/admin/AdminPromoCodesScreen.tsx  (liste, création, activation)
//    - src/admin/AdminApp.tsx               (exception d'inscription par adresse)
//
//  Décodage **tolérant**, comme `Models.swift`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Statistiques d'un code promo (`AdminPromoCodeStat`).
struct AdmPromoCodeStat: Decodable, Identifiable, Equatable {
    /// Index lisible du code, jamais le code brut (stocké uniquement haché).
    var codeHint: String = ""
    var label: String = ""
    var percentOff: Int = 0
    /// `null` quand le nombre d'utilisations n'est pas borné.
    var maxRedemptions: Int?
    var useCount: Int = 0
    /// Nombre de personnes réellement passées par ce code.
    var peopleCount: Int = 0
    var disabled: Bool = false
    var startsAt: Double = 0
    var expiresAt: Double?
    var createdAt: Double = 0

    var id: String { codeHint }

    enum CodingKeys: String, CodingKey {
        case codeHint, label, percentOff, maxRedemptions, useCount, peopleCount
        case disabled, startsAt, expiresAt, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        codeHint = (try? c.decode(String.self, forKey: .codeHint)) ?? ""
        label = (try? c.decode(String.self, forKey: .label)) ?? ""
        percentOff = (try? c.decode(Int.self, forKey: .percentOff)) ?? 0
        maxRedemptions = try? c.decodeIfPresent(Int.self, forKey: .maxRedemptions)
        useCount = (try? c.decode(Int.self, forKey: .useCount)) ?? 0
        peopleCount = (try? c.decode(Int.self, forKey: .peopleCount)) ?? 0
        disabled = (try? c.decode(Bool.self, forKey: .disabled)) ?? false
        startsAt = (try? c.decode(Double.self, forKey: .startsAt)) ?? 0
        expiresAt = try? c.decodeIfPresent(Double.self, forKey: .expiresAt)
        createdAt = (try? c.decode(Double.self, forKey: .createdAt)) ?? 0
    }
}

/// Charge utile de création d'un code promo (`AdminPromoCodeCreateInput`).
/// Encodée telle quelle vers `POST /admin/promo-codes`.
struct AdmPromoCodeCreateInput: Encodable, Equatable {
    var code: String
    var label: String
    var percentOff: Int
    /// Absent quand le nombre d'utilisations est illimité.
    var maxRedemptions: Int?
    /// Absent quand le code n'expire pas.
    var expiresAt: Double?

    enum CodingKeys: String, CodingKey {
        case code, label, percentOff, maxRedemptions, expiresAt
    }
}

/// Exception d'inscription multiple depuis l'adresse réseau courante
/// (`AdminRegistrationIpAccess`).
struct AdmRegistrationIpAccess: Decodable, Equatable {
    var currentIp: String
    var unlimited: Bool

    enum CodingKeys: String, CodingKey {
        case currentIp, unlimited
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let ip = try? c.decode(String.self, forKey: .currentIp),
              let flag = try? c.decode(Bool.self, forKey: .unlimited) else {
            throw AdmAPIError.unreadable
        }
        currentIp = ip
        unlimited = flag
    }
}
