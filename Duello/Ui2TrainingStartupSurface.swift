//
//  Ui2TrainingStartupSurface.swift
//  Duello
//
//  Lot 7-F « UI générique » (préfixe `Ui2`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/TrainingStartupSurface.tsx (`TrainingStartupSurface`,
//      `STARTUP_MODES`, `TrainingStartupMode`)
//
//  Première image d'Entraînement pendant l'évaluation de son gros module : la
//  surface reprend exactement le chrome stable de Mathématiques (année,
//  emplacement de progression, classement) et la barre de modes, contenu vide.
//
//  Réutilise l'existant sans le modifier : `HecJourneyYearTabs` (port de
//  `ProgramYearTabs`) et `ChartPerformanceMetricIcon` (port de
//  `PerformanceMetricIcon`).
//
//  Écarts assumés : la largeur relative des onglets (`flex` 1,28 / 1,1 de la
//  source) est approchée par des largeurs égales ; `useInstalledDesktopLayout`
//  (mode bureau téléchargé) n'a pas d'équivalent iOS. Cible iOS 16.
//
import SwiftUI

/// Modes de la barre de démarrage (`STARTUP_MODES`).
enum Ui2TrainingStartupMode: String, CaseIterable {
    case cours, exercices, colles, annales

    /// Libellé affiché (`label` de la source).
    var label: String {
        switch self {
        case .cours: return "Cours"
        case .exercices: return "Exercices"
        case .colles: return "Colles"
        case .annales: return "Annales"
        }
    }

    /// Symbole SF équivalent aux Ionicons de la source.
    var icon: String {
        switch self {
        case .cours: return "book"
        case .exercices: return "dumbbell"
        case .colles: return "bubble.left.and.bubble.right"
        case .annales: return "books.vertical"
        }
    }
}

/// Surface de démarrage d'Entraînement (`TrainingStartupSurface.tsx`).
struct Ui2TrainingStartupSurface: View {
    /// Année du programme (1 ou 2).
    let programYear: Int
    /// Année du profil, pour l'état des onglets d'année.
    let profileYear: Int
    /// Changement d'année (`onSelectYear` de la source).
    let onSelectYear: (Int) -> Void
    /// État contrôlé optionnel (`selectedMode` de la source).
    var selectedMode: Ui2TrainingStartupMode = .cours
    /// Sélection de mode ; `nil` rend la barre non interactive (aperçu).
    var onSelectMode: ((Ui2TrainingStartupMode) -> Void)? = nil
    /// Résultat réel ou démonstratif placé dans l'emplacement vide.
    var successLabel: String? = nil
    /// Fraction de progression dans [0, 1] (`successFraction`).
    var successFraction: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            metricsHeader
            modeNavigation
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }

    // MARK: En-tête de repères

    private var metricsHeader: some View {
        HStack(spacing: 8) {
            HecJourneyYearTabs(programYear: programYear, onSelectYear: onSelectYear)
            progressSlot
            rankingButton
        }
        .padding(.horizontal, 4)
        .frame(height: 48)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .frame(height: ChartPerformanceOverview.barHeight)
    }

    /// Emplacement de progression, vide tant qu'aucun résultat n'est fourni.
    @ViewBuilder
    private var progressSlot: some View {
        VStack(spacing: 4) {
            if let successLabel {
                Text(successLabel)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                    .monospacedDigit()
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.background)
                        Capsule()
                            .fill(Theme.ink)
                            .frame(width: max(0, min(1, successFraction)) * proxy.size.width)
                    }
                }
                .frame(height: 6)
            }
        }
        .frame(maxWidth: 230)
        .padding(.leading, 6)
        .padding(.trailing, 12)
    }

    /// Bouton du classement XP de mathématiques (`rankingButton`).
    private var rankingButton: some View {
        ChartPerformanceMetricIcon(
            name: "sparkles",
            color: Theme.ink,
            fillColor: Theme.surfaceMuted,
            iconSize: 21,
            size: 40,
            outlined: true
        )
        .frame(width: 40, height: 40)
    }

    // MARK: Barre de modes

    private var modeNavigation: some View {
        HStack(spacing: 5) {
            ForEach(Ui2TrainingStartupMode.allCases, id: \.self) { mode in
                modeTab(mode)
            }
        }
        .padding(4)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            onSelectMode != nil
                ? "Modes d’entraînement de Mathématiques"
                : "Chargement du programme de Mathématiques"
        )
    }

    @ViewBuilder
    private func modeTab(_ mode: Ui2TrainingStartupMode) -> some View {
        let selected = mode == selectedMode
        if let onSelectMode {
            Button { onSelectMode(mode) } label: {
                modeTabLabel(mode, selected: selected)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(mode.label) — Mathématiques")
            .accessibilityAddTraits(selected ? [.isSelected] : [])
        } else {
            modeTabLabel(mode, selected: selected)
        }
    }

    private func modeTabLabel(_ mode: Ui2TrainingStartupMode, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: mode.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
            Text(mode.label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(selected ? Theme.primary : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
