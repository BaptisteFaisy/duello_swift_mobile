//
//  CollColleBanks.swift
//  Duello
//
//  Types des colles retranscrites du parcours (parcours couvert, forme d'une
//  colle) et banques servies.
//
//  Fichiers source Expo portés :
//    - src/data/colleExercises.ts
//        `ColleScope`, `ColleSeed`, `ItemSeed` (les tables d'énoncés — Fontaine,
//        Lécluse, Clemenceau, Trouvé, ESP HEC, dossier partagé — ne sont pas
//        portées : elles sont servies par l'API de contenu).
//    - src/data/colleBanks.ts
//        `BUNDLE_IDS` (banque servie pour chaque parcours).
//
//  Limite documentée : `colleBank`, `colleBankChapter` et `colleCatalogItemIds`
//  assemblent les banques publiées et l'index embarqué via le magasin de contenu
//  (`servedBank`, `contentStore`). Ce magasin n'existe pas côté Swift : les
//  colles sont servies par l'API de contenu, comme les exercices, et consommées
//  par `DuelloAPI`. Seuls les types et le nom des banques sont portés ici.
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Parcours et année couverts par une banque de colles (`ColleScope`).
enum CollColleScope: String, Codable, CaseIterable, Identifiable {
    case ecgAppliquees1 = "ecg-appliquees-1"
    case ecgAppliquees2 = "ecg-appliquees-2"
    case ecgApprofondies1 = "ecg-approfondies-1"
    case ecgApprofondies2 = "ecg-approfondies-2"
    case mpsi1 = "mpsi-1"

    var id: String { rawValue }

    /// `BUNDLE_IDS` de `colleBanks.ts` : banque servie pour ce parcours.
    var bundleId: String {
        switch self {
        case .ecgAppliquees1: return "colles-ecg-appliquees-1"
        case .ecgAppliquees2: return "colles-ecg-appliquees-2"
        case .ecgApprofondies1: return "colles-ecg-approfondies-1"
        case .ecgApprofondies2: return "colles-ecg-approfondies-2"
        case .mpsi1: return "colles-mpsi-1"
        }
    }
}

/// Colle retranscrite d'un chapitre (`ColleSeed`).
///
/// La clé reste stable : la progression enregistrée y est rattachée.
struct CollColleSeed: Codable, Equatable, Identifiable {
    /// Suffixe d'identifiant, stable.
    var key: String
    var title: String
    /// Difficulté de 1 à 5.
    var difficulty: Int
    /// Énoncé complet, affiché dans la fiche de l'exercice.
    var statement: String
    /// Corrigé retranscrit, affiché dans le lecteur et servi au correcteur.
    var solution: String?
    /// Colle et fichier d'origine, pour retrouver le sujet dans le Drive.
    var source: String
    /// Format signalé sur la fiche (`ExerciseBadge`), non porté : libellés.
    var badges: [String]?
    /// Domaine court et fiable (`AnnaleTheme`), non porté : libellé.
    var theme: String?
    /// Notions principales relevées exercice par exercice.
    var notions: [String]?
    /// Épreuve d'origine, ouvrable depuis la fiche.
    var sourceUrl: String?
    /// Page de l'énoncé dans le document source, lorsqu'elle est connue.
    var sourcePage: Int?
    /// Corrigé officiel d'origine, lorsqu'il est publié séparément.
    var solutionUrl: String?
    /// Connaissances relevées à la main (`ChapterPrerequisite`), non porté : clés.
    var requiredChapters: [String]?

    var id: String { key }
}
