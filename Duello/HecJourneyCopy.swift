import Foundation

/// Tous les libellés du parcours HEC, repris **mot pour mot** de
/// `src/components/HecJourney.tsx`, `src/components/HecJourneyScene.tsx`,
/// `src/components/HecJourneyCalendarPicker.tsx` et
/// `src/components/HecJourneyAdmissionScreen.tsx`.
///
/// Regroupés ici pour qu'aucune vue ne réécrive un texte : la source Expo les
/// tient déjà en constantes (`SCHOOL_HOLIDAY_OPTION_LABELS`,
/// `JOURNEY_SHORTCUTS`, libellés d'accessibilité) ou en clair dans le JSX.
///
/// Les alertes d'échec de la source (`Ajout impossible`,
/// `Suppression impossible`, `Enregistrement impossible`) et l'état d'erreur de
/// la scène (`Parcours momentanément indisponible`, `RECHARGER`) ne sont pas
/// repris : le stockage local est synchrone et sans erreur possible, et la
/// frise n'a plus de contexte graphique à perdre. Voir les en-têtes de
/// `HecJourneyAddFlow.swift`, `HecJourneySceneView.swift` et
/// `HecJourneyAdmissionView.swift`.
enum HecJourneyCopy {

    // MARK: En-tête et frise

    static let screenTitle = "PARCOURS HEC"
    static let endOfJourney = "fin du parcours"
    static let nextYearButton = "PARCOURS DE 2E ANNÉE"
    static let previousYearButton = "PARCOURS DE 1RE ANNÉE"
    static let registrationTitle = "INSCRIPTION"

    /// Guide de la première étape, une ligne par paragraphe.
    static let registrationGuide = [
        "1. Tu choisis un chapitre.",
        "2. Tu travailles.",
        "3. Tu ajoutes tes colles et tes DS.",
        "4. Tu regardes tes progrès.",
        "5. Tu avances jusqu’aux concours.",
    ]

    /// `PROGRAM_YEAR_LABELS` de `data/tracks.ts`.
    static let yearLabels: [Int: String] = [1: "1re année", 2: "2e année"]

    // MARK: Raccourcis de navigation

    static let shortcutCurrent = "Aller au bloc actuel"
    static let shortcutEnd = "Aller à la fin du parcours"
    static let shortcutStart = "Aller à la première étape du parcours"

    // MARK: Ajout d'un bloc

    static let dateRowLabel = "DATE DU BLOC"
    static let panelTypes = "NOUVEAU BLOC"
    static let panelTypesForBlock = "CHOISIR POUR CE BLOC"
    static let panelChapters = "CHOISIR UN CHAPITRE"
    static let panelHolidays = "CHOISIR LES VACANCES"
    static let panelHolidayZone = "ZONE OU DATE DE DÉBUT"
    static let panelConfirmation = "CONFIRMER LE BLOC"
    static let panelConfirmationPlural = "CONFIRMER LES BLOCS"
    static let panelDeleteConfirmation = "SUPPRIMER CE BLOC ?"

    static let holidayZoneHint = "Choisis ta zone scolaire, ou règle la date ci-dessus."
    static let allHolidaysTitle = "Toutes les vacances"
    static let allHolidaysBlockTitle = "Toutes les vacances scolaires"
    static let modifyButton = "MODIFIER"
    static let confirmButton = "CONFIRMER"
    static let cancelButton = "ANNULER"
    static let deleteButton = "SUPPRIMER"

    /// « 3 BLOCS DE VACANCES ».
    static func holidayBlockCount(_ count: Int) -> String {
        "\(count) BLOCS DE VACANCES"
    }

    /// « ZONE A », « ZONE B », « ZONE C ».
    static func zoneButton(_ zone: HecJourneySchoolZone) -> String {
        "ZONE \(zone.rawValue)"
    }

    /// « UTILISER LE 12 OCTOBRE ».
    static func useCustomDate(_ date: String) -> String {
        "UTILISER LE \(date.uppercased())"
    }

    // MARK: Suppression

    static let deleteNeutralTitle = "Supprimer ce bloc neutre ?"
    static let deleteBlockQuestion = "Supprimer ce bloc ?"
    static let deleteBlockMessage = "Il disparaîtra de ton parcours HEC."

    // MARK: Accessibilité

    static let a11yScene = "Parcours temporel 3D vers HEC. Faire défiler verticalement pour parcourir les blocs datés."
    static let a11yRanking = "Ouvrir le classement XP de mathématiques"
    static let a11yBackToJourney = "Revenir au parcours HEC"
    static let a11yBackToParcours = "Revenir à Parcours"
    static let a11yAddBlock = "Ajouter un bloc au parcours HEC"
    static let a11yCloseAdd = "Fermer l’ajout"
    static let a11yBackStep = "Revenir à l’étape précédente"
    static let a11yDeleteNeutral = "Supprimer ce bloc neutre"
    static let a11yDeleteBlock = "Supprimer ce bloc du parcours HEC"
    static let a11yDeleteBlockConfirm = "Confirmer la suppression du bloc"
    static let a11yCancelDelete = "Annuler la suppression"
    static let a11yPreviousDay = "Jour précédent"
    static let a11yNextDay = "Jour suivant"
    static let a11yOpenCalendar = "Ouvrir le calendrier"
    static let a11yNextYear = "Continuer vers le parcours de 2e année"
    static let a11yPreviousYear = "Revenir au parcours de 1re année"
    static let a11yProgramYear = "Année du programme"

    /// « Ajouter : Colle ».
    static func a11yAddType(_ type: HecJourneyBlockType) -> String {
        "Ajouter : \(HecJourneyBlocks.label(type))"
    }

    /// « Ajouter et ouvrir Chapitre 4 ».
    static func a11yAddChapter(_ name: String) -> String {
        "Ajouter et ouvrir \(name)"
    }

    /// « Choisir Vacances de Noël ».
    static func a11yChooseHoliday(_ label: String) -> String {
        "Choisir \(label)"
    }

    /// « Choisir la zone A ».
    static func a11yChooseZone(_ zone: HecJourneySchoolZone) -> String {
        "Choisir la zone \(zone.rawValue)"
    }

    /// « Ouvrir HEC Paris » (blason de la dernière étape).
    static func a11yOpenBlock(_ title: String) -> String {
        "Ouvrir \(title)"
    }
}

/// Libellés du sélecteur de date (`HecJourneyCalendarPicker.tsx`).
enum HecJourneyCalendarCopy {
    /// `CALENDAR_WEEKDAYS`.
    static let weekdays = ["L", "M", "M", "J", "V", "S", "D"]
    /// `CALENDAR_CELL_COUNT`.
    static let cellCount = 42
    static let previousMonth = "Mois précédent"
    static let nextMonth = "Mois suivant"

    /// « Choisir le 12 octobre ».
    static func a11yChooseDay(_ date: String) -> String {
        "Choisir le \(date)"
    }
}

/// Libellés de l'écran « MON ADMISSION »
/// (`src/components/HecJourneyAdmissionScreen.tsx`).
enum HecJourneyAdmissionCopy {
    static let eyebrow = "DERNIÈRE ÉTAPE"
    static let title = "MON ADMISSION"
    static let question = "Où as-tu été admis·e ?"
    static let subtitle = "Choisis ton école : son blason remplacera celui de HEC à la fin de ton parcours."
    static let schoolNameLabel = "NOM DE L’ÉCOLE"
    static let rankLabel = "TON RANG D’ADMISSION"
    static let rankA11y = "Rang d’admission"
    static let save = "ENREGISTRER MON ADMISSION"
    static let saveA11y = "Enregistrer mon admission"
    static let reset = "RÉINITIALISER"
    static let resetA11y = "Réinitialiser mon admission"
    static let resetQuestion = "Réinitialiser mon admission ?"
    static let resetMessage = "L’école et le rang enregistrés seront effacés."
    static let cancel = "Annuler"
    static let resetAction = "Réinitialiser"

    /// « Choisir HEC Paris ».
    static func a11ySchool(_ name: String) -> String {
        "Choisir \(name)"
    }
}
