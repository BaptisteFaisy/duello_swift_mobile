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
    /// `settingsBackButton` : carré du bouton de retour.
    static let backButtonSize: CGFloat = 38
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
    var onLogout: () -> Void = {}
    var onDeleteAccount: () -> Void = {}
    /// Jeton de session, transmis au carrousel d'offres Premium.
    var token: String? = nil
    /// « N jours Premium restants » ; `nil` hors abonnement actif.
    var premiumDaysLabel: String? = nil
    /// Ferme les réglages : retour depuis « Paramètres » ou geste vers la droite.
    var onClose: () -> Void = {}

    @State private var tab: SwipeSettingsTabs.Page
    @State private var page: AcctInfoPage
    @State private var displayName: String
    @State private var year: String

    init(
        notificationStore: NotificationPreferencesStore,
        isGuest: Bool = false,
        initialTab: SwipeSettingsTabs.Page = .informations,
        initialPage: AcctInfoPage = .menu,
        displayName: String = "",
        year: String = "",
        biometricEnabled: Bool = false,
        onBiometricChange: @escaping (Bool) -> Void = { _ in },
        onOpenFeedback: @escaping () -> Void = {},
        onOpenPrivacy: @escaping () -> Void = {},
        onOpenTerms: @escaping () -> Void = {},
        onOpenEmail: @escaping () -> Void = {},
        onOpenPassword: @escaping () -> Void = {},
        onOpenBlocked: @escaping () -> Void = {},
        onLogout: @escaping () -> Void = {},
        onDeleteAccount: @escaping () -> Void = {},
        token: String? = nil,
        premiumDaysLabel: String? = nil,
        onClose: @escaping () -> Void = {}
    ) {
        _notificationStore = ObservedObject(wrappedValue: notificationStore)
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
        self.onClose = onClose
        _tab = State(initialValue: initialTab)
        _page = State(initialValue: initialPage)
        _displayName = State(initialValue: displayName)
        _year = State(initialValue: year)
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
    }

    // MARK: En-tête

    /// En-tête commun aux deux onglets : retour puis onglets (`settingsHeader`).
    /// La source ne titre pas la page : l'onglet ouvert dit où l'on est.
    private var header: some View {
        HStack(spacing: 0) {
            backButton
            tabs
        }
        .padding(.bottom, AcctInfoSettingsStyle.headerBottom)
        .background(AcctInfoSettingsStyle.surface)
    }

    /// Retour : catégories depuis une sous-page, sinon sortie des réglages.
    private var backButton: some View {
        Button(action: leaveSettingsOrInformationPage) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
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
        return Button { selectTab(item) } label: {
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
                AcctInfoPersonalPage(displayName: $displayName, year: $year, isGuest: isGuest)
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
