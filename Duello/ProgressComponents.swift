import SwiftUI

/// Composants partagés de l'écran « Progression » : carte ombrée, encart
/// d'information, titre de section, état vide d'un onglet, marque du pluriel,
/// ligne de métrique du résumé et barre d'avancement. Extension de
/// `DuelloProgressView` pour les helpers de mise en page (voir
/// `ProgressScreen.swift` pour le découpage) ; les vues et la barre sont des
/// types à part, réutilisables par les autres onglets.
extension DuelloProgressView {

    // MARK: Composants partagés

    /// Encart d'information sur fond clair (invitation de l'onglet Défis).
    func infoCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.primary)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.top, 16)
    }

    /// Titre de section de l'écran (« Temps par matière »).
    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(Theme.ink)
    }

    /// État vide d'un onglet de matière : aucune matière cochée dans le filtre.
    var noSubjectSelectedState: some View {
        VStack(spacing: 0) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
            Text("Aucune matière sélectionnée")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.top, 16)
            Text("Choisis au moins une matière dans le menu ci-dessus pour voir tes performances.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .padding(.top, 8)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    /// Marque du pluriel reprise d'Expo : « s » dès que le compte dépasse 1.
    func agreement(_ count: Int) -> String {
        count > 1 ? "s" : ""
    }
}

/// Carte de l'écran « Progression » : fond blanc, rayon moyen et ombre du thème
/// (`cardShadow` d'`theme.ts`), comme les cartes d'Expo — pas de bordure.
extension View {
    func progressCard(padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .duelloShadow()
    }
}

// MARK: - Vues partagées

/// Ligne de progression compacte du résumé embarqué (voir `EmbeddedMetric` de
/// `EnhancedProgressScreen.tsx`) : libellé, valeur et barre discrète.
struct EmbeddedMetric: View {
    let label: String
    let value: String
    /// Fraction attendue dans [0, 1] ; les valeurs hors bornes sont ramenées.
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Spacer(minLength: 12)
                Text(value)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            ProgressBar(fraction: progress, height: 3, track: Theme.surfaceMuted, fill: Theme.ink)
        }
    }
}

/// Barre d'avancement fine : piste claire, remplissage vert de maîtrise
/// (voir `progressTrack`/`progressFill` de `theme.ts`).
struct ProgressBar: View {
    /// Fraction de remplissage attendue dans [0, 1].
    let fraction: Double
    /// Épaisseur de la barre.
    var height: CGFloat = 6
    /// Couleur de la piste.
    var track: Color = Theme.primaryLight
    /// Couleur du remplissage ; l'encre pour la barre du résumé embarqué.
    var fill: Color = Theme.progress

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(fill)
                    .frame(width: proxy.size.width * bounded)
            }
        }
        .frame(height: height)
    }

    /// Fraction bornée à [0, 1], comme `Math.min(1, Math.max(0, progress))`.
    private var bounded: CGFloat {
        CGFloat(min(1, max(0, fraction)))
    }
}
