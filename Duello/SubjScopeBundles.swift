//
//  SubjScopeBundles.swift
//  Duello
//
//  Résolution des banques d'énoncés servies pour la matière affichée : quand une
//  fiche est listée depuis une autre filière que celle du profil, son énoncé vit
//  dans la banque de cette filière, pas dans la banque principale.
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx
//        lignes 93-98  : `EXERCISE_SCOPE_TO_BUNDLE`, réplique locale de la table
//                        du catalogue (4 filières ECG).
//        lignes 6735-6756 : `resolveExerciseBundle` — les scopes sont balayés
//                        dans l'ordre du source, le scope courant exclu ; le
//                        premier qui liste l'identifiant gagne ; à défaut on
//                        retombe sur `primaryExerciseBundleId` (banque d'énoncés
//                        de l'année affichée, cf. `TrainContent.exerciseBundleIds`).
//    - src/data/trainingCardCatalogs.ts (lignes 72-80)
//        table de référence `EXERCISE_BUNDLE_IDS` (6 entrées, MPSI incluse) :
//        citée pour mémoire, non dupliquée — la réplique locale de l'écran ne
//        contient que les 4 filières ECG, et les banques MPSI sont déjà
//        résolues par `TrainContent.exerciseBundleIds`.
//
//  Limite documentée : `exerciseCardCatalogItemIds(scope)` (index embarqué des
//  fiches) n'existe pas côté Swift — le magasin de contenu est servi par l'API.
//  L'appelant fournit donc les identifiants de la banque via une closure
//  `itemIdsInScope`, exactement comme le rendu de l'écran les lisait au vol.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Filières ECG dont l'écran connaît la banque d'énoncés d'exercices
/// (`EXERCISE_SCOPE_TO_BUNDLE`, SubjectsScreen.tsx:93).
enum SubjExerciseScope: String, CaseIterable, Identifiable {
    case ecgAppliquees1 = "ecg-appliquees-1"
    case ecgAppliquees2 = "ecg-appliquees-2"
    case ecgApprofondies1 = "ecg-approfondies-1"
    case ecgApprofondies2 = "ecg-approfondies-2"

    var id: String { rawValue }

    /// Banque d'énoncés servie pour cette filière (les identifiants de banque
    /// sont ceux de `OfflContentBundleId`, déjà porté).
    var bundleId: OfflContentBundleId {
        switch self {
        case .ecgAppliquees1: return .ecgApplied1Statements
        case .ecgAppliquees2: return .ecgApplied2Statements
        case .ecgApprofondies1: return .ecgAdvanced1Statements
        case .ecgApprofondies2: return .ecgAdvanced2Statements
        }
    }
}

/// Table `EXERCISE_SCOPE_TO_BUNDLE` et résolution de la banque d'une fiche.
enum SubjScopeBundles {
    /// Scopes balayés par la résolution, dans l'ordre exact du source
    /// (SubjectsScreen.tsx:6741-6746).
    static let scannedScopes: [SubjExerciseScope] = SubjExerciseScope.allCases

    /// Scope correspondant à un identifiant brut, `nil` si la filière n'a pas de
    /// banque d'énoncés connue de l'écran (MPSI, lycée).
    static func scope(_ rawValue: String) -> SubjExerciseScope? {
        SubjExerciseScope(rawValue: rawValue)
    }

    /// `EXERCISE_SCOPE_TO_BUNDLE[scope]` : banque servie pour un scope donné.
    static func bundle(forScope rawValue: String) -> OfflContentBundleId? {
        SubjExerciseScope(rawValue: rawValue)?.bundleId
    }

    /// Banque qui contient réellement l'énoncé d'une fiche.
    ///
    /// Les scopes autres que le scope courant sont balayés dans l'ordre du
    /// source ; le premier qui liste `itemId` gagne. Si aucun ne le liste, la
    /// banque principale du profil est retenue (`primaryBundleId`), qui peut
    /// elle-même être absente (lycée).
    static func resolveExerciseBundle(
        itemId: String,
        currentScope: SubjExerciseScope?,
        itemIdsInScope: (SubjExerciseScope) -> [String]?,
        primaryBundleId: OfflContentBundleId?
    ) -> OfflContentBundleId? {
        for scope in scannedScopes where scope != currentScope {
            if let ids = itemIdsInScope(scope), ids.contains(itemId) {
                return scope.bundleId
            }
        }
        return primaryBundleId
    }

    /// Scope de la banque principale, pour l'exclure du balayage : la banque
    /// principale de l'année affichée est déjà lue par `TrainContent`.
    static func primaryScope(track: String, specialty: String, year: Int) -> SubjExerciseScope? {
        let normalized = TrainContent.normalize(specialty)
        guard TrainContent.normalize(track).contains("ecg") else { return nil }
        if normalized.contains("applique") {
            return year == 2 ? .ecgAppliquees2 : .ecgAppliquees1
        }
        return year == 2 ? .ecgApprofondies2 : .ecgApprofondies1
    }
}
