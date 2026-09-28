//
//  LoginScrProviderReuse.swift
//  Duello
//
//  Port de src/utils/providerAccountReuse.ts (RN) — réouverture du compte
//  existant après une authentification fournisseur (Google / Apple).
//
//  Une connexion fournisseur en pleine création de compte rouvre l'ancien
//  compte lié à l'identité et jette toute l'inscription (filière, année,
//  option, pseudo saisi). Sur l'écran de connexion c'est l'effet attendu ;
//  pendant une création explicite (`signup`), l'utilisateur croit créer son
//  nouveau programme puis retrouve son ancien profil : demander confirmation.
//
//  Réductions assumées (iOS), notées le 28/09/2026 :
//    - `providerAccountSummary` appelle, dans la source,
//      `academicProgramSelection(profile, toProgramYear(profile.year))` puis
//      `accountAcademicOptionLabel(profile.track, selection.specialty,
//      profile.specialty)`. Le port lit l'option de l'année affichée dans le
//      champ `academicPath` du profil (`firstYearOption` en 1re année,
//      `currentOption` sinon) et retombe sur `specialty` quand ce parcours
//      détaillé manque (comptes anciens) : `normalizeAcademicPath` de la source,
//      qui le reconstruit, n'est pas porté ici (module académique partagé,
//      `OnbFlowAcademic`). Le repli ECG de `accountAcademicOptionLabel`
//      (« Maths appliquées » / « Maths approfondies ») reste porté à l'identique.
//    - `toLocaleLowerCase('fr-FR')` de la source est rendu par `lowercased()` :
//      les fragments testés (« appliqu », « approfond ») sont ASCII, le
//      résultat est identique.
//    - `ProviderAuthFollowUp` (`'declined' | void`) devient `ProviderAuthFollowUp?` :
//      `nil` correspond au `void` de la source, `.declined` au refus de rouvrir.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// `ProviderAuthFollowUp` de `utils/providerAccountReuse.ts`.
///
/// Suite donnée par l'application après une authentification fournisseur.
/// `.declined` : l'utilisateur a refusé de rouvrir son ancien compte,
/// l'inscription en cours continue sans lier l'identité. L'absence de valeur
/// (`nil`) correspond au `void` de la source.
enum ProviderAuthFollowUp: Equatable {
    case declined
}

/// Règles pures de la réouverture du compte existant après une connexion
/// fournisseur (`utils/providerAccountReuse.ts`). Aucun accès réseau ni
/// stockage : module vérifiable hors application.
enum LoginScrProviderReuse {
    /// Fournisseur à l'origine de la connexion (`provider` de la source).
    enum Provider: String {
        case google = "Google"
        case apple = "Apple"
    }

    /// `ProviderLoginContext` de `utils/providerAccountReuse.ts`.
    struct ProviderLoginContext: Equatable {
        var hasActiveSession: Bool
        var authStage: String
        var upgradingGuest: Bool
        var resolutionKind: String
    }

    /// `shouldConfirmProviderLogin` : faut-il demander confirmation avant de
    /// rouvrir l'ancien compte ? Uniquement quand le serveur a résolu une
    /// **connexion** vers un compte existant pendant une création explicite
    /// (`signup` / `guest`), sans session active ni montée en gamme d'invité
    /// (celle-ci garde son comportement dédié : ses données sont copiées vers
    /// le compte retrouvé).
    static func shouldConfirmProviderLogin(_ context: ProviderLoginContext) -> Bool {
        if context.resolutionKind != "login" { return false }
        if context.hasActiveSession { return false }
        if context.upgradingGuest { return false }
        return context.authStage == "signup" || context.authStage == "guest"
    }

    /// `providerAccountSummary` : résumé reconnaissable du compte retrouvé, avec
    /// le même libellé d'option que l'écran de profil.
    static func providerAccountSummary(_ profile: UserProfile) -> String {
        let trimmed = profile.displayName.trimmingCharacters(in: .whitespaces)
        let name = trimmed.isEmpty ? "Sans pseudo" : trimmed
        let option = accountAcademicOptionLabel(
            track: profile.track,
            currentOption: selectedOption(profile),
            legacySpecialty: profile.specialty
        )
        return option.isEmpty
            ? "« \(name) » (\(profile.year))"
            : "« \(name) » (\(profile.year) • \(option))"
    }

    /// `academicProgramSelection(profile, toProgramYear(profile.year)).specialty`
    /// (`utils/academicPath.ts:309-330`) : option de l'année affichée — celle de
    /// 1re année pour un élève de 1re année (`toProgramYear` renvoie 1), l'option
    /// courante sinon. La source lit le parcours **normalisé** ; le port lit
    /// `academicPath` en priorité et retombe sur `specialty` (comptes anciens
    /// sans parcours détaillé).
    private static func selectedOption(_ profile: UserProfile) -> String {
        guard let path = profile.academicPath else { return profile.specialty }
        return profile.year == "1re année" ? path.firstYearOption : path.currentOption
    }

    /// `providerReuseDialogCopy` : titre et message du dialogue de confirmation.
    static func providerReuseDialogCopy(
        provider: Provider,
        summary: String
    ) -> (title: String, message: String) {
        (
            title: "Compte déjà existant",
            message: "Le compte \(summary) existe déjà avec ce compte \(provider.rawValue). "
                + "L’ouvrir ? La création en cours sera abandonnée."
        )
    }

    /// `accountAcademicOptionLabel` (`utils/accountAcademicOption.ts`) : valeur
    /// lisible de l'option, repli sur la spécialité héritée, et libellés ECG
    /// canoniques pour les anciennes spécialités libres.
    static func accountAcademicOptionLabel(
        track: String,
        currentOption: String,
        legacySpecialty: String
    ) -> String {
        let current = currentOption.trimmingCharacters(in: .whitespaces)
        let option = current.isEmpty
            ? legacySpecialty.trimmingCharacters(in: .whitespaces)
            : current
        guard !option.isEmpty, track == "ECG" else { return option }

        let normalized = option.lowercased()
        if normalized.contains("appliqu") { return "Maths appliquées" }
        if normalized.contains("approfond") { return "Maths approfondies" }
        return option
    }
}
