import SwiftUI

/// Écran « Progression » : avancement de chaque matière, défis et temps
/// d'entraînement. Reprend `src/screens/EnhancedProgressScreen.tsx` : le
/// parcours vient de `SessionStore`, les compteurs de `ProgressStore`, et les
/// items comptés sont ceux réellement servis (`DuelloExerciseCatalog`).
///
/// Le préfixe `Duello` suit `DuelloTextField` : `ProgressView` est déjà pris
/// par SwiftUI, et une déclaration locale masquerait la roue de chargement des
/// autres écrans (`ChallengePlayerView`, `ChallengesView`, `WelcomeView`).
///
/// Découpage (règles de complexité Duello : ≤ 500 lignes et ≤ 10 `func` par
/// fichier) : ce fichier porte l'état, le corps, la barre d'onglets, le routage
/// des onglets et l'état vide. La lecture des données est dans
/// `ProgressData.swift`, l'en-tête (sélecteur de matière, résumé compact) dans
/// `ProgressSummary.swift`, les onglets Exercices/Colles dans
/// `ProgressTrainingSections.swift`, l'onglet Défis dans
/// `ProgressDuelSection.swift`, l'onglet Heures dans
/// `ProgressHoursSection.swift`, et les composants partagés (encart, titre de
/// section, ligne de métrique, barre d'avancement) dans
/// `ProgressComponents.swift`. Aucun type, membre ni signature n'est renommé :
/// les membres appelés depuis un autre fichier du découpage sont `internal`,
/// ceux d'un seul fichier restent `private`.
struct DuelloProgressView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var progress: ProgressStore

    /// Matière choisie ; vide tant que l'élève n'a rien choisi, la première
    /// matière du parcours fait alors office de sélection.
    @State var selectedSubjectId: String = ""
    @State private var selectedTab: ProgressTab = .exercises

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if subjects.isEmpty {
                        emptyState
                    } else {
                        subjectPickerCard
                        summaryCard
                        tabBar
                        tabContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: Onglets

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProgressTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.label)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(selectedTab == tab ? Theme.surface : Theme.inkSoft)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(selectedTab == tab ? Theme.ink : Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                                    .stroke(
                                        selectedTab == tab ? Theme.ink : Theme.border,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .exercises: trainingSection(.exercises)
        case .colles: trainingSection(.colles)
        case .duels: duelSection
        case .hours: hoursSection
        }
    }

    // MARK: État vide

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Text("Choisis ton parcours dans « Mon compte »")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Types de l'écran

/// Onglets de la progression, dans l'ordre de `TAB_LABELS` d'Expo.
private enum ProgressTab: String, CaseIterable, Identifiable {
    case exercises
    case colles
    case duels
    case hours

    var id: String { rawValue }

    /// Libellé affiché dans la barre d'onglets.
    var label: String {
        switch self {
        case .exercises: return "Exercices"
        case .colles: return "Colles"
        case .duels: return "Défis"
        case .hours: return "Heures"
        }
    }
}
