//
//  AdmUserText.swift
//  Duello
//
//  Libellés dérivés d'un enregistrement utilisateur (registre admin).
//
//  Fichiers source Expo portés :
//    - src/admin/AdminUsersScreen.tsx (`formatPath`, `lastActivity`,
//      `searchableUser`, initiale d'avatar)
//    - src/admin/AdminFeedbackScreen.tsx (initiale d'avatar)
//    - src/admin/adminAnalytics.ts (`'Compte sans nom'`)
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Textes calculés à partir d'un `AdmUserRecord`.
enum AdmUserText {
    /// Initiale d'avatar : première lettre du nom, « U » par défaut.
    static func initial(for displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "U" }
        return String(first).uppercased()
    }

    /// `formatPath` : filière, année et prépa, ou mention explicite quand le
    /// compte n'a pas publié de profil dans l'annuaire.
    static func path(for user: AdmUserRecord) -> String {
        let parts = [user.track, user.year, user.prepName].filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return parts.isEmpty ? "Profil non publié dans l’annuaire" : parts.joined(separator: " · ")
    }

    /// `lastActivity` : dernier signe de vie connu (usage, feedback, mise à
    /// jour). Sémantique `??` du source : seule une valeur **absente** bascule
    /// sur l'étage suivant, une chaîne vide est retenue telle quelle.
    static func lastActivity(for user: AdmUserRecord) -> String? {
        user.usage?.lastSeenAt ?? user.lastFeedbackAt ?? user.updatedAt
    }

    /// `searchableUser` : concaténation insensible à la casse des champs de
    /// recherche de la liste des comptes.
    static func searchable(_ user: AdmUserRecord) -> String {
        let fields = [
            user.displayName,
            user.registrationEmail ?? "",
            user.prepName,
            user.className,
            user.track,
            user.year,
            user.targetSchool,
        ]
        return fields.joined(separator: " ").lowercased()
    }

    /// `'Compte sans nom'` de `adminAnalytics.ts` : nom d'affichage de repli.
    static func analyticsDisplayName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Compte sans nom" : trimmed
    }
}
