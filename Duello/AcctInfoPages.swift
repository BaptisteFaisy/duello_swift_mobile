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
/// `securityCard` de la source : fond blanc pleine largeur, sans bordure ni
/// séparateur.
struct AcctInfoMenuPage: View {
    let onSelect: (AcctInfoPage) -> Void

    /// Asset du logo cube Duello (`DUELLO_CUBE_LOGO_SOURCE`).
    static let duelloLogoAsset = "DuelloCubeLogo"

    var body: some View {
        VStack(spacing: 0) {
            AcctInfoCategoryRow(icon: "person", label: "Mes informations") { onSelect(.personal) }
            AcctInfoCategoryRow(icon: "gearshape", label: "Mon compte") { onSelect(.account) }
            AcctInfoCategoryRow(
                icon: "cube.transparent",
                assetIcon: Self.duelloLogoAsset,
                iconSize: AcctInfoRowMetrics.duelloLogoSize,
                label: "Duello"
            ) { onSelect(.duello) }
        }
        .background(Theme.surface)
    }
}

// MARK: - Page « Duello »

/// Préférences Duello : signalement de bug et documents légaux.
/// `duelloLegalGroup` de la source : `gap: 8`, sans carte ni séparateur.
struct AcctInfoDuelloPage: View {
    var onReportBug: () -> Void = {}
    var onOpenPrivacy: () -> Void = {}
    var onOpenTerms: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            AcctInfoActionRow(
                icon: "bubble.left.and.text.bubble.right",
                title: "Un bug ?",
                accessibilityLabel: "Signaler un bug",
                action: onReportBug
            )
            AcctInfoActionRow(
                icon: "checkmark.shield",
                title: "Politique de confidentialité",
                accessibilityLabel: "Consulter la politique de confidentialité",
                action: onOpenPrivacy
            )
            AcctInfoActionRow(
                icon: "doc.text",
                title: "Conditions d’utilisation",
                accessibilityLabel: "Consulter les conditions d’utilisation",
                action: onOpenTerms
            )
        }
        .background(Theme.surface)
    }
}

// MARK: - Page « informations personnelles »

/// Informations personnelles : nom affiché et année d'études.
/// `identityCard` de la source : fond blanc pleine largeur, lignes
/// `minHeight: 64`, `gap: 14`, `paddingHorizontal: 8`.
struct AcctInfoPersonalPage: View {
    @Binding var displayName: String
    @Binding var year: String
    var isGuest: Bool = false

    /// Années proposées par le menu déroulant (`years` de la source).
    private static let years = ["1re année", "2e année"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            nameField
            yearField
        }
        .background(Theme.surface)
    }

    /// Nom affiché : bouton photo 34 × 34 (badge caméra) et champ « Ex. Camille ».
    private var nameField: some View {
        HStack(spacing: 14) {
            profilePhotoButton
            TextField("Ex. Camille", text: $displayName)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .disabled(isGuest)
                .accessibilityLabel("Nom")
            Spacer(minLength: 8)
            if !isGuest {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 64)
        .padding(.horizontal, 8)
    }

    /// Bouton photo de profil (`profilePhotoButton`) : pastille 34 × 34, initiale
    /// 14 / 900, badge caméra 14 × 14 en bas-droite.
    private var profilePhotoButton: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Theme.primaryLight)
                .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1.5))
            Text(currentInitial)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
            Image(systemName: "camera")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 14, height: 14)
                .background(Circle().fill(Theme.primary))
                .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 2))
                .offset(x: 2, y: 2)
        }
        .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
        .accessibilityHidden(true)
    }

    /// Année d'études : menu déroulant, libellé d'action « Choisir mon année ».
    private var yearField: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: AcctInfoRowMetrics.iconSize, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
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
        .frame(minHeight: 64)
        .padding(.horizontal, 8)
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

    /// `informationContent` (`gap: 36`) puis `accountActionsGroup` (`gap: 8`).
    /// La carte sécurité est masquée en invité (`{!isGuest ? … : null}`).
    var body: some View {
        VStack(spacing: 36) {
            if !isGuest {
                securityCard
            }
            accountActions
        }
    }

    /// Sécurité : e-mail, mot de passe, connexion biométrique.
    /// `securityCard` de la source : fond blanc, sans bordure ni séparateur ;
    /// les lignes e-mail / mot de passe reprennent `passwordToggle` (60 / 10).
    private var securityCard: some View {
        VStack(spacing: 0) {
            AcctInfoActionRow(
                icon: "envelope",
                title: "Modifier mon adresse e-mail",
                metrics: .password,
                action: onOpenEmail
            )
            AcctInfoActionRow(
                icon: "key",
                title: "Modifier mon mot de passe",
                metrics: .password,
                action: onOpenPassword
            )
            AcctInfoToggleRow(
                icon: "touchid",
                title: "Connexion biométrique",
                isOn: Binding(get: { biometricEnabled }, set: onBiometricChange),
                accessibilityLabel: "Activer la connexion biométrique"
            )
        }
        .background(Theme.surface)
    }

    /// Actions du compte, dans l'ordre de la source (`accountActionsGroup`,
    /// `gap: 8`).
    private var accountActions: some View {
        VStack(spacing: 8) {
            ConsentAiCard(iconSize: AcctInfoRowMetrics.iconSize)
            NotificationSettingsCard(store: notificationStore, isGuest: isGuest)
            AcctInfoToggleRow(
                icon: "lock",
                title: "Compte privé",
                description: privateAccountDescription,
                isOn: $isPrivateAccount,
                accessibilityLabel: "Activer le compte privé"
            )
            communityCard
        }
    }

    /// `communityCard` de la source : « Comptes bloqués », puis — hors invité —
    /// la déconnexion (`marginTop: 36`) et la suppression (`marginTop: 16`),
    /// regroupées dans la même carte.
    private var communityCard: some View {
        VStack(spacing: 0) {
            AcctInfoActionRow(
                icon: "nosign",
                title: "Comptes bloqués",
                accessibilityLabel: "Gérer les comptes bloqués",
                action: onOpenBlocked
            )
            if !isGuest {
                AcctInfoLogoutRow(onLogout: onLogout)
                    .padding(.top, 36)
                AcctInfoDeleteRow(onDelete: onDeleteAccount)
                    .padding(.top, 16)
            }
        }
        .background(Theme.surface)
    }

    private var privateAccountDescription: String {
        isPrivateAccount
            ? "Tes performances ne sont plus publiées : tu restes visible sous « Anonyme » dans les classements."
            : "Tes performances sont visibles dans le fil et ton nom apparaît dans les classements."
    }
}
