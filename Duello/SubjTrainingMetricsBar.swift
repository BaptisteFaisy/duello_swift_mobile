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
//  V2 (2026-09-29, écart 06#5) : la barre passe en noir comme la source —
//  `trainingMetricsBar` `backgroundColor: '#000000'` (`SubjectsScreen.tsx:10794-10798`),
//  compteur `trainingProgressTextOnDark` blanc (`:12150-12152`, `renderTrainingProgressControl(true)`),
//  pastille de classement `PerformanceMetricIcon` noire cerclée de blanc avec
//  `sparkles` blanc (`:9803-9808`). Le sélecteur d'année (`ProgramYearTabs`,
//  `tabs` `#000000` / `tabSelected` blanc / `tabText` blanc) suit la même bascule,
//  sans quoi la capsule claire resterait visible sur la barre noire.
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
        HStack(spacing: 8) {
            yearTabs
            progress
            rankingButton
        }
        .padding(.horizontal, 4)
        .frame(height: 48)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Sélecteur d'année (`ProgramYearTabs.tsx`)

    /// Deux puces `1re` / `2e` dans une capsule noire, l'année choisie sur fond
    /// blanc à libellé encre — `compactTabs` + `matchedTabs` de la source
    /// (`ProgramYearTabs.tsx:116-160` : `tabs` `#000000`, `tabSelected` blanc,
    /// `tabText` blanc, `tabTextSelected` encre).
    private var yearTabs: some View {
        HStack(spacing: 2) {
            ForEach([1, 2], id: \.self) { value in
                yearTab(value)
            }
        }
        .padding(2)
        .frame(height: 40)
        .background(Color.black)
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
                .foregroundStyle(selected ? Theme.ink : Color.white)
                .frame(minWidth: 29, minHeight: 36)
                .background(selected ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Programme de \(value == 1 ? "1re" : "2e") année")
        .accessibilityValue(value == profileYear ? "Votre année actuelle" : "")
    }

    // MARK: Avancement de la matière (`trainingProgressControl`)

    /// « X/Y sujets réussis » puis la piste d'avancement — texte centré blanc
    /// (`trainingProgressTextOnDark`), piste de 6 points sur fond blanc,
    /// remplissage à l'encre.
    private var progress: some View {
        VStack(spacing: 4) {
            Text("\(succeeded)/\(total) sujets réussis")
                .font(.system(size: 11, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Color.white)
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

    /// Pastille `sparkles` de la barre (`PerformanceMetricIcon`, `:9803-9808`) :
    /// cercle 40 pt noir cerclé de blanc (1,5 pt), icône `sparkles` blanche 21 —
    /// ouvre le classement XP, comme `setRankingOpen(true)` de la source.
    private var rankingButton: some View {
        Button(action: onOpenRanking) {
            IonIcon(name: "sparkles", size: 21, color: Color.white)
                .frame(width: 40, height: 40)
                .background(Color.black)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ouvrir le classement de Mathématiques")
    }
}
