import SwiftUI

// MARK: - Carte d'offre Premium

/// Portage de `src/components/premium-offers/PremiumOfferCard.tsx` : la carte
/// sombre d'une offre — fond dégradé, badges de remise, prix, bénéfices et
/// bouton d'abonnement.
///
/// absent : l'agrandissement au survol (`onPointerEnter` + `scale(1.025)`),
/// réservé au client de bureau téléchargé, sans objet sur iOS.
/// absent : l'état `busy` (« Ouverture… ») — aucun flux d'achat dans ce
/// portage, voir `PremPurchaseService`.
struct PremOfferCard: View {
    let offer: PremOffer
    var discount: PremDiscount? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // `planRow` : badge du code promo à gauche, économie de l'offre à droite.
            HStack(spacing: 8) {
                if let discount {
                    PremSavingBadge(text: discount.saving)
                }
                Spacer(minLength: 0)
                if let saving = offer.saving {
                    PremSavingBadge(text: saving)
                }
            }
            .frame(minHeight: 25)

            PremOfferPriceRow(offer: offer, discount: discount)

            // `equivalentSlot` : hauteur réservée même sans équivalent, pour que
            // les trois cartes gardent la même assise.
            VStack(spacing: 0) {
                if let equivalent = offer.equivalent {
                    Text(equivalent)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .top)
            .padding(.top, 13)

            PremOfferFeatures(features: offer.features)

            Spacer(minLength: 16)

            if let label = offer.ctaLabel {
                PremOfferCallToAction(label: label, available: PremPurchaseService.isAvailable)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 500, alignment: .topLeading)
        .background(PremOfferBackdrop(annual: offer.id == .annual))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(offer.accessibilityLabel)
    }
}

/// `OfferPriceRow` : prix barré du code promo, valeur, symbole « € » et période.
struct PremOfferPriceRow: View {
    let offer: PremOffer
    let discount: PremDiscount?

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if let discount {
                Text(discount.basePrice)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .strikethrough()
                    .padding(.bottom, 10)
            }
            HStack(alignment: .top, spacing: 4) {
                Text(discount?.price ?? offer.price)
                    .font(.system(size: 48, weight: .medium))
                    .kerning(-2.1)
                    .foregroundStyle(Color.white)
                Text("€")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.white)
                    .padding(.top, 2)
            }
            if let period = offer.period {
                Text(period)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .padding(.top, 16)
    }
}

/// `OfferFeatures` : coche blanche pour un bénéfice inclus, croix grisée sinon.
///
/// `marginTop: 17` et `paddingTop: 17` de la source se cumulent : 34 points
/// séparent le dernier prix de la liste.
struct PremOfferFeatures: View {
    let features: [PremOfferFeature]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(features) { feature in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: feature.available ? "checkmark" : "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(feature.available ? Color.white : PremOfferPalette.limited)
                        .frame(width: 18)
                    Text(feature.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(feature.available ? Color.white : PremOfferPalette.limited)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.top, 34)
    }
}

/// `PremiumCallToAction` : le bouton d'abonnement de la carte.
///
/// ⚠️ La conformité App Store 3.1.1 porte sur le bouton, pas sur les tarifs :
/// tant que la facturation native n'est pas embarquée (`available == false`),
/// le bouton reste désactivé, en encre atténuée, et annonce « bientôt
/// disponible » aux lecteurs d'écran. `onPurchase` est le point de branchement
/// de `purchase.launch(offer.id)` le jour où StoreKit arrive.
struct PremOfferCallToAction: View {
    let label: String
    let available: Bool
    var onPurchase: (() -> Void)? = nil

    var body: some View {
        Button { onPurchase?() } label: {
            Text(label)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(available ? Theme.ink : Theme.inkSoft)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(available ? 1 : 0.85)
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .accessibilityLabel(available ? label : "\(label), bientôt disponible")
        .accessibilityAddTraits(.isButton)
    }
}

/// `OfferBackdrop` : dégradé sombre, et pour l'offre annuelle un projecteur
/// radial qui l'éclaire par le haut.
///
/// Le projecteur de la source est une ellipse SVG (`rx` 167, `ry` 113 dans une
/// boîte de 100 × 100) ; SwiftUI ne trace qu'un rayon circulaire, le portage
/// retient donc le plus grand des deux et éclaire un peu plus large sur les
/// côtés.
struct PremOfferBackdrop: View {
    let annual: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: PremOfferPalette.stops(annual: annual)),
                    startPoint: UnitPoint(x: 0.15, y: 0),
                    endPoint: UnitPoint(x: 0.85, y: 1)
                )
                if annual {
                    RadialGradient(
                        gradient: Gradient(stops: PremOfferPalette.spotlight),
                        center: UnitPoint(x: 0.5, y: -0.08),
                        startRadius: 0,
                        endRadius: max(geo.size.width, geo.size.height) * 1.67
                    )
                }
            }
        }
    }
}

/// Badge translucide de remise (« −50 % », « −25 % »).
struct PremSavingBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(PremOfferPalette.savingBadgeBackground)
            .clipShape(Capsule())
    }
}

/// Couleurs des cartes d'offre, relevées sur `PremiumOfferCard.tsx`.
enum PremOfferPalette {
    /// `DARK_GRADIENT` et `ANNUAL_GRADIENT`, avec leurs positions.
    static func stops(annual: Bool) -> [Gradient.Stop] {
        annual
            ? [
                Gradient.Stop(color: Color(hex: 0x5A5A5A), location: 0),
                Gradient.Stop(color: Color(hex: 0x242424), location: 0.48),
                Gradient.Stop(color: Color(hex: 0x030303), location: 1),
            ]
            : [
                Gradient.Stop(color: Color(hex: 0x383838), location: 0),
                Gradient.Stop(color: Color(hex: 0x161616), location: 0.52),
                Gradient.Stop(color: Color(hex: 0x050505), location: 1),
            ]
    }

    /// `ANNUAL_SPOTLIGHT_STOPS` : blanc 24 %, gris 13 %, puis transparent.
    static let spotlight: [Gradient.Stop] = [
        Gradient.Stop(color: Color.white.opacity(0.24), location: 0),
        Gradient.Stop(color: Color(hex: 0x9D9D9D).opacity(0.13), location: 0.32),
        Gradient.Stop(color: Color(hex: 0x9D9D9D).opacity(0), location: 0.58),
    ]

    /// `stylesVars.limitedColor` : bénéfice absent de la formule.
    static let limited = Color.white.opacity(0.58)

    /// `savingBadge.backgroundColor`.
    static let savingBadgeBackground = Color.white.opacity(0.18)
}
