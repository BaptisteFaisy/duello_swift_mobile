import Foundation

/// Sélection du compte proposé au formulaire de connexion.
///
/// Porté de `src/utils/loginAccountSelection.ts` : la connexion publique propose
/// le premier compte **utilisateur** stocké, et jamais l'administrateur par
/// défaut ni une identité invitée. L'adresse administrateur reste saisissable
/// explicitement dans le formulaire commun.
///
/// Note de fidélité : la source ne modélise aucune notion de récence ; « le
/// compte proposé » est le premier utilisateur non invité dans l'ordre de
/// stockage, ce qui correspond au comportement de `preferredUserLoginAccount`.
enum AcctSecAccountSelection {
    /// Rôle d'un compte stocké (`AccountRole` de `src/utils/auth.ts`).
    enum Role: String, Equatable {
        case admin
        case user
    }

    /// Vue minimale d'un compte stocké, suffisante pour la sélection
    /// (`StoredAccount` de `src/utils/auth.ts`).
    struct StoredAccount: Identifiable, Equatable {
        let id: String
        let email: String
        let role: Role
        /// Compte local sans identifiants visibles (`guest` de `UserAccount`).
        var isGuest: Bool = false
    }

    /// Compte proposé par défaut : premier utilisateur non invité, ou `nil` si
    /// l'installation ne contient que l'administrateur ou des invités.
    static func preferredLoginAccount(from accounts: [StoredAccount]) -> StoredAccount? {
        accounts.first { $0.role == .user && !$0.isGuest }
    }
}
