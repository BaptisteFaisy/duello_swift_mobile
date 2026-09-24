//
//  ReportPublicProfileStorage.swift
//  Duello
//
//  Port de src/utils/publicProfileStorage.ts (RN) — clés agrégées du profil
//  public et prédicat « cette écriture change-t-elle un profil public ? ».
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/publicProfileStorage.ts — `GRADES_STORAGE_KEY`,
//      `PROGRAM_TASKS_STORAGE_KEY`, `SUBSCRIPTION_STORAGE_KEY`,
//      `PUBLIC_PROFILE_STORAGE_KEYS`, `isPublicProfileStorageKey`.
//    - src/storage/keys.ts — `ACCOUNT_STORAGE_KEYS.*` et
//      `ACCOUNT_STORAGE_PREFIXES.subjects` (valeurs physiques reprises ici).
//
//  Rôle : regrouper les clés logiques dont une écriture locale modifie une
//  donnée visible sur un profil public, et exposer `isPublicProfileStorageKey`,
//  consommé par le coordinateur (`ReportPublicProfilePublisher`) et par l'écran
//  Compte.
//
//  Notes datées :
//    - 2026-09-24 — création (vague 2, unité U9). Les identifiants RN en
//      SCREAMING_CASE deviennent des constantes Swift en camelCase ; la
//      correspondance est notée au-dessus de chacune. Les valeurs physiques des
//      clés (`prepapp-…`) sont reprises telles quelles, donc interchangeables
//      avec le stockage Expo.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `publicProfileStorage.ts` : clés logiques du profil public.
enum ReportPublicProfileStorage {

    /// `GRADES_STORAGE_KEY` = `ACCOUNT_STORAGE_KEYS.grades`.
    static let gradesStorageKey = "prepapp-grades"

    /// `PROGRAM_TASKS_STORAGE_KEY` = `ACCOUNT_STORAGE_KEYS.programTasks`.
    static let programTasksStorageKey = "prepapp-program-tasks"

    /// `SUBSCRIPTION_STORAGE_KEY` = `ACCOUNT_STORAGE_KEYS.subscription`.
    static let subscriptionStorageKey = "prepapp-subscription:v1"

    /// `ACCOUNT_STORAGE_KEYS.activity` : séries jour/semaine/mois publiées.
    static let activityStorageKey = "prepapp-xp-activity"

    /// `ACCOUNT_STORAGE_KEYS.exerciseProgress` : réussites d'exercices publiées.
    static let exerciseProgressStorageKey = "prepapp-exercise-progress"

    /// `ACCOUNT_STORAGE_KEYS.subjectElo` (`SUBJECT_ELO_KEY`).
    static let subjectEloStorageKey = "prepapp-subject-elo:v1"

    /// `ACCOUNT_STORAGE_KEYS.subjectEloHistory` (`SUBJECT_ELO_HISTORY_KEY`).
    static let subjectEloHistoryStorageKey = "prepapp-subject-elo-history:v1"

    /// `ACCOUNT_STORAGE_KEYS.subjectXp` : total d'XP publié.
    static let subjectXpStorageKey = "prepapp-subject-xp:v1"

    /// `ACCOUNT_STORAGE_PREFIXES.subjects` : les statuts de chapitres font aussi
    /// évoluer le pourcentage public.
    static let subjectsPrefix = "prepapp-subjects:"

    /// `PUBLIC_PROFILE_STORAGE_KEYS` : écritures locales qui modifient une
    /// donnée visible sur un profil public. Même ordre que la source.
    static let publicProfileStorageKeys: [String] = [
        gradesStorageKey,
        programTasksStorageKey,
        activityStorageKey,
        exerciseProgressStorageKey,
        subjectEloStorageKey,
        subjectEloHistoryStorageKey,
        subscriptionStorageKey,
        subjectXpStorageKey,
    ]

    /// `isPublicProfileStorageKey` : la clé logique modifie-t-elle une donnée
    /// visible sur un profil public ? Les statuts de chapitres sont qualifiés
    /// par préfixe, tout le reste par appartenance exacte.
    static func isPublicProfileStorageKey(_ logicalKey: String) -> Bool {
        publicProfileStorageKeys.contains(logicalKey)
            || logicalKey.hasPrefix(subjectsPrefix)
    }
}
