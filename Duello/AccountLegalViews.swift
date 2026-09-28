import SwiftUI

// MARK: - Documents juridiques

/// Article d'un document juridique embarqué : un titre, des paragraphes, puis
/// des puces. Reprend la forme de `LegalSection` de `LegalSectionView.tsx`.
struct LegalSection: Identifiable {
    let id: String
    let title: String
    var paragraphs: [String] = []
    var bullets: [String] = []
}

/// Document juridique embarqué : titre, date de mise à jour et articles.
struct LegalDocument {
    let title: String
    let updatedAt: String
    let sections: [LegalSection]
}

/// Affichage générique d'un document juridique : chevron de retour en tête,
/// titre centré, date de mise à jour, puis articles repliables. Reprend la
/// présentation commune à `PrivacyPolicyScreen.tsx` et `TermsOfUseScreen.tsx`
/// (`LegalSectionView.tsx`) : marge latérale `LEGAL_PAGE_CONTENT_INSET` (44),
/// marge basse `LEGAL_PAGE_BOTTOM_INSET` (120), chevron de retour en tête de
/// contenu (marge `LEGAL_PAGE_BACK_INSET` = 24) au lieu d'une barre de
/// navigation, et espace de fin propre aux Conditions.
struct LegalDocumentView: View {
    let document: LegalDocument
    /// Retour arrière facultatif (`onBack` de la source). Fourni, il ajoute le
    /// chevron en tête de contenu.
    var onBack: (() -> Void)? = nil
    /// Espace de 12 pt en fin de page (`backToSettingsSpacer`), propre aux
    /// Conditions et affiché quand `onBack` est fourni.
    var showsBackToSettingsSpacer: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let onBack {
                backButton(onBack)
            }

            // `ElasticScrollView.tsx` : défilement commun aux pages légales.
            // L'indicateur vertical est masqué (`showsVerticalScrollIndicator=
            // {false}`) et le contenu occupe au moins la hauteur visible
            // (`flexGrow: 1`).
            Ui2ElasticScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(document.title)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Theme.ink)
                        // Interligne 29 pt de la source : la hauteur de ligne
                        // native de la police système à 24 pt vaut ≈ 29 pt, la
                        // valeur est donc déjà respectée (SwiftUI n'expose pas
                        // de réglage exact de la hauteur de ligne).
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("Dernière mise à jour : \(document.updatedAt)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 6)
                        .padding(.bottom, 16)

                    ForEach(document.sections) { section in
                        LegalSectionRow(section: section)
                    }

                    // `backToSettingsSpacer` : rendu uniquement quand `onBack`
                    // est fourni (`TermsOfUseScreen.tsx:47`).
                    if showsBackToSettingsSpacer, onBack != nil {
                        Color.clear.frame(height: 12)
                    }
                }
                .padding(.horizontal, 44)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
        }
        .background(Theme.background)
    }

    /// Chevron de retour, aligné sur le bord `LEGAL_PAGE_BACK_INSET` (24).
    private func backButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // `BackButton.tsx` : glyphe `chevron-back` 20 `ink`, sans graisse,
            // centré dans une boîte 40×40 puis décalé de -4 pt.
            IonIcon(name: "chevron-back", size: 20, color: Theme.ink)
                .offset(x: -4)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
                // `hitSlop={8}` : cible tactile élargie de 8 pt (56 pt) sans
                // décaler la mise en page.
                .padding(8)
                .contentShape(Rectangle())
                .padding(-8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Retour aux paramètres")
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
    }
}

/// Article repliable : le contenu (paragraphes puis puces) reste masqué jusqu'à
/// l'appui sur le titre, et le chevron pivote d'un quart de tour.
private struct LegalSectionRow: View {
    let section: LegalSection

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                // `setExpanded((value) => !value)` de la source : bascule sèche,
                // aucune animation (`LegalSectionView.tsx:26`).
                expanded.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text(section.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // `Ionicons "chevron-forward"` 16 `inkFaint`, sans graisse.
                    IonIcon(name: "chevron-forward", size: 16, color: Theme.inkFaint)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(expanded ? "Replier" : "Déplier") : \(section.title)")
            // `accessibilityState={{ expanded }}` de la source.
            .accessibilityValue(expanded ? "Déplié" : "Replié")

            if expanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(section.paragraphs.indices, id: \.self) { index in
                        Text(section.paragraphs[index])
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    }
                    ForEach(section.bullets.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.primary)
                            Text(section.bullets[index])
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.top, 18)
    }
}

/// Écran « Politique de confidentialité » (voir `PrivacyPolicyScreen.tsx`).
struct PrivacyPolicyView: View {
    /// `onBack?` de la source : absent (onboarding, premium), aucun chevron.
    var onBack: (() -> Void)? = nil

    var body: some View {
        LegalDocumentView(
            document: LegalContent.privacyPolicy,
            onBack: onBack
        )
    }
}

/// Écran « Conditions d'utilisation » (voir `TermsOfUseScreen.tsx`).
struct TermsOfUseView: View {
    /// `onBack?` de la source : absent (onboarding, premium), aucun chevron.
    var onBack: (() -> Void)? = nil

    var body: some View {
        LegalDocumentView(
            document: LegalContent.termsOfUse,
            onBack: onBack,
            showsBackToSettingsSpacer: true
        )
    }
}
