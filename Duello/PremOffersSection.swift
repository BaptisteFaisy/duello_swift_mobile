import SwiftUI

// MARK: - Section des offres Premium

/// Portage de `src/components/PremiumOffers.tsx` : le carrousel des trois
/// offres, la carte « code promo » qui le suit et les garanties qui ferment la
/// page.
///
/// Les prix sont affichés à l'identique de `duello.fr/home` : la contrainte de
/// conformité (App Store 3.1.1) porte sur le bouton d'abonnement, pas sur la
/// présentation des tarifs — d'où des cartes payantes toujours visibles et un
/// bouton désactivé tant que la facturation native n'est pas embarquée.
///
/// absent : la disposition de bureau (trois cartes côte à côte, survol à
/// l'échelle), propre au client téléchargé.
/// « Gérer mon abonnement » (`presentCustomerCenter`) n'apparaît que si le
/// paywall RevenueCat est embarqué (`isRevenueCatPaywallAvailable`) : la sonde
/// `PremPurchasesModules.nativePurchasesUIModule()` renvoie `nil` dans ce build,
/// donc la ligne reste absente — l'appel est câblé, il ne s'affiche jamais.
struct PremOffersSection: View {
    /// Jeton de session, transmis à la carte « code promo ».
    var token: String? = nil

    /// Disponibilité de la facturation native, publiée par l'hôte du paywall
    /// (`\.premPurchaseAvailable`) ; sans hôte, la valeur par défaut est celle
    /// de la couture `PremCodePurchases` (voir `PremToolPaywall.swift`).
    @Environment(\.premPurchaseAvailable) private var purchaseAvailable

    @StateObject private var promo = PremPromoCodeController()
    @State private var availableWidth: CGFloat = 0
    @State private var openedOnDefaultOffer = false
    /// Alignement différé en cours (`snapToInterval` de la source) : annulé et
    /// replanifié à chaque mouvement du carrousel.
    @State private var snapTask: Task<Void, Never>?

    private let offerGap: CGFloat = 18
    private let nextOfferPreview: CGFloat = 18
    private let offerMaxWidth: CGFloat = 340
    /// Repère nommé du carrousel, pour mesurer son défilement (`onScroll` de la
    /// source, reconstruit par mesure de préférence).
    private let scrollSpace = "prem.offers.scroll"

    /// Le seul réglage exposé est le jeton de session : l'état local du
    /// carrousel et du formulaire reste `private`, ce que l'initialiseur
    /// explicite rend possible depuis un autre fichier.
    init(token: String? = nil) {
        self.token = token
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            carousel
            PremPromoCodeCard(controller: promo) {
                Task { await promo.submit(token: token) }
            }
            reassurance
            // `PremiumOffers.tsx:143` : le pied de conformité est **masqué** dans
            // les builds development (mêmes masques que le nom de formule).
            if !PremDevelopmentBuild.isActive {
                PremSubscriptionLegalFooter()
            }
        }
    }

    /// Le carrousel, qui s'ouvre sur l'offre annuelle plutôt que sur la carte
    /// gratuite (`DEFAULT_OFFER_INDEX` de la source).
    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                HStack(spacing: offerGap) {
                    ForEach(PremOfferCatalog.offers) { offer in
                        PremOfferCard(offer: offer, discount: promo.discounted[offer.id])
                            .frame(width: cardWidth)
                            .id(offer.id)
                    }
                }
                .padding(.bottom, 8)
                .background(offsetReader)
                .onPreferenceChange(PremOffersOffsetKey.self) { offset in
                    snap(offset: offset, proxy: proxy)
                }
                .onAppear {
                    guard !openedOnDefaultOffer else { return }
                    openedOnDefaultOffer = true
                    // `scrollTo({animated:false})` de la source : l'ouverture sur
                    // l'offre annuelle ne s'anime pas.
                    withAnimation(nil) {
                        proxy.scrollTo(PremOfferCatalog.defaultOfferId, anchor: .leading)
                    }
                }
            }
        }
        .coordinateSpace(name: scrollSpace)
        .accessibilityLabel("Les trois offres Duello")
        .background(widthReader)
        .onPreferenceChange(PremOffersWidthKey.self) { width in
            if width > 0 { availableWidth = width }
        }
    }

    /// `offerWidth` puis `cardWidth` de la source : la carte laisse voir un
    /// aperçu de la suivante, et ne dépasse jamais 340 points.
    private var cardWidth: CGFloat {
        let available = availableWidth > 0 ? availableWidth : offerMaxWidth
        let offerWidth = available - offerGap - nextOfferPreview
        return max(1, min(offerMaxWidth, offerWidth))
    }

    /// Alignement carte par carte : `snapToInterval = cardWidth + OFFER_GAP`,
    /// `snapToAlignment="start"`. iOS 16 n'a pas d'alignement natif
    /// (`scrollTargetBehavior` est iOS 17) : le défilement mesuré est ramené au
    /// multiple de l'intervalle le plus proche, après un court répit sans
    /// mouvement — approximation du `decelerationRate="fast"` de la source.
    private func snap(offset: CGFloat, proxy: ScrollViewProxy) {
        let interval = cardWidth + offerGap
        guard interval > 0 else { return }
        let count = PremOfferCatalog.offers.count
        let index = min(max(Int((offset / interval).rounded()), 0), count - 1)
        let target = CGFloat(index) * interval
        guard abs(offset - target) > 0.5 else { return }
        let id = PremOfferCatalog.offers[index].id
        snapTask?.cancel()
        snapTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(id, anchor: .leading)
            }
        }
    }

    /// Mesure le défilement horizontal du carrousel (`onScroll` de la source).
    private var offsetReader: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: PremOffersOffsetKey.self,
                value: -geo.frame(in: .named(scrollSpace)).minX
            )
        }
    }

    /// Les garanties, sous la carte promo : la source les aligne sur 300 points
    /// centrés. La gestion d'abonnement ne s'y ajoute que si la facturation
    /// native est embarquée (`isRevenueCatPaywallAvailable`), donc jamais ici.
    private var reassurance: some View {
        VStack(alignment: .leading, spacing: 9) {
            PremReassuranceRow(label: "Résiliable à tout moment")
            PremReassuranceRow(label: "Paiement sécurisé via l’App Store et Google Play")
            if manageAvailable { manageRow }
        }
        .frame(maxWidth: 300, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    /// `isRevenueCatPaywallAvailable()` : SDK + interface RevenueCat + clé.
    /// La disponibilité vient de la couture d'achat (publiée par l'hôte du
    /// paywall ou lue par défaut) ; la sonde de l'interface RevenueCat renvoie
    /// `nil` dans ce build, donc la ligne reste masquée.
    private var manageAvailable: Bool {
        purchaseAvailable && PremPurchasesModules.nativePurchasesUIModule() != nil
    }

    /// « Gérer mon abonnement » (`presentCustomerCenter`) : même disposition
    /// qu'une garantie, mais actionnable. Jamais montrée tant que la couture
    /// d'achat refuse (`purchaseAvailable == false`).
    private var manageRow: some View {
        Button {
            Task { try? await PremPurchasesModules.nativePurchasesUIModule()?.presentCustomerCenter() }
        } label: {
            PremReassuranceRow(label: "Gérer mon abonnement", icon: "settings-outline")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gérer mon abonnement")
    }

    /// Mesure la largeur du carrousel (`onLayout` de la source) : les cartes se
    /// dimensionnent dessus, comme dans Expo.
    private var widthReader: some View {
        GeometryReader { geo in
            Color.clear.preference(key: PremOffersWidthKey.self, value: geo.size.width)
        }
    }
}

/// `Reassurance` de la source : une icône et une ligne de garantie.
struct PremReassuranceRow: View {
    let label: String
    var icon: String = "shield-checkmark-outline"

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            IonIcon(name: icon, size: 16, color: Theme.inkSoft)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// `isDevelopmentBuild()` de la source (`utils/developmentBuild.ts`) : vrai dans
/// les builds development — Metro local (`__DEV__`) ou canal EAS `development`.
/// Le binaire iOS n'a ni `__DEV__` ni canal OTA ; le repli natif est le build
/// Debug (`#if DEBUG`), faux en Release — parité build *development* RN d'un
/// côté, prod RN (preview/production/stores) de l'autre.
enum PremDevelopmentBuild {
    static var isActive: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

/// `SubscriptionLegalFooter` de la source : la mention de reconduction puis les
/// deux liens légaux, qui ouvrent les écrans embarqués.
struct PremSubscriptionLegalFooter: View {
    @State private var page: PremLegalPage?

    var body: some View {
        VStack(spacing: 10) {
            Text(
                "Le paiement est débité via l’App Store ou Google Play. "
                + "L’abonnement se renouvelle automatiquement sauf résiliation "
                + "au plus tard 24 h avant la fin de la période en cours."
            )
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                PremLegalLink(label: "Conditions d’utilisation") { page = .terms }
                Text("•")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
                PremLegalLink(label: "Politique de confidentialité") { page = .privacy }
            }
        }
        .padding(.horizontal, 8)
        .sheet(item: $page) { target in
            switch target {
            case .terms:
                TermsOfUseView()
            case .privacy:
                PrivacyPolicyView()
            }
        }
    }
}

/// Un lien légal souligné (`styles.link` / `styles.linkText` de la source).
private struct PremLegalLink: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .underline()
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
    }
}

/// Page légale ouverte depuis le pied de page (`legalPage` de la source).
private enum PremLegalPage: String, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }
}

/// Largeur mesurée du carrousel, remontée par préférence.
private struct PremOffersWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Défilement horizontal mesuré du carrousel, remonté par préférence.
private struct PremOffersOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
