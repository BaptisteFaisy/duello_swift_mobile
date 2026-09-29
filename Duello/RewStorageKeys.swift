//
//  RewStorageKeys.swift
//  Duello
//
//  Clés logiques des données appartenant à un compte (table centrale).
//
//  Fichier source Expo porté (valeurs et libellés repris mot pour mot) :
//    - src/storage/keys.ts
//        `ACCOUNT_STORAGE_KEYS` (toutes les clés exactes),
//        `ACCOUNT_STORAGE_PREFIXES` (préfixes par objet),
//        `annaleDraftStorageKey`, `subjectProgramStorageKey`.
//
//  Ces clés passent toujours par le stockage cloisonné par compte
//  (`RewStorageScope.accountStorageKey` / `accountStoragePrefix`) : la clé
//  logique seule ne suffit jamais. Les clés de session et d'authentification,
//  volontairement globales, vivent dans `AcctAuthSession.swift`.
//
//  Découpage (29/09/2026) : cette table est la source unique des constantes.
//  La **politique** des clés réellement synchronisées côté serveur reste dans
//  `RewRemoteAccountData+SyncedKeys.swift` (`RewServerSyncedKeys`), déjà portée
//  ; `isServerSyncedAccountKey` y renvoie. Les constructeurs de clé par objet
//  déjà posés près de leur store ne sont pas dupliqués ici :
//    - `courseDocument*` → `TrainCourseStore.swift` ;
//    - `courseKnowledge*` → `TrainCourseKnowledgeStore.swift` ;
//    - `courseFlashcards*` → `TrainChapterFlashcards.swift` ;
//    - `courseTd*` → `CourseTdStore.swift` ;
//    - `chapterNotebook*` → `SubjChapterNotebook.swift` ;
//    - `colleCompletion*` → `CollCompletionStore.swift` ;
//    - `hecJourneyTimeline` (v2) → `HecJourneyStore.swift`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `keys.ts` : clés logiques et préfixes des données de compte.
enum RewStorageKeys {
    /// `ACCOUNT_STORAGE_KEYS` : clés exactes des données d'un compte.
    enum Account {
        static let classSchedule = "prepapp-class-schedule"
        static let programTasks = "prepapp-program-tasks"
        static let grades = "prepapp-grades"
        static let socialState = "prepapp-social-state"
        static let feedLikes = "prepapp-feed-likes"
        static let activity = "prepapp-xp-activity"
        static let subjectElo = "prepapp-subject-elo:v1"
        static let subjectEloHistory = "prepapp-subject-elo-history:v1"
        static let annaleAttempts = "prepapp-annale-attempts:v1"
        static let annaleCopyCorrections = "prepapp-annale-copy-corrections:v1"
        static let correctionGradeHistory = "prepapp-correction-grade-history:v1"
        /// Durées mesurées des corrections de réponses, propres à cet appareil.
        static let correctionDurationStats = "prepapp-correction-duration-stats:v1"
        /// Hauteur de l'énoncé choisie à la main, exercice par exercice.
        static let annaleSplits = "prepapp-annale-splits:v1"
        static let exerciseProgress = "prepapp-exercise-progress"
        static let challengeAllowStartedExercises = "prepapp-challenge-allow-started-exercises:v1"
        static let correctionQuota = "prepapp-correction-quota:v1"
        static let subscription = "prepapp-subscription:v1"
        static let notifications = "prepapp-notifications"
        /// Choix local du compte pour les alertes système de cet appareil.
        static let pushNotificationsEnabled = "prepapp-push-notifications-enabled:v1"
        /// Jeton Expo de ce compte sur cet appareil ; il ne doit pas être
        /// restauré ailleurs.
        static let pushNotificationToken = "prepapp-push-notification-token:v1"
        /// Autorisation locale, versionnée, avant tout partage avec un
        /// prestataire d’IA.
        static let aiDataSharingConsent = "prepapp-ai-data-sharing-consent:v1"
        /// Brouillons de copie des événements, suffixés par identifiant d'événement.
        static let eventDrafts = "prepapp-event-drafts:v1"
        /// Identifiants des événements déjà vus, par ordre d'ajout.
        static let seenEvents = "prepapp-seen-events:v1"
        /// Dernière soumission dont le classement a été ouvert, exercice par exercice.
        static let exerciseRankingSeen = "prepapp-exercise-ranking-seen:v1"
        static let mathOcrSettings = "prepapp-math-ocr-settings"
        static let mathsProgramPlacement = "prepapp-maths-program-placement:v1"
        /// Nombre de changements d'option ECG confirmés, plafonné côté interface.
        static let ecgOptionChangeCount = "prepapp-ecg-option-change-count:v1"
        /// Ancienne frise commune, conservée uniquement comme source de migration.
        static let hecJourneyTimeline = "prepapp-hec-journey-timeline:v1"
        static let hecJourneyTimelineYearMigration = "prepapp-hec-journey-timeline-year-migration:v1"
        static let hecJourneyAnimationProgress = "prepapp-hec-journey-animation-progress:v1"
        static let hecJourneyAdmission = "prepapp-hec-journey-admission:v1"
        static let ollamaSettings = "prepapp-ollama-settings"
        static let trainingTime = "prepapp-training-time:v1"
        static let subjectXp = "prepapp-subject-xp:v1"
        static let usageAnalytics = "prepapp-usage-analytics:v1"
        static let adminApiToken = "prepapp-admin-api-token:v1"
        static let courseProgressLegendDismissed = "prepapp-course-progress-legend-dismissed:v1"
        static let eloLeagueThresholdHintDismissed = "prepapp-elo-league-threshold-hint-dismissed:v1"
        static let profilePhotoHintDismissed = "prepapp-profile-photo-hint-dismissed:v1"
        static let trainingWorkflowTipDismissed = "prepapp-training-workflow-tip-dismissed:v1"
        static let trainingWorkflowTipState = "prepapp-training-workflow-tip-state:v2"
    }

    /// `ACCOUNT_STORAGE_PREFIXES` : préfixes des données de compte par objet.
    enum Prefixes {
        static let annaleDraft = "prepapp-annale-draft:"
        static let courseDocument = "prepapp-course-document:v1:"
        /// Documents qualifiés par année ; la clé v1 reste lue pour migration.
        static let courseDocumentByYear = "prepapp-course-document:v2:"
        static let courseKnowledgeIndex = "prepapp-course-knowledge-index:v1:"
        static let courseKnowledgeJob = "prepapp-course-knowledge-job:v1:"
        static let courseFlashcards = "prepapp-course-flashcards:v1:"
        static let courseTd = "prepapp-course-td:v1:"
        static let chapterNotebook = "prepapp-chapter-notebook:v1:"
        static let colleCompletion = "prepapp-colle-completion:v1:"
        static let subjects = "prepapp-subjects:"
        static let hecJourneyTimeline = "prepapp-hec-journey-timeline:v2:"
    }

    /// `annaleDraftStorageKey` : clé logique du brouillon de copie d'une annale,
    /// suffixée par l'identifiant de l'item.
    static func annaleDraftStorageKey(_ itemId: String) -> String {
        "\(Prefixes.annaleDraft)\(itemId)"
    }

    /// `subjectProgramStorageKey` : clé logique du programme d'une matière, par
    /// filière et par année.
    static func subjectProgramStorageKey(track: String, year: Int) -> String {
        "\(Prefixes.subjects)\(track):\(year)"
    }

    /// `isServerSyncedAccountKey` : données durables restaurées sur les appareils
    /// authentifiés du même compte. Renvoie à `RewServerSyncedKeys` (port de la
    /// politique `SERVER_SYNCED_*` du même fichier source).
    static func isServerSyncedAccountKey(_ logicalKey: String) -> Bool {
        RewServerSyncedKeys.isServerSyncedAccountKey(logicalKey)
    }
}
