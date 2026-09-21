import SwiftUI

// MARK: - Catalogue des offres Premium

/// Portage de `src/components/premium-offers/premiumOfferCatalog.ts` :
/// les trois offres canoniques (gratuite, annuelle, hebdomadaire), dans
/// l'ordre de `duello.fr/home`, avec leurs prix, leurs remises et leurs
/// bénéfices. Aucune valeur n'est recalculée ici : prix, périodes et
/// économies sont repris mot pour mot de la source.

/// Identifiant d'une offre (`PremiumOfferId`).
enum PremOfferId: String, CaseIterable, Identifiable {
    case free
    case annual
    case weekly

    var id: String { rawValue }
}

/// Bénéfice d'une offre : présent ou non dans la formule (`PremiumOfferFeature`).
struct PremOfferFeature: Identifiable, Equatable {
    let available: Bool
    let label: String

    /// Les libellés sont uniques dans une même liste : ils servent d'identité.
    var id: String { label }
}

/// Offre affichable (`PremiumOffer`).
struct PremOffer: Identifiable {
    let id: PremOfferId
    /// Libellé d'accessibilité de la carte, repris de la source.
    let accessibilityLabel: String
    /// Prix affiché, sans le symbole « € » : la carte l'ajoute à côté.
    let price: String
    let period: String?
    let equivalent: String?
    let saving: String?
    let features: [PremOfferFeature]
    let ctaLabel: String?
}

/// Les trois offres et les bénéfices partagés par les formules payantes.
enum PremOfferCatalog {
    /// `PREMIUM_REGISTRATION_TRIAL_DAYS` de `shared/premium-offer.mjs`.
    static let trialDays = 7

    /// Bénéfices complets, partagés par les deux offres payantes
    /// (`PREMIUM_FEATURES` de la source).
    static let premiumFeatures: [PremOfferFeature] = [
        PremOfferFeature(available: true, label: "Annales & banque d’exercices illimitées"),
        PremOfferFeature(available: true, label: "Correcteur IA 24 h/24"),
        PremOfferFeature(available: true, label: "Génération illimitée de flashcards"),
        PremOfferFeature(available: true, label: "Accès complet aux défis"),
        PremOfferFeature(available: true, label: "1 événement / mois"),
    ]

    /// Bénéfices de l'offre gratuite : l'essai offert à la création du compte,
    /// puis ses limites — dont « Aucune correction », qui motive la barrière.
    static let freeFeatures: [PremOfferFeature] = [
        PremOfferFeature(available: true, label: "\(trialDays) jours Premium"),
        PremOfferFeature(available: true, label: "1 événement / mois"),
        PremOfferFeature(available: true, label: "1 exercice par jour"),
        PremOfferFeature(available: false, label: "Aucune correction"),
    ]

    /// `PREMIUM_OFFERS` : la carte gratuite reste la première, l'annuelle
    /// précède l'hebdomadaire.
    static let offers: [PremOffer] = [
        PremOffer(
            id: .free,
            accessibilityLabel: "Offre gratuite à 0 euro",
            price: "0",
            period: nil,
            equivalent: nil,
            saving: nil,
            features: freeFeatures,
            ctaLabel: nil
        ),
        PremOffer(
            id: .annual,
            accessibilityLabel: "Offre annuelle à 103 euros et 99 centimes par an",
            price: "103,99",
            period: "/ an",
            equivalent: "Soit 2 € par semaine",
            saving: "−50 %",
            features: premiumFeatures,
            ctaLabel: "Accéder à Premium"
        ),
        PremOffer(
            id: .weekly,
            accessibilityLabel: "Offre hebdomadaire à 3 euros et 99 centimes par semaine",
            price: "3,99",
            period: "/ semaine",
            equivalent: nil,
            saving: nil,
            features: premiumFeatures,
            ctaLabel: "Accéder à Premium"
        ),
    ]

    /// `DEFAULT_OFFER_INDEX` : le carrousel s'ouvre sur l'offre annuelle, au
    /// milieu des trois cartes, plutôt que sur la carte gratuite.
    static let defaultOfferId: PremOfferId = .annual
}
