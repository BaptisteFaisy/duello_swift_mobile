//
//  SubjHecJourney.swift
//  Duello
//
//  Parcours HEC guidé des maths : étapes, libellés, durées de session, réglages
//  du chrome d'entraînement, variante d'application et chargement différé de la
//  surface du parcours.
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx
//        lignes 399-406 : `CourseNotebookPage`, `HecGuidedStep`.
//        lignes 408-415 : `HEC_MATHS_SESSION_DURATIONS`,
//                         `TRAINING_CHROME_HIDDEN_TRANSLATE_Y`,
//                         `TRAINING_CHROME_SETTLE_SPRING`.
//        lignes 554-558 : `IS_DEVELOPMENT_APP` (variante d'application).
//        lignes 7400-7410 : `openDevelopmentMathsChapter` (état initial du
//                         parcours guidé : étape nulle, durée nulle, position de
//                         lecture 0,35).
//        lignes 7425-7435 : `goToPreviousHecGuidedStep`.
//        lignes 7548-7552 : condition d'affichage de `HecJourneySurface`.
//        lignes 7630-7835 : JSX des étapes guidées (titres, descriptions,
//                         actions, cartes d'exemple, retour).
//        ligne 9869 : ouverture du parcours au lancement de l'onglet Parcours.
//
//  Limite documentée : `HecJourneySurface` elle-même (le parcours 3D des blocs)
//  est déjà portée par le lot `HecJourney*` ; ici on ne porte que le chargement
//  différé de cette surface et la porte d'entrée, pas son contenu.
//  Le ressort Expo (`friction` / `tension`) est traduit vers SwiftUI
//  (`tension` ≈ raideur, `friction` ≈ amortissement) ; la valeur obtenue est
//  suramortie, donc sans dépassement de cible, comme l'exige le commentaire
//  source.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

/// Étapes du parcours HEC guidé (`HecGuidedStep`, SubjectsScreen.tsx:400).
enum SubjHecGuidedStep: String, CaseIterable, Identifiable {
    case duration
    case programmeCheck = "programme-check"
    case courseUpload = "course-upload"
    case generating
    case flashcards
    case learn

    var id: String { rawValue }

    /// Étape précédente (`goToPreviousHecGuidedStep`) : `nil` pour la première,
    /// dont le retour referme le parcours guidé.
    var previous: SubjHecGuidedStep? {
        switch self {
        case .duration: return nil
        case .programmeCheck: return .duration
        case .courseUpload: return .programmeCheck
        case .generating: return .courseUpload
        case .flashcards: return .generating
        case .learn: return .flashcards
        }
    }
}

/// Pages de l'espace de travail d'un chapitre (`CourseNotebookPage`) : l'écran
/// ne connaît pour l'instant que la page « conseils ».
enum SubjCourseNotebookPage: String, CaseIterable, Identifiable {
    case tips
    var id: String { rawValue }
}

/// Constantes du parcours HEC guidé.
enum SubjHecJourneyConstants {
    /// `HEC_MATHS_SESSION_DURATIONS` : durées proposées à l'étape 1, en minutes.
    static let mathsSessionDurations: [Int] = [15, 30, 45, 60]

    /// `openDevelopmentMathsChapter` : position de lecture initiale du cours.
    static let defaultCourseProgress: Double = 0.35

    /// Identifiant de la matière maths, seul chapitre du parcours HEC.
    static let mathsSubjectId = "maths"

    /// État initial du parcours guidé, porté par le store de l'écran.
    struct InitialState: Equatable {
        var step: SubjHecGuidedStep?
        var sessionMinutes: Int?
        var courseProgress: Double
    }

    static let initialState = InitialState(
        step: nil,
        sessionMinutes: nil,
        courseProgress: defaultCourseProgress
    )
}

/// Réglages du chrome d'entraînement qui s'efface au défilement
/// (`TRAINING_CHROME_HIDDEN_TRANSLATE_Y`, `TRAINING_CHROME_SETTLE_SPRING`).
enum SubjTrainingChrome {
    /// Décalage vertical appliqué au chrome masqué, en points.
    static let hiddenTranslateY: CGFloat = -24

    /// Ressort de repli Expo : `{ friction: 26, tension: 60 }`.
    static let settleFriction: Double = 26
    static let settleTension: Double = 60

    /// Ressort SwiftUI équivalent : `tension` → raideur, `friction` →
    /// amortissement. Le rapport d'amortissement vaut ≈ 1,68, donc suramorti :
    /// aucun dépassement de la cible, conformément au commentaire source.
    static var settleAnimation: Animation {
        .interpolatingSpring(
            mass: 1,
            stiffness: settleTension,
            damping: settleFriction,
            initialVelocity: 0
        )
    }
}

/// Variante d'application (`IS_DEVELOPMENT_APP`, SubjectsScreen.tsx:555) : le
/// parcours HEC n'apparaît que dans l'app de développement.
enum SubjAppVariant {
    static let developmentBundleIdentifier = "com.prepapp.mobile.dev"
    static let developmentVariantName = "development"
    static let developmentDisplayName = "Duello Dev"
    static let variantInfoKey = "DuelloAppVariant"
    static let nameInfoKey = "CFBundleDisplayName"

    static var isDevelopmentApp: Bool {
        let bundle = Bundle.main
        if bundle.bundleIdentifier == developmentBundleIdentifier { return true }
        if let variant = bundle.object(forInfoDictionaryKey: variantInfoKey) as? String,
           variant == developmentVariantName {
            return true
        }
        return bundle.object(forInfoDictionaryKey: nameInfoKey) as? String == developmentDisplayName
    }
}

/// Point d'entrée de l'écran Matières (`entryPoint`).
enum SubjHecJourneyEntryPoint: String {
    case training
    case journey
}

/// Porte d'entrée de la surface HEC.
enum SubjHecJourneyEntry {
    /// `HecJourneySurface` remplace l'écran quand l'app est la variante de
    /// développement, qu'aucun chapitre du parcours n'est ouvert, et que l'on
    /// vient du parcours de développement ou de l'onglet Parcours.
    static func shouldShowSurface(
        isDevelopmentApp: Bool = SubjAppVariant.isDevelopmentApp,
        journeyChapterOpen: Bool,
        developmentMathsPageOpen: Bool,
        entryPoint: SubjHecJourneyEntryPoint
    ) -> Bool {
        guard isDevelopmentApp, !journeyChapterOpen else { return false }
        return developmentMathsPageOpen || entryPoint == .journey
    }

    /// Le parcours guidé est l'écran d'entrée de l'onglet Parcours pour la
    /// matière maths (`IS_DEVELOPMENT_APP && entryPoint === 'journey' &&
    /// subject.id === 'maths'`).
    static func shouldOpenJourneyOnLaunch(
        subjectId: String?,
        entryPoint: SubjHecJourneyEntryPoint,
        isDevelopmentApp: Bool = SubjAppVariant.isDevelopmentApp
    ) -> Bool {
        isDevelopmentApp
            && entryPoint == .journey
            && subjectId == SubjHecJourneyConstants.mathsSubjectId
    }
}

/// Surface du parcours HEC chargée en différé (`lazy()` + `<Suspense>` d'Expo).
///
/// Tant que la surface n'est pas prête, le repli plein écran est affiché
/// (`Ouverture du parcours…`) ; le contenu fourni est la vue du parcours déjà
/// portée par le lot `HecJourney*`.
struct SubjHecJourneySurfaceLoader<Content: View>: View {
    @StateObject private var loader: SubjDeferredModuleLoader
    private let content: () -> Content

    init(
        load: @escaping () async throws -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _loader = StateObject(
            wrappedValue: SubjDeferredModuleLoader(surface: .hecJourney, load: load)
        )
        self.content = content
    }

    var body: some View {
        Group {
            if loader.isReady {
                content()
            } else {
                SubjDeferredFeatureFallback(label: fallbackLabel)
            }
        }
        .task { loader.start() }
    }

    private var fallbackLabel: String {
        if case let .feature(label) = SubjDeferredSurface.hecJourney.presentation {
            return label
        }
        return ""
    }
}
