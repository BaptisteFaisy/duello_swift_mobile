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
/// absent : « Gérer mon abonnement » (`presentCustomerCenter`), qui n'existe
/// que si le paywall RevenueCat est embarqué — jamais dans ce portage.
struct PremOffersSection: View {
    /// Jeton de session, transmis à la carte « code promo ».
    var token: String? = nil

    @StateObject private var promo = PremPromoCodeController()
    @State private var availableWidth: CGFloat = 0
    @State private var openedOnDefaultOffer = false

    private let offerGap: CGFloat = 18
    private let nextOfferPreview: CGFloat = 18
    private let offerMaxWidth: CGFloat = 340

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
                .onAppear {
                    guard !openedOnDefaultOffer else { return }
                    openedOnDefaultOffer = true
                    proxy.scrollTo(PremOfferCatalog.defaultOfferId, anchor: .leading)
                }
            }
        }
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

    /// Les garanties, sous la carte promo : la source les aligne sur 300 points
    /// centrés. Quand la facturation native est absente, une dernière ligne
    /// explique pourquoi le bouton reste inerte.
    private var reassurance: some View {
        VStack(alignment: .leading, spacing: 9) {
            PremReassuranceRow(label: "Résiliable à tout moment")
            PremReassuranceRow(label: "Paiement sécurisé via l’App Store et Google Play")
            if !PremPurchaseService.isAvailable {
                PremReassuranceRow(
                    label: PremPurchaseService.paywallUnavailableMessage,
                    icon: "info.circle"
                )
            }
        }
        .frame(maxWidth: 300, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
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
    var icon: String = "checkmark.shield"

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// Largeur mesurée du carrousel, remontée par préférence.
private struct PremOffersWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
