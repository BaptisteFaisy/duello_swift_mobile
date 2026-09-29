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
//      informations personnelles (nom + année + filière PSI), compte
//      (sécurité + actions) ;
//    - src/utils/settingsTabSwipe.ts / notificationsTabSwipe.ts : rubans déjà
//      portés par `SwipeSettingsTabs` / `SwipeNotificationsTabs`, seulement
//      réexposés ici (aucune duplication).
//
//  Limite documentée : `AccountView.swift` porte déjà une version réduite du
//  profil (parcours, année, prépa) et n'est pas modifié ; cette tranche ajoute
//  la variante « réglages » à libellés exacts, sans la remplacer.
//
//  V1 (2026-09-26) — écart U08#2 : `AcctInfoAccountPage.onDeleteAccount`
//  devient asynchrone et faillible (suppression réelle du compte).
//
//  V3 (2026-09-29) — écart U08#54 « logo cube Duello » : la source RN affiche
//  `assets/duello-logo.png` (arêtes noires sur fond blanc, `AccountScreen.tsx:104`)
//  devant la ligne « Duello ». Ce PNG n'est pas présent dans le bundle Swift
//  (Assets.xcassets ne porte que `DuelloLogo`, la variante blanche) et l'asset
//  `DuelloCubeLogo` n'existe pas : `UIImage(named:)` renvoie `nil` et l'ancien
//  repli `icon: "cube.transparent"` — un nom SF Symbols, pas Ionicons — ne
//  rendait **rien**. Le repli est désormais le glyphe Ionicons `cube-outline`
//  (cube isométrique, équivalent visuel) ; si le PNG cube est un jour embarqué
//  sous `DuelloCubeLogo`, `AcctInfoCategoryRow` le prendra automatiquement.
//  Écart assumé : le glyphe vectoriel remplace le PNG (aucun asset ajoutable ici).
//
//  V2 (2026-09-28) — parité Swift↔RN :
//    - #17/#18/#27 : le nom et l'année sont liés au profil (persistance) et le
//      changement d'année recalcule la filière (`changeDraftYear`) ;
//    - #19 : bloc « Filière de 1re/2e année » pour un élève PSI ;
//    - #20 : le bouton photo ouvre `PhotoPickSheet` (portage du sélecteur RN) ;
//    - #21 : bascule biométrique branchée sur `AcctSecBiometricPolicy` ;
//    - #22/#23 : encre/danger exacts des lignes ;
//    - #51 : icônes `IonIcon` (noms RN) au lieu de SF Symbols ;
//    - #53 : dropdown maison (overlay + coche) au lieu d'un `Menu` natif.
//
import SwiftUI
import UIKit

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

    /// Asset du logo cube Duello (`DUELLO_CUBE_LOGO_SOURCE`, `assets/duello-logo.png`).
    static let duelloLogoAsset = "DuelloCubeLogo"

    /// Repli si l'asset cube n'est pas dans le bundle : glyphe Ionicons
    /// équivalent (cube isométrique). Un nom SF Symbols ici ne rendrait rien
    /// (`IonIcon` ne lit que la table Ionicons).
    static let duelloLogoFallbackIcon = "cube-outline"

    var body: some View {
        VStack(spacing: 0) {
            AcctInfoCategoryRow(icon: "person-outline", label: "Mes informations") { onSelect(.personal) }
            AcctInfoCategoryRow(icon: "settings-outline", label: "Mon compte") { onSelect(.account) }
            AcctInfoCategoryRow(
                icon: Self.duelloLogoFallbackIcon,
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
                icon: "chatbubble-ellipses-outline",
                title: "Un bug ?",
                accessibilityLabel: "Signaler un bug",
                action: onReportBug
            )
            AcctInfoActionRow(
                icon: "shield-checkmark-outline",
                title: "Politique de confidentialité",
                accessibilityLabel: "Consulter la politique de confidentialité",
                action: onOpenPrivacy
            )
            AcctInfoActionRow(
                icon: "document-text-outline",
                title: "Conditions d’utilisation",
                accessibilityLabel: "Consulter les conditions d’utilisation",
                action: onOpenTerms
            )
        }
        .background(Theme.surface)
    }
}

// MARK: - Page « informations personnelles »

/// Informations personnelles : nom affiché, année d'études et — pour un élève
/// PSI — filières de 1re et 2e année. `identityCard` de la source : fond blanc
/// pleine largeur, lignes `minHeight: 64`, `gap: 14`, `paddingHorizontal: 8`.
struct AcctInfoPersonalPage: View {
    @Binding var displayName: String
    var firstName: String = ""
    let year: String
    /// Filière suivie normalisée (`draftAcademicPath.currentTrack`).
    var currentTrack: String = ""
    /// Filière de 1re année (`draftAcademicPath.firstYearTrack`).
    var firstYearTrack: String = ""
    var photoUri: String? = nil
    var isGuest: Bool = false
    var onYearChange: (String) -> Void = { _ in }
    var onOriginChange: (String) -> Void = { _ in }
    var onPhotoChange: (String?) -> Void = { _ in }

    /// Années proposées par le menu déroulant (`years` de la source).
    private static let years = ["1re année", "2e année"]

    @State private var photoPickerOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            nameField
            yearField
            if currentTrack == "PSI" {
                psiTrackCard
            }
        }
        .background(Theme.surface)
        .sheet(isPresented: $photoPickerOpen) {
            PhotoPickSheet(currentPhotoUri: photoUri, onCommit: onPhotoChange)
        }
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
                IonIcon(name: "create-outline", size: 16, color: Theme.inkSoft)
            }
        }
        .frame(minHeight: 64)
        .padding(.horizontal, 8)
    }

    /// Bouton photo de profil (`profilePhotoButton`) : ouvre le sélecteur,
    /// pastille 34 × 34, initiale 14 / 900, badge caméra 14 × 14 en bas-droite.
    private var profilePhotoButton: some View {
        Button { photoPickerOpen = true } label: {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Theme.primaryLight)
                    .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                    .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1.5))
                photoContent
                IonIcon(name: "camera", size: 8, color: .white)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(Theme.primary))
                    .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 2))
                    .offset(x: 2, y: 2)
            }
            .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photoUri == nil ? "Ajouter une photo de profil" : "Modifier ma photo de profil")
    }

    /// Miniature publiée si présente, sinon l'initiale du nom.
    @ViewBuilder private var photoContent: some View {
        if let image = decodedPhoto {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                .clipShape(Circle())
        } else {
            Text(currentInitial)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
        }
    }

    /// Miniature JPEG `data:` du profil, décodée en image.
    private var decodedPhoto: UIImage? {
        guard let uri = PhotoPickUri.publicProfilePhotoUri(photoUri),
              let comma = uri.firstIndex(of: ","),
              let data = Data(base64Encoded: String(uri[uri.index(after: comma)...])) else { return nil }
        return UIImage(data: data)
    }

    /// Année d'études : dropdown maison, libellé d'action « Choisir mon année ».
    private var yearField: some View {
        AcctInfoDropdown(
            icon: "calendar-outline",
            value: year.isEmpty ? "Choisir mon année" : year,
            options: Self.years,
            accessibilityLabel: "Choisir mon année",
            onSelect: onYearChange
        )
    }

    /// Bloc PSI (`draftAcademicPath.currentTrack === 'PSI'`) : filière de 1re
    /// année (dropdown) puis filière de 2e année (valeur figée).
    private var psiTrackCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            AcctInfoDropdown(
                icon: "school-outline",
                label: "Filière de 1re année",
                value: firstYearTrack,
                options: OnbFlowAcademic.originChoices(currentTrack: "PSI"),
                accessibilityLabel: "Choisir ma filière de 1re année",
                onSelect: onOriginChange
            )
            VStack(alignment: .leading, spacing: 7) {
                Text("Filière de 2e année")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                HStack(spacing: 14) {
                    IonIcon(name: "school-outline", size: AcctInfoRowMetrics.iconSize, color: Theme.ink)
                        .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                    Text(currentTrack)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                }
                .frame(minHeight: 64)
                .padding(.horizontal, 8)
            }
        }
    }

    /// Initiale de la pastille : prénom, sinon nom (`firstName || displayName`).
    private var currentInitial: String {
        let preferred = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = preferred.isEmpty
            ? displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            : preferred
        return String((source.isEmpty ? "P" : source).prefix(1)).uppercased()
    }
}

// MARK: - Alerte biométrique

/// Alertes de la bascule biométrique (`updateBiometricLogin`,
/// `AccountScreen.tsx:1300-1366`).
enum AcctInfoBiometricAlert: String, Identifiable {
    case unavailable
    case activationFailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unavailable: return "Biométrie indisponible"
        case .activationFailed: return "Activation impossible"
        }
    }

    var message: String {
        switch self {
        case .unavailable:
            return "Configure d’abord une empreinte digitale ou la reconnaissance faciale dans les réglages de ton téléphone."
        case .activationFailed:
            return "L’identité biométrique n’a pas pu être vérifiée."
        }
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
    /// Déconnexion réelle, faillible (RN `LogoutControl`).
    var onLogout: () async throws -> Void = {}
    /// Suppression réelle du compte (asynchrone, faillible) — V1 2026-09-26,
    /// écart U08#2.
    var onDeleteAccount: () async throws -> Void = {}

    /// Off par défaut : le compte est public (source).
    @State private var isPrivateAccount = false
    @State private var isUpdatingBiometric = false
    @State private var biometricAlert: AcctInfoBiometricAlert?

    /// `informationContent` (`gap: 36`) puis `accountActionsGroup` (`gap: 8`).
    /// La carte sécurité est masquée en invité (`{!isGuest ? … : null}`).
    var body: some View {
        VStack(spacing: 36) {
            if !isGuest {
                securityCard
            }
            accountActions
        }
        .alert(biometricAlert?.title ?? "", isPresented: isBiometricAlertPresented) {
            Button("OK", role: .cancel) { biometricAlert = nil }
        } message: {
            Text(biometricAlert?.message ?? "")
        }
    }

    /// Liaison d'affichage de l'alerte biométrique : l'`item` optionnel devient
    /// un drapeau (`alert(_:isPresented:actions:message:)`, iOS 16).
    private var isBiometricAlertPresented: Binding<Bool> {
        Binding(
            get: { biometricAlert != nil },
            set: { presented in if !presented { biometricAlert = nil } }
        )
    }

    /// Sécurité : e-mail, mot de passe, connexion biométrique.
    /// `securityCard` de la source : fond blanc, sans bordure ni séparateur ;
    /// les lignes e-mail / mot de passe reprennent `passwordToggle` (60 / 10) et
    /// sont en encre (`colors.ink`).
    private var securityCard: some View {
        VStack(spacing: 0) {
            AcctInfoActionRow(
                icon: "mail-outline",
                title: "Modifier mon adresse e-mail",
                tint: Theme.ink,
                metrics: .password,
                action: onOpenEmail
            )
            AcctInfoActionRow(
                icon: "key-outline",
                title: "Modifier mon mot de passe",
                tint: Theme.ink,
                metrics: .password,
                action: onOpenPassword
            )
            AcctInfoToggleRow(
                icon: "finger-print",
                title: "Connexion biométrique",
                isOn: biometricBinding,
                isDisabled: isUpdatingBiometric,
                accessibilityLabel: "Activer la connexion biométrique"
            )
        }
        .background(Theme.surface)
    }

    /// Interrupteur biométrique : la bascule passe par la politique
    /// `AcctSecBiometricPolicy` (état + alerte) au lieu d'un no-op.
    private var biometricBinding: Binding<Bool> {
        Binding(
            get: { biometricEnabled },
            set: { enabled in Task { await updateBiometricLogin(enabled) } }
        )
    }

    /// Actions du compte, dans l'ordre de la source (`accountActionsGroup`,
    /// `gap: 8`).
    private var accountActions: some View {
        VStack(spacing: 8) {
            ConsentAiCard(iconSize: AcctInfoRowMetrics.iconSize)
            NotificationSettingsCard(store: notificationStore, isGuest: isGuest)
            AcctInfoToggleRow(
                icon: "lock-closed-outline",
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
                icon: "ban-outline",
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

    /// `updateBiometricLogin` : disponibilité, vérification biométrique, puis
    /// activation. Le repli « code de l'appareil » reste désactivé
    /// (`disableDeviceFallback`).
    @MainActor
    private func updateBiometricLogin(_ enabled: Bool) async {
        guard !isUpdatingBiometric else { return }
        isUpdatingBiometric = true
        defer { isUpdatingBiometric = false }
        if !enabled {
            onBiometricChange(false)
            return
        }
        guard AcctSecBiometricPolicy.availability() == .available else {
            biometricAlert = .unavailable
            return
        }
        let outcome = await AcctSecBiometricPolicy.authenticate(
            prompt: AcctSecBiometricPolicy.activationPrompt
        )
        switch outcome {
        case .success:
            onBiometricChange(true)
        case .cancelled:
            break
        case .lockout, .failed:
            biometricAlert = .activationFailed
        }
    }

    private var privateAccountDescription: String {
        isPrivateAccount
            ? "Tes performances ne sont plus publiées : tu restes visible sous « Anonyme » dans les classements."
            : "Tes performances sont visibles dans le fil et ton nom apparaît dans les classements."
    }
}
