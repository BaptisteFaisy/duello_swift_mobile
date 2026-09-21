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

/// Affichage générique d'un document juridique : titre centré, date de mise à
/// jour, puis articles repliables. Reprend la présentation commune à
/// `PrivacyPolicyScreen.tsx` et `TermsOfUseScreen.tsx` (`LegalSectionView.tsx`).
struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(document.title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Theme.ink)
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Theme.background)
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
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(section.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(expanded ? "Replier" : "Déplier") : \(section.title)")

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
            }
        }
        .padding(.top, 18)
    }
}

/// Écran « Politique de confidentialité » (voir `PrivacyPolicyScreen.tsx`).
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LegalDocumentView(document: LegalContent.privacyPolicy)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer") { dismiss() }
                    }
                }
        }
    }
}

/// Écran « Conditions d'utilisation » (voir `TermsOfUseScreen.tsx`).
struct TermsOfUseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LegalDocumentView(document: LegalContent.termsOfUse)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer") { dismiss() }
                    }
                }
        }
    }
}
