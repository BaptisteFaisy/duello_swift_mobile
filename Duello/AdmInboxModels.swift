//
//  AdmInboxModels.swift
//  Duello
//
//  Boîte de réception de l'administration : feedbacks, signalements de comptes
//  et de contenus, inscriptions à la liste d'attente.
//
//  Fichiers source Expo portés :
//    - src/admin/adminApi.ts                    (`AdminFeedbackRecord`,
//      `AdminExerciseReportRecord`, `AdminUserReportRecord`,
//      `AdminWaitlistEntry`)
//    - src/admin/AdminFeedbackScreen.tsx        (cartes de message)
//    - src/admin/AdminExerciseReportsScreen.tsx (`TARGET_LABEL`, `SOURCE_LABEL`,
//      `USER_REASON_LABEL`)
//    - src/admin/AdminWaitlistScreen.tsx        (cartes de contact)
//
//  Décodage **tolérant**, comme `Models.swift`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Message envoyé par un utilisateur (`AdminFeedbackRecord`).
struct AdmFeedbackRecord: Decodable, Identifiable, Equatable {
    var id: String = ""
    var userId: String = ""
    var displayName: String = ""
    var subject: String = ""
    var message: String = ""
    /// Adresse authentifiée du compte ayant envoyé le message.
    var accountEmail: String?
    /// Ancien champ libre, conservé pour les messages historiques.
    var contactEmail: String?
    var createdAt: String = ""

    enum CodingKeys: String, CodingKey {
        case id, userId, displayName, subject, message, accountEmail, contactEmail, createdAt
    }

    /// Adresse affichée : l'adresse authentifiée prime sur l'ancien champ libre.
    var contactAddress: String? {
        if let accountEmail, !accountEmail.isEmpty { return accountEmail }
        if let contactEmail, !contactEmail.isEmpty { return contactEmail }
        return nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        userId = (try? c.decode(String.self, forKey: .userId)) ?? ""
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        subject = (try? c.decode(String.self, forKey: .subject)) ?? ""
        message = (try? c.decode(String.self, forKey: .message)) ?? ""
        accountEmail = try? c.decodeIfPresent(String.self, forKey: .accountEmail)
        contactEmail = try? c.decodeIfPresent(String.self, forKey: .contactEmail)
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
    }
}

/// Signalement d'un exercice (`AdminExerciseReportRecord`).
struct AdmExerciseReportRecord: Decodable, Identifiable, Equatable {
    var id: String = ""
    var userId: String = ""
    var displayName: String = ""
    var target: AdmReportTarget = .statement
    var source: AdmReportSource = .training
    var exerciseId: String = ""
    var exerciseTitle: String = ""
    var subject: String = ""
    var message: String = ""
    var createdAt: String = ""

    enum CodingKeys: String, CodingKey {
        case id, userId, displayName, target, source, exerciseId, exerciseTitle
        case subject, message, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        userId = (try? c.decode(String.self, forKey: .userId)) ?? ""
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        let targetValue = (try? c.decode(String.self, forKey: .target)) ?? ""
        target = AdmReportTarget(rawValue: targetValue) ?? .statement
        let sourceValue = (try? c.decode(String.self, forKey: .source)) ?? ""
        source = AdmReportSource(rawValue: sourceValue) ?? .training
        exerciseId = (try? c.decode(String.self, forKey: .exerciseId)) ?? ""
        exerciseTitle = (try? c.decode(String.self, forKey: .exerciseTitle)) ?? ""
        subject = (try? c.decode(String.self, forKey: .subject)) ?? ""
        message = (try? c.decode(String.self, forKey: .message)) ?? ""
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
    }
}

/// Signalement d'un compte par un autre compte (`AdminUserReportRecord`).
struct AdmUserReportRecord: Decodable, Identifiable, Equatable {
    var id: String = ""
    var reporterId: String = ""
    var reportedId: String = ""
    var reporterDisplayName: String = ""
    var reportedDisplayName: String = ""
    var reason: AdmUserReportReason = .other
    var details: String = ""
    var createdAt: String = ""

    enum CodingKeys: String, CodingKey {
        case id, reporterId, reportedId, reporterDisplayName, reportedDisplayName
        case reason, details, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        reporterId = (try? c.decode(String.self, forKey: .reporterId)) ?? ""
        reportedId = (try? c.decode(String.self, forKey: .reportedId)) ?? ""
        reporterDisplayName = (try? c.decode(String.self, forKey: .reporterDisplayName)) ?? ""
        reportedDisplayName = (try? c.decode(String.self, forKey: .reportedDisplayName)) ?? ""
        let reasonValue = (try? c.decode(String.self, forKey: .reason)) ?? ""
        reason = AdmUserReportReason(rawValue: reasonValue) ?? .other
        details = (try? c.decode(String.self, forKey: .details)) ?? ""
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
    }
}

/// Cible d'un signalement de contenu (`TARGET_LABEL`).
enum AdmReportTarget: String {
    case statement, correction

    var label: String {
        switch self {
        case .statement: return "Énoncé"
        case .correction: return "Corrigé"
        }
    }
}

/// Origine d'un signalement de contenu (`SOURCE_LABEL`).
enum AdmReportSource: String {
    case training, challenge

    var label: String {
        switch self {
        case .training: return "Entraînement"
        case .challenge: return "Défi"
        }
    }
}

/// Motif d'un signalement de compte (`USER_REASON_LABEL`).
enum AdmUserReportReason: String {
    case harassment
    case spam
    case impersonation
    case inappropriateContent = "inappropriate-content"
    case other

    var label: String {
        switch self {
        case .harassment: return "Harcèlement ou menace"
        case .spam: return "Spam ou faux compte"
        case .impersonation: return "Usurpation d’identité"
        case .inappropriateContent: return "Contenu inapproprié"
        case .other: return "Autre raison"
        }
    }
}

/// Inscription à la liste d'attente du site (`AdminWaitlistEntry`).
struct AdmWaitlistEntry: Decodable, Identifiable, Equatable {
    var phone: String?
    var email: String?
    var school: String = ""
    var position: Int = 0
    var referrals: Int = 0
    var referredBy: String?
    var createdAt: String = ""

    /// Le serveur n'envoie pas d'identifiant : le contact, la date d'inscription
    /// et le rang identifient la ligne. Le rang est ajouté à la clé de liste du
    /// source pour garantir l'unicité quand deux contacts partagent la même date.
    var id: String { "\(phoneOrNil ?? "")|\(email ?? "")|\(createdAt)|\(position)" }

    enum CodingKeys: String, CodingKey {
        case phone, email, school, position, referrals, referredBy, createdAt
    }

    /// Téléphone renseigné : une chaîne vide vaut absence.
    var phoneOrNil: String? {
        guard let phone,
              !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return phone
    }

    /// Contact affiché : le téléphone prime sur l'adresse, comme l'écran Expo.
    /// Si les deux manquent — cas que le source rendrait par `null` — un libellé
    /// local explicite est affiché.
    var contact: String { phoneOrNil ?? email ?? "Contact inconnu" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        phone = try? c.decodeIfPresent(String.self, forKey: .phone)
        email = try? c.decodeIfPresent(String.self, forKey: .email)
        school = (try? c.decode(String.self, forKey: .school)) ?? ""
        position = (try? c.decode(Int.self, forKey: .position)) ?? 0
        referrals = (try? c.decode(Int.self, forKey: .referrals)) ?? 0
        referredBy = try? c.decodeIfPresent(String.self, forKey: .referredBy)
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
    }
}
