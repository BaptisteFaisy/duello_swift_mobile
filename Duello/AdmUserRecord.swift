//
//  AdmUserRecord.swift
//  Duello
//
//  Un compte utilisateur **tel que le voit l'administration**.
//
//  Fichiers source Expo portés :
//    - src/admin/adminApi.ts          (`AdminUserRecord`, `performance`)
//    - src/admin/AdminUsersScreen.tsx (liste, recherche, détail)
//    - src/admin/adminAnalytics.ts    (agrégation par période)
//
//  Ce type appartient au registre admin : il ne remplace jamais `UserProfile`,
//  qui reste le modèle du registre utilisateur. Aucun champ de contenu scolaire
//  (réponses, brouillons, copies) n'y figure — le serveur n'en transmet pas.
//
//  Décodage **tolérant**, comme `Models.swift`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// `performance` : indicateurs de progression d'un compte.
struct AdmUserPerformance: Decodable, Equatable {
    var average: String?
    var trend: String?
    var gradeCount: Int?
    var completion: Double?
    var streak: Int?
    var xp: Int?

    enum CodingKeys: String, CodingKey {
        case average, trend, gradeCount, completion, streak, xp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        average = try? c.decodeIfPresent(String.self, forKey: .average)
        trend = try? c.decodeIfPresent(String.self, forKey: .trend)
        gradeCount = try? c.decodeIfPresent(Int.self, forKey: .gradeCount)
        completion = try? c.decodeIfPresent(Double.self, forKey: .completion)
        streak = try? c.decodeIfPresent(Int.self, forKey: .streak)
        xp = try? c.decodeIfPresent(Int.self, forKey: .xp)
    }
}

/// `AdminUserRecord` : une entrée du registre admin.
struct AdmUserRecord: Decodable, Identifiable, Equatable {
    var id: String = ""
    /// Adresse de connexion, transmise uniquement au registre admin.
    var registrationEmail: String?
    var displayName: String = ""
    var prepName: String = ""
    var className: String = ""
    /// Vide pour un compte connu par sa seule activité, sans profil publié.
    var track: String = ""
    var year: String = ""
    var targetSchool: String = ""
    var isPublic: Bool = false
    /// `false` quand le compte n'apparaît pas dans l'annuaire public.
    var listed: Bool?
    var createdAt: String?
    var updatedAt: String?
    var lastFeedbackAt: String?
    var performance: AdmUserPerformance?
    /// `null` pour un compte connu par sa seule activité, sans profil publié.
    var usage: AdmUsageAnalytics?

    enum CodingKeys: String, CodingKey {
        case id, registrationEmail, displayName, prepName, className, track, year
        case targetSchool, isPublic, listed, createdAt, updatedAt, lastFeedbackAt
        case performance, usage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        registrationEmail = try? c.decodeIfPresent(String.self, forKey: .registrationEmail)
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        prepName = (try? c.decode(String.self, forKey: .prepName)) ?? ""
        className = (try? c.decode(String.self, forKey: .className)) ?? ""
        track = (try? c.decode(String.self, forKey: .track)) ?? ""
        year = (try? c.decode(String.self, forKey: .year)) ?? ""
        targetSchool = (try? c.decode(String.self, forKey: .targetSchool)) ?? ""
        isPublic = (try? c.decode(Bool.self, forKey: .isPublic)) ?? false
        listed = try? c.decodeIfPresent(Bool.self, forKey: .listed)
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try? c.decodeIfPresent(String.self, forKey: .updatedAt)
        lastFeedbackAt = try? c.decodeIfPresent(String.self, forKey: .lastFeedbackAt)
        performance = try? c.decodeIfPresent(AdmUserPerformance.self, forKey: .performance)
        usage = try? c.decodeIfPresent(AdmUsageAnalytics.self, forKey: .usage)
    }
}
