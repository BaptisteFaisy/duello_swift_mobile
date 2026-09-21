//
//  SubjDeferredFallbacks.swift
//  Duello
//
//  Replis des surfaces différées de l'écran Matières. Dans l'app Expo, les
//  écrans volumineux (lecteur d'annales, parcours HEC, cours, clavier
//  mathématique, classement…) étaient chargés par `lazy(() => import(...))` +
//  `<Suspense fallback={...}>`, et deux d'entre eux par une promesse mémoïsée
//  (`loadAnnaleViewer`, `loadDetailedChapterItems`).
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx
//        lignes 304-321 : `AnnaleViewerModule`, `annaleViewerModule`,
//                         `loadAnnaleViewer` (mémoïsation, cache remis à zéro en
//                         cas d'échec pour autoriser une nouvelle tentative).
//        lignes 322-356 : `lazy()` des surfaces (CourseDocumentViewer,
//                         CourseTdPanel, ColleCompletionPanel, MathKeyboard,
//                         PhotoTranscriptionModal, LeaderboardScreen,
//                         HecJourneySurface).
//        lignes 358-369 : `DetailedChapterItemsModule`,
//                         `loadDetailedChapterItems` (mémoïsation `??=`, sans
//                         réinitialisation en cas d'échec).
//        lignes 452-482 : `DeferredFeatureFallback`, `DeferredInlineFallback`,
//                         `DeferredModalFallback` et leurs styles
//                         (`detailContainer`, `recoveryScreen`, `recoveryTitle`,
//                         `deferredInlineFallback*`).
//        lignes 2105, 7554, 7870, 7882, 7960, 8293, 9090 : libellés de repli
//                         réellement affichés.
//
//  Limite documentée : SwiftUI n'a pas de découpage de module paresseux côté
//  application — tout le binaire est déjà chargé. Le coût que le `lazy()`
//  évitait à Metro (parsing JS au premier affichage) disparaît, mais l'état
//  « pas encore prêt » reste utile : c'est le moment où une surface construit
//  son contenu (PDF, génération de flashcards, index d'énoncés). Les replis
//  sont donc portés comme vues de chargement / indisponibilité, et
//  `SubjDeferredModuleLoader` rejoue la mémoïsation et la reprise sur échec.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

/// État d'une surface différée (`Suspense` + promesse mémoïsée d'Expo).
enum SubjDeferredModuleState: Equatable {
    case idle
    case loading
    case ready
    case failed
}

/// Comment un repli s'affiche dans l'écran, tel que lu dans le JSX source.
enum SubjDeferredPresentation: Equatable {
    /// Ligne de chargement dans le flux (`DeferredInlineFallback`).
    case inline(String)
    /// Plein écran de chargement (`DeferredFeatureFallback`).
    case feature(String)
    /// Plein écran présenté en modale (`DeferredModalFallback`).
    case modal(String)
    /// Surface chargée en tâche de fond, sans repli affiché
    /// (`loadDetailedChapterItems`).
    case module
}

/// Surfaces différées de l'écran Matières et leur repli.
enum SubjDeferredSurface: String, CaseIterable, Identifiable {
    case annaleViewer
    case detailedChapterItems
    case hecJourney
    case courseDocument
    case courseTdPanel
    case colleCompletion
    case mathKeyboard
    case leaderboard

    var id: String { rawValue }

    var presentation: SubjDeferredPresentation {
        switch self {
        case .annaleViewer: return .modal("Ouverture du sujet…")
        case .detailedChapterItems: return .module
        case .hecJourney: return .feature("Ouverture du parcours…")
        case .courseDocument: return .feature("Ouverture du cours…")
        case .courseTdPanel: return .feature("Ouverture du TD…")
        case .colleCompletion: return .feature("Ouverture de la colle…")
        case .mathKeyboard: return .inline("Ouverture du clavier…")
        case .leaderboard: return .feature("Ouverture du classement…")
        }
    }

    /// `true` quand le source réarme la promesse après un échec
    /// (`loadAnnaleViewer`) ; `false` quand la promesse mémoïsée est conservée
    /// telle quelle (`loadDetailedChapterItems`).
    var retriesOnFailure: Bool { self != .detailedChapterItems }
}

/// Chargement paresseux mémoïsé d'une surface volumineuse.
///
/// Port de `loadAnnaleViewer` / `loadDetailedChapterItems` : le travail n'est
/// lancé qu'une fois, l'état est partagé, et un échec peut laisser la place à
/// une nouvelle tentative (`retriesOnFailure`).
@MainActor
final class SubjDeferredModuleLoader: ObservableObject {
    @Published private(set) var state: SubjDeferredModuleState = .idle

    let surface: SubjDeferredSurface
    private let retriesOnFailure: Bool
    private let load: () async throws -> Void
    private var task: Task<Void, Never>?

    init(
        surface: SubjDeferredSurface,
        load: @escaping () async throws -> Void
    ) {
        self.surface = surface
        self.retriesOnFailure = surface.retriesOnFailure
        self.load = load
    }

    var isReady: Bool { state == .ready }

    /// Lance le chargement si la surface n'est pas déjà prête ou en cours.
    func start() {
        guard task == nil, state == .idle || (state == .failed && retriesOnFailure) else { return }
        state = .loading
        task = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.load()
                self.state = .ready
            } catch {
                self.state = .failed
            }
            self.task = nil
        }
    }

    /// Remet la surface au repos (`annaleViewerModule = null` du source).
    func reset() {
        task?.cancel()
        task = nil
        state = .idle
    }
}

/// Plein écran de chargement d'une surface différée
/// (`detailContainer` + `recoveryScreen` + `recoveryTitle`).
struct SubjDeferredFeatureFallback: View {
    let label: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(label)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .background(Theme.background)
    }
}

/// Ligne de chargement dans le flux (`deferredInlineFallback`, hauteur 72 pt).
struct SubjDeferredInlineFallback: View {
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
    }
}

/// Repli plein écran destiné à être présenté en modale
/// (`DeferredModalFallback`, non fermable : `onRequestClose` ne fait rien).
///
/// À utiliser avec `subjDeferredModal(label:isPresented:)`, qui présente le
/// contenu en plein écran et neutralise le balayage de fermeture.
struct SubjDeferredModalFallback: View {
    let label: String

    var body: some View {
        SubjDeferredFeatureFallback(label: label)
    }
}

extension View {
    /// Présente une surface différée en plein écran, non fermable par
    /// balayage — équivalent de `DeferredModalFallback` en Expo.
    func subjDeferredModal(label: String, isPresented: Binding<Bool>) -> some View {
        fullScreenCover(isPresented: isPresented) {
            SubjDeferredModalFallback(label: label)
                .interactiveDismissDisabled(true)
        }
    }
}
