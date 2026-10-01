//
//  AcctGradeHistoryCard.swift
//  Duello
//
//  Historique des notes du profil (lot S04, vague 6 ; bordure et « Tout voir »
//  vague I7).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/GradeHistoryCard.tsx (`GradeHistoryCard`,
//      `GradeHistoryRowView`).
//
//  Réutilise `GradeHistoryRow` (`RankingGradeHistory.swift`),
//  `ExGRemarkBadge` (`GradingRemarkBadge`), `ChartGradeEvolutionBadge`
//  (`GradeEvolutionBadge`) et `ExGFormat.score` (`formatGradingScore`).
//
//  L'état est figé, contrairement à la version animée du site : la carte est
//  rendue une fois par état de l'écran, comme la source.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// `GradeHistoryCard` de `src/components/GradeHistoryCard.tsx` : les dernières
/// corrections, de la plus récente à la plus ancienne, chacune avec sa
/// catégorie, son intitulé, son appréciation, son éventuel record, sa note sur
/// 20 et son évolution face à la note précédente.
struct AcctGradeHistoryCard: View {
    let rows: [ResolvedGradeHistoryRow]
    /// `onSeeAll` : ouvre la page dédiée à l'historique complet. Absent sur
    /// cette page.
    var onSeeAll: (() -> Void)? = nil
    /// `onOpenItem` : rouvre le sujet d'une ligne lorsque le spectateur y a
    /// accès (`onOpenItem` de `GradeHistoryCard.tsx`). Absent ⇒ lignes inertes.
    var onOpenItem: ((ChalRunTrainingTarget) -> Void)? = nil
    /// `hasMore` : vrai lorsqu'au moins une note est masquée par l'aperçu.
    var hasMore: Bool = false
    /// `showTitle` : la page dédiée ne répète pas le titre.
    var showTitle: Bool = true
    /// `refined` : titre noir capitales sur le développement, gris atténué en
    /// production.
    var refined: Bool = false

    var body: some View {
        if rows.isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    /// Bandeau (kicker + « Tout voir ») puis la liste des lignes (`styles.list`).
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(spacing: 7) {
                ForEach(rows) { row in
                    rowView(row)
                }
            }
        }
    }

    /// `seeAllVisible` : le lien n'apparaît que si l'aperçu masque des notes.
    private var seeAllVisible: Bool {
        hasMore && onSeeAll != nil
    }

    /// `styles.header` : kicker à gauche, « Tout voir » à droite. Le bandeau
    /// n'existe que si l'un des deux est visible.
    @ViewBuilder
    private var header: some View {
        if showTitle || seeAllVisible {
            HStack(alignment: .center, spacing: 0) {
                if showTitle {
                    Text("Historique")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(refined ? Theme.ink : Theme.inkFaint)
                }
                Spacer(minLength: 0)
                if seeAllVisible, let onSeeAll {
                    Button(action: onSeeAll) {
                        Text("Tout voir")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tout voir")
                    .contentShape(Rectangle())
                }
            }
            .padding(.bottom, 8)
        }
    }

    /// Une ligne : intitulé à gauche, note et évolution à droite (`styles.row`).
    /// Toute ligne dont la cible est connue devient un bouton (« Ouvrir le sujet
    /// dans l'entraînement »), à `opacity: 0.6` à l'appui (`styles.rowPressed`).
    @ViewBuilder
    private func rowView(_ row: ResolvedGradeHistoryRow) -> some View {
        if let target = row.target, let onOpenItem {
            Button {
                onOpenItem(target)
            } label: {
                rowBody(row)
            }
            .buttonStyle(HistoryRowPressStyle())
            .accessibilityLabel("\(row.displayTitle), \(ExGFormat.score(row.score))")
            .accessibilityHint("Ouvrir le sujet dans l'entraînement")
        } else {
            rowBody(row)
        }
    }

    /// Le corps de la ligne, partagé par la version inerte et la version
    /// pressable.
    private func rowBody(_ row: ResolvedGradeHistoryRow) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.category)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.ink)
                Text(row.displayTitle)
                    .font(.system(size: 13.5, weight: .bold))
                    .tracking(-0.14)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                remarks(row)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            figure(row)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Pastille « Record » (seul aplat noir plein de la ligne) puis appréciation.
    /// Les deux pastilles s'enroulent si la largeur manque (`flexWrap: 'wrap'`).
    private func remarks(_ row: ResolvedGradeHistoryRow) -> some View {
        AcctShowWrapLayout(spacing: 6) {
            if row.record {
                Text("Record")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.surface)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.ink)
                    .clipShape(Capsule())
                    // `marginRight: 2` de la source : 2 points de plus que le
                    // `gap: 6` commun aux deux pastilles.
                    .padding(.trailing, 2)
                    .accessibilityLabel("Record")
            }
            ExGRemarkBadge(score: row.score)
        }
        .padding(.top, 2)
    }

    /// Note sur 20 et pastille d'évolution (`styles.figure`).
    private func figure(_ row: ResolvedGradeHistoryRow) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(ExGFormat.score(row.score))
                .font(.system(size: 13, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            if let percentage = row.evolutionPercentage {
                ChartGradeEvolutionBadge(percentage: percentage)
            }
        }
    }
}

/// `styles.rowPressed` : la ligne s'éclaircit à l'appui (`opacity: 0.6`).
private struct HistoryRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}
