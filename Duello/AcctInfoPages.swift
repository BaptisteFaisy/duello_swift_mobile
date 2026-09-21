//
//  AcctInfoPages.swift
//  Duello
//
//  Lot 10-C « réglages informations » (préfixe `AcctInfo`).
//  Les quatre surfaces visibles du menu « informations ».
//
//  Fichiers source Expo portés :
//    - src/screens/AccountScreen.tsx (3590-4132) : `informationSettingsPage`
//      (`'menu' | 'duello' | 'personal' | 'account'`) et le rendu des quatre
//      pages — menu des catégories, préférences Duello (liens légaux + bug),
//      informations personnelles (nom + année), compte (sécurité + actions) ;
//    - src/utils/settingsTabSwipe.ts / notificationsTabSwipe.ts : rubans déjà
//      portés par `SwipeSettingsTabs` / `SwipeNotificationsTabs`, seulement
//      réexposés ici (aucune duplication).
//
//  ⚠️ Les plages de lignes annoncées par le brief (371-383, 496-1600) ne
//  contiennent, dans le fichier courant, que les constantes de ruban et les
//  hooks du méga-composant : le JSX des quatre pages vit en réalité en
//  3590-4132. Le portage suit donc les surfaces réellement rendues.
//
//  Limite documentée : `AccountView.swift` porte déjà une version réduite du
//  profil (parcours, année, prépa) et n'est pas modifié ; cette tranche ajoute
//  la variante « réglages » à libellés exacts, sans la remplacer.
//
import SwiftUI

// MARK: - Navigation

/// Page de réglages « informations » (`InformationSettingsPage`).
enum AcctInfoPage: String, CaseIterable, Identifiable, Equatable {
    case menu
    case duello
    case personal
    case account

    var id: String { rawValue }

    /// Titre de barre pour les sous-pages ; `nil` pour le menu racine.
    var navigationTitle: String? {
        switch self {
        case .menu: return nil
        case .duello: return "Duello"
        case .personal: return "Mes informations"
        case .account: return "Mon compte"
        }
    }
}

/// Ruban de swipe des réglages (`SETTINGS_SWIPE_PAGES`,
/// `SETTINGS_INSTANT_PAGE_TRANSITIONS`) : délégué à `SwipeSettingsTabs`.
enum AcctInfoSettingsTabs {
    static var pages: [SwipeSettingsTabs.Page] { SwipeSettingsTabs.pages }
    static var instantTransitions: [SwipeOrderedTabs.InstantTransition] { SwipeSettingsTabs.instantTransitions }
    static func pageIndex(for page: SwipeSettingsTabs.Page) -> Int { SwipeSettingsTabs.pageIndex(for: page) }
}

/// Ruban de swipe des notifications (`NOTIFICATIONS_SWIPE_PAGES`) : délégué à
/// `SwipeNotificationsTabs`, qui en détient déjà l'ordre.
enum AcctInfoNotificationsTabs {
    static var pages: [SwipeNotificationsPage] { SwipeNotificationsTabs.pages }
}

// MARK: - Page « menu »

/// Menu racine : trois accès — Mes informations, Mon compte, Duello.
struct AcctInfoMenuPage: View {
    let onSelect: (AcctInfoPage) -> Void

    /// Asset du logo cube Duello (`DUELLO_CUBE_LOGO_SOURCE`).
    static let duelloLogoAsset = "DuelloCubeLogo"

    var body: some View {
        VStack(spacing: 0) {
            AcctInfoCategoryRow(icon: "person", label: "Mes informations") { onSelect(.personal) }
            Divider().padding(.leading, AcctInfoRowMetrics.separatorInset)
            AcctInfoCategoryRow(icon: "gearshape", label: "Mon compte") { onSelect(.account) }
            Divider().padding(.leading, AcctInfoRowMetrics.separatorInset)
            AcctInfoCategoryRow(
                icon: "cube.transparent",
                assetIcon: Self.duelloLogoAsset,
                iconSize: AcctInfoRowMetrics.duelloLogoSize,
                label: "Duello"
            ) { onSelect(.duello) }
        }
        .duelloCard()
    }
}

// MARK: - Page « Duello »

/// Préférences Duello : signalement de bug et documents légaux.
struct AcctInfoDuelloPage: View {
    var onReportBug: () -> Void = {}
    var onOpenPrivacy: () -> Void = {}
    var onOpenTerms: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            AcctInfoActionRow(
                icon: "bubble.left.and.text.bubble.right",
                title: "Un bug ?",
                accessibilityLabel: "Signaler un bug",
                action: onReportBug
            )
            Divider().padding(.leading, AcctInfoRowMetrics.separatorInset)
            AcctInfoActionRow(
                icon: "checkmark.shield",
                title: "Politique de confidentialité",
                accessibilityLabel: "Consulter la politique de confidentialité",
                action: onOpenPrivacy
            )
            Divider().padding(.leading, AcctInfoRowMetrics.separatorInset)
            AcctInfoActionRow(
                icon: "doc.text",
                title: "Conditions d’utilisation",
                accessibilityLabel: "Consulter les conditions d’utilisation",
                action: onOpenTerms
            )
        }
        .duelloCard()
    }
}

// MARK: - Page « informations personnelles »

/// Informations personnelles : nom affiché et année d'études.
struct AcctInfoPersonalPage: View {
    @Binding var displayName: String
    @Binding var year: String
    var isGuest: Bool = false

    /// Années proposées par le menu déroulant (`years` de la source).
    private static let years = ["1re année", "2e année"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            nameField
            Divider()
            yearField
        }
        .duelloCard()
    }

    /// Nom affiché : avatar à initiale, libellé « Nom », champ « Ex. Camille ».
    private var nameField: some View {
        HStack(spacing: 12) {
            DuelloAvatar(initial: currentInitial, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text("Nom")
                    .font(.system(size: 11, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkFaint)
                TextField("Ex. Camille", text: $displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .disabled(isGuest)
                    .accessibilityLabel("Nom")
            }
            Spacer(minLength: 8)
            if !isGuest {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Année d'études : menu déroulant, libellé d'action « Choisir mon année ».
    private var yearField: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: AcctInfoRowMetrics.iconSize, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: AcctInfoRowMetrics.iconColumn)
            Menu {
                ForEach(Self.years, id: \.self) { value in
                    Button(value) { year = value }
                }
            } label: {
                HStack {
                    Text(year.isEmpty ? "Choisir mon année" : year)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(year.isEmpty ? Theme.inkFaint : Theme.ink)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Choisir mon année")
        }
    }

    private var currentInitial: String {
        let source = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((source.isEmpty ? "P" : source).prefix(1)).uppercased()
    }
}

// MARK: - Page « compte »

/// Compte : sécurité (e-mail, mot de passe, biométrie) puis actions
/// (consentement IA, notifications, compte privé, comptes bloqués,
/// déconnexion, suppression). `ConsentAiCard` et `NotificationSettingsCard`
/// sont des briques existantes, réutilisées telles quelles.
struct AcctInfoAccountPage: View {
    @ObservedObject var notificationStore: NotificationPreferencesStore
    var isGuest: Bool = false
    var biometricEnabled: Bool = false
    var onBiometricChange: (Bool) -> Void = { _ in }
    var onOpenEmail: () -> Void = {}
    var onOpenPassword: () -> Void = {}
    var onOpenBlocked: () -> Void = {}
    var onLogout: () -> Void = {}
    var onDeleteAccount: () -> Void = {}

    /// Off par défaut : le compte est public (source).
    @State private var isPrivateAccount = false

    var body: some View {
        VStack(spacing: 14) {
            securityCard
            accountActions
        }
    }

    /// Sécurité : e-mail, mot de passe, connexion biométrique.
    private var securityCard: some View {
        VStack(spacing: 0) {
            AcctInfoActionRow(
                icon: "envelope",
                title: "Modifier mon adresse e-mail",
                action: onOpenEmail
            )
            Divider().padding(.leading, AcctInfoRowMetrics.separatorInset)
            AcctInfoActionRow(
                icon: "key",
                title: "Modifier mon mot de passe",
                action: onOpenPassword
            )
            Divider().padding(.leading, AcctInfoRowMetrics.separatorInset)
            AcctInfoToggleRow(
                icon: "touchid",
                title: "Connexion biométrique",
                isOn: Binding(get: { biometricEnabled }, set: onBiometricChange),
                accessibilityLabel: "Activer la connexion biométrique"
            )
        }
        .duelloCard()
    }

    /// Actions du compte, dans l'ordre de la source.
    private var accountActions: some View {
        VStack(spacing: 14) {
            ConsentAiCard(iconSize: AcctInfoRowMetrics.iconSize)
            NotificationSettingsCard(store: notificationStore, isGuest: isGuest)
            AcctInfoToggleRow(
                icon: "lock",
                title: "Compte privé",
                description: privateAccountDescription,
                isOn: $isPrivateAccount,
                accessibilityLabel: "Activer le compte privé"
            )
            AcctInfoActionRow(
                icon: "nosign",
                title: "Comptes bloqués",
                accessibilityLabel: "Gérer les comptes bloqués",
                action: onOpenBlocked
            )
            if !isGuest {
                AcctInfoLogoutRow(onLogout: onLogout)
                AcctInfoDeleteRow(onDelete: onDeleteAccount)
            }
        }
    }

    private var privateAccountDescription: String {
        isPrivateAccount
            ? "Tes performances ne sont plus publiées : tu restes visible sous « Anonyme » dans les classements."
            : "Tes performances sont visibles dans le fil et ton nom apparaît dans les classements."
    }
}
