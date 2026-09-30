//
//  SubjTrainingMetricsBar.swift
//  Duello
//
//  Barre de métriques de la page d'entraînement d'une matière (préfixe `Subj`).
//
//  Fichiers source Expo portés :
//    - `src/screens/SubjectsScreen.tsx` : `trainingMetricsBar` (l. 10664),
//      `trainingMetricsHeader` (l. 10659) et `trainingProgressControl`
//      (l. 7474-7490) — la barre noire arrondie qui coiffe la page
//      Mathématiques de l'onglet Entraînement : sélecteur d'année, compteur
//      « X/Y sujets réussis » avec sa piste, et accès au classement XP ;
//    - `src/components/ProgramYearTabs.tsx` : le sélecteur d'année (deux puces
//      `1re` / `2e`, l'année choisie sur fond blanc).
//
//  Cible : iOS 16, aucune API iOS 17.
//
//  V3 (2026-09-30, « retour gris » `92e3e639d`) : la barre reprend le gris de la
//  source — `trainingMetricsBar` `backgroundColor: colors.surfaceMuted`
//  (`SubjectsScreen.tsx:10794-10798`), compteur `trainingProgressText`
//  `mutedSurfaceText` (`:12150-12152`), pastille de classement
//  `PerformanceMetricIcon` `surfaceMuted` cerclée d'encre avec `sparkles` encre
//  (`:9817-9824`). Le sélecteur d'année (`ProgramYearTabs`, `tabs`
//  `surfaceMuted` / `tabSelected` `primary` / `tabText` `mutedSurfaceText`)
//  suit la même bascule. La zone d'en-tête de 60 pt (`trainingMetricsHeader`,
//  `:10800-10803`) est rétablie autour de la barre de 48 pt.
//
import SwiftUI

/// En-tête de la page Mathématiques : année du programme, avancement de la
/// matière, classement XP.
struct SubjTrainingMetricsBar: View {
    /// Année du programme affichée (1 ou 2).
    let programYear: Int
    /// Année du compte, marquée comme « l'année actuelle » dans le sélecteur.
    let profileYear: Int
    let succeeded: Int
    let total: Int
    let onSelectYear: (Int) -> Void
    let onOpenRanking: () -> Void

    var body: some View {
        // `trainingMetricsHeader` (60 pt) coiffe `trainingMetricsBar` (48 pt) :
        // la zone réserve la hauteur exacte du bandeau de la source
        // (`SubjectsScreen.tsx:10800-10803`), la barre grise restant centrée
        // dedans — sans quoi le squelette (qui réserve déjà 60) sautait de 12 pt
        // à la fin du chargement.
        HStack(spacing: 0) {
            yearTabs
            Spacer(minLength: 8)
            progress
                .padding(.leading, 6)
                .padding(.trailing, 12)
            Spacer(minLength: 8)
            rankingButton
        }
        .padding(.horizontal, 4)
        .frame(height: 48)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(height: 60)
    }

    // MARK: Sélecteur d'année (`ProgramYearTabs.tsx`)

    /// Deux puces `1re` / `2e` dans une capsule grise, l'année choisie sur fond
    /// `primary` à libellé blanc — `compactTabs` + `matchedTabs` de la source
    /// (`ProgramYearTabs.tsx:122,148,154,159` : `tabs` `surfaceMuted`,
    /// `tabSelected` `primary`, `tabText` `mutedSurfaceText`, `tabTextSelected`
    /// blanc).
    private var yearTabs: some View {
        HStack(spacing: 2) {
            ForEach([1, 2], id: \.self) { value in
                yearTab(value)
            }
        }
        .padding(2)
        .frame(height: 40)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Année du programme")
    }

    private func yearTab(_ value: Int) -> some View {
        let selected = programYear == value
        return Button {
            guard !selected else { return }
            onSelectYear(value)
        } label: {
            Text(value == 1 ? "1re" : "2e")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(selected ? Color.white : Theme.mutedSurfaceText)
                .frame(minWidth: 29, minHeight: 36)
                .background(selected ? Theme.primary : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Programme de \(value == 1 ? "1re" : "2e") année")
        .accessibilityValue(value == profileYear ? "Votre année actuelle" : "")
    }

    // MARK: Avancement de la matière (`trainingProgressControl`)

    /// « X/Y sujets réussis » puis la piste d'avancement — texte centré
    /// `mutedSurfaceText` (`trainingProgressText`), piste de 6 points sur fond
    /// blanc, remplissage à l'encre.
    private var progress: some View {
        VStack(spacing: 4) {
            Text("\(succeeded)/\(total) sujets réussis")
                .font(.system(size: 11, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.mutedSurfaceText)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.background)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.ink)
                        .frame(width: fillWidth(in: geometry.size.width))
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: 230)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(succeeded) sujets réussis sur \(total)")
    }

    private func fillWidth(in available: CGFloat) -> CGFloat {
        guard total > 0, succeeded > 0 else { return 0 }
        let fraction = min(1, max(0, Double(succeeded) / Double(total)))
        return max(6, available * CGFloat(fraction))
    }

    // MARK: Accès au classement XP

    /// Pastille `sparkles` de la barre (`PerformanceMetricIcon`, `:9817-9824`) :
    /// cercle 40 pt `surfaceMuted` cerclé d'encre (1,5 pt), icône `sparkles`
    /// encre 21 — ouvre le classement XP, comme `setRankingOpen(true)` de la
    /// source.
    private var rankingButton: some View {
        Button(action: onOpenRanking) {
            IonIcon(name: "sparkles", size: 21, color: Theme.ink)
                .frame(width: 40, height: 40)
                .background(Theme.surfaceMuted)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.ink, lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ouvrir le classement de Mathématiques")
    }
}
