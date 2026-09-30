//
//  AcctInfoSettingsView.swift
//  Duello
//
//  Écran de réglages : ruban « Paramètres | Premium », puis — côté
//  « Paramètres » — les quatre sous-pages du menu informations.
//
//  Fichiers source Expo portés :
//    - src/screens/AccountScreen.tsx : `SETTINGS_SWIPE_PAGES`
//      (`['informations', 'premium']`, l. 388), l'en-tête `settingsHeader`
//      (retour + onglets, l. 3576-3626), le compteur `premiumDaysCounter`
//      (l. 3640-3650), `informationContent` (l. 3657) et les transitions
//      `setInformationSettingsPage('menu' | 'duello' | 'personal' | 'account')`
//      (l. 3657-4180) ;
//    - src/utils/settingsTabSwipe.ts : ruban déjà porté par `SwipeSettingsTabs`.
//
//  Découpé hors de `AcctInfoPages.swift` pour tenir la règle des 10 `func`
//  par fichier. À présenter dans un `NavigationStack` par l'écran hôte.
//
//  V1 (2026-09-26) — écart U08#2 : `onDeleteAccount` devient asynchrone et
//  faillible, pour porter la suppression réelle du compte.
//
import SwiftUI

/// Mesures et couleurs de l'écran de réglages (`settingsHeader`, `settingsTab`,
/// `premiumDaysCounter`, `informationContent`).
enum AcctInfoSettingsStyle {
    /// `colors.white` : les réglages sont sur fond blanc, pas sur le fond d'app.
    static var surface: Color { Theme.surface }
    /// `scrollContent` : retrait horizontal des pages.
    static let horizontalPadding: CGFloat = 24
    static let topPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 36
    /// `settingsHeader.marginBottom`.
    static let headerBottom: CGFloat = 12
    /// `settingsBackButton` : carré du bouton de retour. La source pose 38 pt,
    /// mais le `BackButton` impose `minWidth/minHeight: 40`, qui l'emporte.
    static let backButtonSize: CGFloat = 40
    /// `settingsTabs` : écart entre onglets et retrait après le bouton.
    static let tabsSpacing: CGFloat = 8
    static let tabsLeading: CGFloat = 10
    /// `settingsTab` : hauteur minimale, retrait interne, épaisseur du trait.
    static let tabMinHeight: CGFloat = 38
    static let tabPadding: CGFloat = 8
    static let tabUnderline: CGFloat = 2
    /// `settingsTabText` : 13 / 800.
    static let tabTextSize: CGFloat = 13
    /// `informationContent`.
    static let informationTop: CGFloat = 20
    static let informationPadding: CGFloat = 4
    static let informationGap: CGFloat = 36
    /// `premiumDaysCounter`.
    static let premiumCounterTop: CGFloat = 28
    static let premiumCounterBottom: CGFloat = 40
    static let premiumCounterSpacing: CGFloat = 5
    /// `premiumDaysCounterText` : 13 / 800.
    static let premiumCounterTextSize: CGFloat = 13
}

/// Écran de réglages : onglets « Paramètres | Premium » et pages du menu.
struct AcctInfoSettingsView: View {
    @ObservedObject var notificationStore: NotificationPreferencesStore
    var isGuest: Bool = false
    var biometricEnabled: Bool = false
    var onBiometricChange: (Bool) -> Void = { _ in }
    var onOpenFeedback: () -> Void = {}
    var onOpenPrivacy: () -> Void = {}
    var onOpenTerms: () -> Void = {}
    var onOpenEmail: () -> Void = {}
    var onOpenPassword: () -> Void = {}
    var onOpenBlocked: () -> Void = {}
    /// Déconnexion réelle, faillible (RN `LogoutControl`).
    var onLogout: () async throws -> Void = {}
    // Suppression réelle du compte (asynchrone, faillible), portée V1 U08#2.
    var onDeleteAccount: () async throws -> Void = {}
    /// Jeton de session, transmis au carrousel d'offres Premium.
    var token: String? = nil
    /// « N jours Premium restants » ; `nil` hors abonnement actif.
    var premiumDaysLabel: String? = nil
    /// Ferme les réglages : retour depuis « Paramètres » ou geste vers la droite.
    var onClose: () -> Void = {}

    /// Profil du compte : nom et année sont **écrits ici** (persistance réelle,
    /// écart U08#17/#18/#27) au lieu de `@State` local jamais reporté.
    @Binding var profile: UserProfile
    /// Reporte le profil modifié dans la persistance (`persistProfile`).
    var onProfileChange: () -> Void = {}

    @State private var tab: SwipeSettingsTabs.Page
    @State private var page: AcctInfoPage

    init(
        notificationStore: NotificationPreferencesStore,
        profile: Binding<UserProfile>,
        isGuest: Bool = false,
        initialTab: SwipeSettingsTabs.Page = .informations,
        initialPage: AcctInfoPage = .menu,
        biometricEnabled: Bool = false,
        onBiometricChange: @escaping (Bool) -> Void = { _ in },
        onOpenFeedback: @escaping () -> Void = {},
        onOpenPrivacy: @escaping () -> Void = {},
        onOpenTerms: @escaping () -> Void = {},
        onOpenEmail: @escaping () -> Void = {},
        onOpenPassword: @escaping () -> Void = {},
        onOpenBlocked: @escaping () -> Void = {},
        onLogout: @escaping () async throws -> Void = {},
        onDeleteAccount: @escaping () async throws -> Void = {},
        token: String? = nil,
        premiumDaysLabel: String? = nil,
        onProfileChange: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {}
    ) {
        _notificationStore = ObservedObject(wrappedValue: notificationStore)
        _profile = profile
        self.isGuest = isGuest
        self.biometricEnabled = biometricEnabled
        self.onBiometricChange = onBiometricChange
        self.onOpenFeedback = onOpenFeedback
        self.onOpenPrivacy = onOpenPrivacy
        self.onOpenTerms = onOpenTerms
        self.onOpenEmail = onOpenEmail
        self.onOpenPassword = onOpenPassword
        self.onOpenBlocked = onOpenBlocked
        self.onLogout = onLogout
        self.onDeleteAccount = onDeleteAccount
        self.token = token
        self.premiumDaysLabel = premiumDaysLabel
        self.onProfileChange = onProfileChange
        self.onClose = onClose
        _tab = State(initialValue: initialTab)
        _page = State(initialValue: initialPage)
    }

    var body: some View {
        Ui2OrderedTabPager(
            pageCount: SwipeSettingsTabs.pages.count,
            page: tabIndex,
            onPageSelected: selectTab,
            onBack: leaveSettingsOrInformationPage
        ) {
            informationsSurface
            premiumSurface
        }
        .background(AcctInfoSettingsStyle.surface)
        // Écart U08#17 : le nom édité est reporté dans le profil persisté.
        .onChange(of: profile.displayName) { _ in onProfileChange() }
        .onChange(of: profile.firstName) { _ in onProfileChange() }
    }

    /// Chemin scolaire normalisé du profil (`normalizeAcademicPath`) : alimente
    /// le bloc PSI de la page « Mes informations » (écart U08#19).
    private var currentPath: AcademicPath { AcctInfoAcademic.path(profile) }

    // MARK: En-tête

    /// En-tête commun aux deux onglets : retour puis onglets (`settingsHeader`).
    /// La source ne titre pas la page : l'onglet ouvert dit où l'on est.
    private var header: some View {
        HStack(spacing: 0) {
            backButton
            // `settingsTabsVisible` : le ruban disparaît dès qu'une sous-page
            // est ouverte — le retour suffit.
            if tab != .informations || page == .menu {
                tabs
            }
        }
        .padding(.bottom, AcctInfoSettingsStyle.headerBottom)
        .background(AcctInfoSettingsStyle.surface)
    }

    /// Retour : catégories depuis une sous-page, sinon sortie des réglages.
    private var backButton: some View {
        Button(action: leaveSettingsOrInformationPage) {
            // RN `BackButton` : `<Ionicons name="chevron-back" size={21} … />`,
            // avec `icon: { transform: [{ translateX: -4 }] }`
            // (`BackButton.tsx:93`) — le chevron est décalé de 4 pt vers la gauche.
            IonIcon(name: "chevron-back", size: 21, color: Theme.ink)
                .offset(x: -4)
                .frame(
                    width: AcctInfoSettingsStyle.backButtonSize,
                    height: AcctInfoSettingsStyle.backButtonSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(backLabel)
    }

    private var backLabel: String {
        tab == .informations && page != .menu
            ? "Retour aux catégories de réglages"
            : "Retour au profil"
    }

    /// Onglets `['informations', 'Paramètres']` / `['premium', 'Premium']`.
    private var tabs: some View {
        HStack(spacing: AcctInfoSettingsStyle.tabsSpacing) {
            ForEach(SwipeSettingsTabs.pages) { item in
                tabButton(item)
            }
        }
        .padding(.leading, AcctInfoSettingsStyle.tabsLeading)
    }

    /// Un onglet : libellé 13/800, souligné quand il est ouvert.
    private func tabButton(_ item: SwipeSettingsTabs.Page) -> some View {
        let selected = item == tab
        let index = SwipeSettingsTabs.pageIndex(for: item)
        return Button { selectTab(index) } label: {
            Text(tabLabel(item))
                .font(.system(size: AcctInfoSettingsStyle.tabTextSize, weight: .heavy))
                .foregroundStyle(selected ? Theme.ink : Theme.inkFaint)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: AcctInfoSettingsStyle.tabMinHeight)
                .padding(.horizontal, AcctInfoSettingsStyle.tabPadding)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(selected ? Theme.ink : Color.clear)
                        .frame(height: AcctInfoSettingsStyle.tabUnderline)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// Libellés des onglets (`AccountScreen.tsx`, l. 3603) : « remote » reste
    /// désactivé sur mobile, mais garde son libellé pour la fiche photo.
    private func tabLabel(_ item: SwipeSettingsTabs.Page) -> String {
        switch item {
        case .informations: return "Paramètres"
        case .premium: return "Premium"
        case .remote: return "Connecter au PC"
        }
    }

    // MARK: Surfaces

    /// Onglet « Paramètres » : l'une des quatre sous-pages du menu.
    private var informationsSurface: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                informationsContent
            }
            .padding(.horizontal, AcctInfoSettingsStyle.horizontalPadding)
            .padding(.top, AcctInfoSettingsStyle.topPadding)
            .padding(.bottom, AcctInfoSettingsStyle.bottomPadding)
        }
        .background(AcctInfoSettingsStyle.surface)
    }

    /// Contenu de la sous-page ouverte (`informationContent`, `gap: 36`).
    @ViewBuilder private var informationsContent: some View {
        VStack(alignment: .leading, spacing: AcctInfoSettingsStyle.informationGap) {
            switch page {
            case .menu:
                AcctInfoMenuPage { page = $0 }
            case .duello:
                AcctInfoDuelloPage(
                    onReportBug: onOpenFeedback,
                    onOpenPrivacy: onOpenPrivacy,
                    onOpenTerms: onOpenTerms
                )
            case .personal:
                AcctInfoPersonalPage(
                    displayName: $profile.displayName,
                    firstName: profile.firstName,
                    year: profile.year,
                    currentTrack: currentPath.currentTrack,
                    firstYearTrack: currentPath.firstYearTrack,
                    photoUri: profile.photoUri,
                    isGuest: isGuest,
                    onYearChange: { newYear in
                        // Écarts U08#18/#27 : recalcul de la filière au changement d'année.
                        profile = AcctInfoAcademic.changeYear(profile, to: newYear)
                        onProfileChange()
                    },
                    onOriginChange: { origin in
                        profile = AcctInfoAcademic.changeOrigin(profile, firstYearTrack: origin)
                        onProfileChange()
                    },
                    onPhotoChange: { uri in
                        profile.photoUri = uri
                        onProfileChange()
                    }
                )
            case .account:
                AcctInfoAccountPage(
                    notificationStore: notificationStore,
                    isGuest: isGuest,
                    biometricEnabled: biometricEnabled,
                    onBiometricChange: onBiometricChange,
                    onOpenEmail: onOpenEmail,
                    onOpenPassword: onOpenPassword,
                    onOpenBlocked: onOpenBlocked,
                    onLogout: onLogout,
                    onDeleteAccount: onDeleteAccount
                )
            }
        }
        .padding(.top, AcctInfoSettingsStyle.informationTop)
        .padding(.horizontal, AcctInfoSettingsStyle.informationPadding)
    }

    /// Onglet « Premium » : compteur de jours puis carrousel d'offres.
    private var premiumSurface: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                premiumCounter
                PremOffersSection(token: token)
            }
            .padding(.horizontal, AcctInfoSettingsStyle.horizontalPadding)
            .padding(.top, AcctInfoSettingsStyle.topPadding)
            .padding(.bottom, AcctInfoSettingsStyle.bottomPadding)
        }
        .background(AcctInfoSettingsStyle.surface)
    }

    /// Coche + « N jours Premium restants », sous les onglets.
    @ViewBuilder private var premiumCounter: some View {
        if let premiumDaysLabel {
            HStack(spacing: AcctInfoSettingsStyle.premiumCounterSpacing) {
                PremPremiumBadge(size: 12)
                Text(premiumDaysLabel)
                    .font(.system(size: AcctInfoSettingsStyle.premiumCounterTextSize, weight: .heavy))
                    // `premiumDaysCounterText.lineHeight: 16` : SwiftUI n'expose pas
                    // d'interligne explicite pour un `Text` ; le défaut système
                    // (≈ 15,5 pt à 13 pt) en est à moins d'un point.
                    .foregroundStyle(Theme.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, AcctInfoSettingsStyle.premiumCounterTop)
            .padding(.bottom, AcctInfoSettingsStyle.premiumCounterBottom)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Navigation

    /// Index de l'onglet ouvert dans le ruban (`pageIndex(for:)`).
    private var tabIndex: Int { SwipeSettingsTabs.pageIndex(for: tab) }

    private func selectTab(_ index: Int) {
        let pages = SwipeSettingsTabs.pages
        guard pages.indices.contains(index) else { return }
        tab = pages[index]
    }

    /// `leaveSettingsOrInformationPage` : une sous-page revient aux catégories,
    /// le menu racine sort des réglages.
    private func leaveSettingsOrInformationPage() {
        if tab == .informations, page != .menu {
            page = .menu
        } else {
            onClose()
        }
    }
}
