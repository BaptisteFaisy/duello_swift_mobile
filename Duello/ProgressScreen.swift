import SwiftUI

/// Écran « Progression » : avancement de chaque matière, défis et temps
/// d'entraînement. Reprend `src/screens/EnhancedProgressScreen.tsx` : le
/// parcours vient de `SessionStore`, les compteurs de `ProgressStore`, et les
/// items comptés sont ceux réellement servis (`DuelloExerciseCatalog` et le
/// socle de colles `ProgressColleSocle`).
///
/// Le préfixe `Duello` suit `DuelloTextField` : `ProgressView` est déjà pris
/// par SwiftUI, et une déclaration locale masquerait la roue de chargement des
/// autres écrans (`ChallengePlayerView`, `ChallengesView`, `WelcomeView`).
///
/// Découpage (règles de complexité Duello : ≤ 500 lignes et ≤ 10 `func` par
/// fichier) : ce fichier porte l'état, le corps, la barre d'onglets, le routage
/// des onglets et l'état vide. Le filtre de matières et le résumé embarqué sont
/// dans `ProgressSummary.swift`, la lecture des données dans `ProgressData.swift`,
/// les onglets Exercices/Colles dans `ProgressTrainingSections.swift`, l'onglet
/// Défis dans `ProgressDuelSection.swift`, l'onglet Heures dans
/// `ProgressHoursSection.swift`, et les composants partagés (carte, encart,
/// titre de section, état vide, ligne de métrique, barre d'avancement) dans
/// `ProgressComponents.swift`. Aucun type, membre ni signature n'est renommé.
struct DuelloProgressView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var progress: ProgressStore

    /// Mode embarqué : résumé compact de **toutes** les matières, sans onglets
    /// (l'écran est posé dans « Mon compte », qui assure le défilement).
    var embedded: Bool = false

    /// Matières cochées dans le filtre ; `nil` tant que l'élève n'a pas touché
    /// au filtre, tout le parcours étant alors affiché (`selectedSubjects`
    /// initialisé sur toutes les matières côté Expo).
    @State var selectedSubjectNames: Set<String>? = nil
    @State private var selectedTab: ProgressTab = .exercises
    /// Panneau des cases du filtre, déplié ou replié.
    @State var subjectPickerOpen: Bool = false

    /// Init explicite : les `@State`/`@EnvironmentObject` gardent leurs valeurs
    /// par défaut, et `embedded` reste appelable depuis un autre fichier (le
    /// membre à membre synthétisé serait privé, `selectedTab` étant privé).
    init(embedded: Bool = false) {
        self.embedded = embedded
    }

    var body: some View {
        if embedded {
            embeddedContent
        } else {
            standardContent
        }
    }

    // MARK: Corps de l'écran complet

    /// Barre d'onglets, filtre (onglets de matière) puis contenu de l'onglet.
    /// Pas de barre de titre : l'écran vit dans un conteneur, comme Expo.
    private var standardContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                tabBar
                    .padding(.bottom, 20)

                if isSubjectTab {
                    subjectPickerCard
                        .padding(.bottom, 16)
                }

                tabContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        // Un changement de programme repart de toutes les matières.
        .onChange(of: subjectNames) { _ in
            selectedSubjectNames = nil
        }
    }

    // MARK: Sélection de matières

    /// Matières affichées : la sélection explicite, ou tout le parcours.
    var activeSubjectNames: Set<String> {
        selectedSubjectNames ?? Set(subjectNames)
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
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(selectedTab == tab ? Theme.surface : Theme.inkSoft)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(selectedTab == tab ? Theme.primary : Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
    }

    /// Les trois premiers onglets portent le filtre de matières ; « Heures » non.
    private var isSubjectTab: Bool {
        switch selectedTab {
        case .exercises, .colles, .duels: return true
        case .hours: return false
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
