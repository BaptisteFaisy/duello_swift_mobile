import SwiftUI

/// En-tête de domaine de la page « Matières ».
///
/// Port de `DomainHeading` (`src/screens/SubjectsScreen.tsx`, lignes 1088-1098),
/// avec les styles `domainHeader` (`marginTop: 18`, `paddingHorizontal: 2`,
/// ligne ~10355) et `domainTitle` (`fontSize: 11`, `fontWeight: '800'`,
/// `color: colors.primary`, `textTransform: 'uppercase'`,
/// `letterSpacing: 0.6`, ligne ~10361).
///
/// `colors.primary` vaut `#0A0D0C` dans `src/theme.ts`, soit exactement
/// `Theme.ink` : l'intitulé est donc en `ink`, pas en couleur d'accent.
///
/// Distinct de `DuelloSectionHeader` (13 pt `heavy`, `inkSoft`, sous-titre
/// optionnel) : ne pas le remplacer par ce dernier sans changer la charte.
struct SubjDomainHeading: View {
    /// Intitulé déjà résolu (la source reçoit une chaîne, pas une énumération).
    let label: String

    /// `marginTop: 18` de `styles.domainHeader`.
    private static let topMargin: CGFloat = 18
    /// `letterSpacing: 0.6` de `styles.domainTitle`.
    private static let tracking: CGFloat = 0.6
    /// `paddingHorizontal: 2` de `styles.domainHeader`.
    private static let horizontalPadding: CGFloat = 2

    init(label: String) {
        self.label = label
    }

    /// Commodité : un domaine du programme porte déjà son libellé
    /// (`CHAPTER_DOMAIN_LABELS`, cf. `TrainDomain.label`).
    init(domain: TrainDomain) {
        self.label = domain.label
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .textCase(.uppercase)
                .tracking(Self.tracking)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.top, Self.topMargin)
        .accessibilityAddTraits(.isHeader)
    }
}
