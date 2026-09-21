import Foundation
import Combine

/// Machine à états de la feuille « NOUVEAU BLOC » et de la suppression d'un
/// emplacement neutre.
///
/// Porté de la seconde moitié de `src/components/HecJourney.tsx` :
/// `openAddPanel`, `closeAddPanel`, `handleAddType`, `handleOpenChapter`,
/// `confirmEntryCreation`, `createPendingEntry`, `confirmHolidayCreation`,
/// `deleteTargetNeutralBlock` et `persistEntries`. Le composant Expo garde cet
/// état dans une dizaine de `useState` ; il est ici rassemblé dans un objet
/// observable, pour que la vue reste une simple projection.
///
/// Différence assumée : la source écrit dans `AsyncStorage` et affiche des
/// alertes d'échec (`Ajout impossible`, `Suppression impossible`). Ici les
/// écritures passent par `UserDefaults`, synchrones et sans erreur possible :
/// il n'y a donc ni état « CRÉATION… » / « SUPPRESSION… », ni alerte d'échec.
///
/// La gestion de la date proposée vit dans `HecJourneyAddFlowDate.swift`.
final class HecJourneyAddFlow: ObservableObject {

    /// Panneaux successifs de la feuille (`AddPanel` de la source).
    enum Panel: Hashable {
        case types
        case chapters
        case holidays
        case holidayZone
        case confirmation
        case deleteConfirmation
    }

    @Published var panel: Panel?
    /// « DATE DU BLOC » : date proposée pour le prochain ajout.
    @Published var draftDate: Date
    @Published var selectedHoliday: HecJourneySchoolHoliday?
    @Published var pendingEntry: HecJourneyEntry?
    @Published var pendingHolidayEntries: [HecJourneyEntry] = []
    /// Emplacement neutre choisi sur la frise, s'il y en a un.
    @Published private(set) var targetNeutralId: String?
    @Published var calendarOpen = false

    /// Demande de centrage sur un bloc après création ou suppression : la vue
    /// l'observe et anime la frise (`focusBlock` de la source).
    @Published var focusRequest: HecJourneyFocusRequest?

    private let store: HecJourneyStore
    /// Jour d'inscription, lu aussi par l'extension de la date du bloc.
    let registeredAt: Date

    init(store: HecJourneyStore) {
        self.store = store
        self.registeredAt = store.registeredAt
        self.draftDate = HecJourneyDates.normalize(Date(), registeredAt: store.registeredAt)
    }

    // MARK: Ouverture et fermeture

    /// `openAddPanel` : la date proposée repart d'aujourd'hui.
    func open(neutralId: String?) {
        draftDate = HecJourneyDates.normalize(Date(), registeredAt: registeredAt)
        calendarOpen = false
        pendingEntry = nil
        pendingHolidayEntries = []
        selectedHoliday = nil
        targetNeutralId = neutralId
        panel = .types
    }

    /// `closeAddPanel`.
    func close() {
        panel = nil
        calendarOpen = false
        pendingEntry = nil
        pendingHolidayEntries = []
        selectedHoliday = nil
        targetNeutralId = nil
    }

    // MARK: Choix d'un type

    /// `handleAddType` : un chapitre ouvre la liste des chapitres, des vacances
    /// ouvrent la liste des vacances, les autres types vont droit à la
    /// confirmation.
    func selectType(_ type: HecJourneyBlockType) {
        switch type {
        case .chapter:
            calendarOpen = false
            panel = .chapters
        case .holiday:
            calendarOpen = false
            selectedHoliday = nil
            panel = .holidays
        default:
            confirmEntry(
                HecJourneyEntry(
                    id: HecJourneyEntries.createId(type),
                    type: type,
                    title: HecJourneyBlocks.label(type),
                    createdAt: draftDate
                )
            )
        }
    }

    /// `handleOpenChapter` : le chapitre devient un bloc daté ; c'est ensuite
    /// l'appui sur ce bloc qui ouvre le cours, comme dans la source.
    func selectChapter(_ chapter: HecJourneyChapter) {
        confirmEntry(
            HecJourneyEntry(
                id: HecJourneyEntries.createId(.chapter),
                type: .chapter,
                title: chapter.name,
                createdAt: draftDate,
                chapterId: chapter.id
            )
        )
    }

    /// `confirmEntryCreation`.
    func confirmEntry(_ entry: HecJourneyEntry) {
        pendingEntry = entry
        pendingHolidayEntries = []
        calendarOpen = false
        panel = .confirmation
    }

    // MARK: Vacances

    /// `confirmHolidayCreation` : la zone fournit les dates officielles de
    /// l'année scolaire ; `nil` retient la date réglée à la main.
    func selectHolidayZone(_ zone: HecJourneySchoolZone?) {
        guard let selectedHoliday else { return }
        let entries: [HecJourneyEntry]
        if let zone {
            entries = HecJourneyDates.schoolHolidayStarts(selectedHoliday, zone: zone).map { start in
                HecJourneyEntry(
                    id: HecJourneyEntries.createId(.holiday),
                    type: .holiday,
                    title: start.title,
                    createdAt: start.date
                )
            }
        } else {
            entries = [
                HecJourneyEntry(
                    id: HecJourneyEntries.createId(.holiday),
                    type: .holiday,
                    title: selectedHoliday == .toutes
                        ? HecJourneyCopy.allHolidaysTitle
                        : selectedHoliday.label,
                    createdAt: draftDate
                ),
            ]
        }
        guard let first = entries.first else { return }
        pendingEntry = first
        pendingHolidayEntries = entries
        calendarOpen = false
        panel = .confirmation
    }

    // MARK: Retour et suppression

    /// Navigation arrière de l'en-tête, et bouton « MODIFIER » de la
    /// confirmation : mêmes retours que la source.
    func back() {
        calendarOpen = false
        if panel == .chapters || panel == .holidays {
            pendingEntry = nil
            pendingHolidayEntries = []
            selectedHoliday = nil
            panel = .types
            return
        }
        if panel == .holidayZone {
            panel = .holidays
            return
        }
        if panel == .confirmation, pendingEntry?.type == .chapter {
            pendingEntry = nil
            panel = .chapters
            return
        }
        if panel == .confirmation, pendingEntry?.type == .holiday {
            pendingEntry = nil
            pendingHolidayEntries = []
            panel = .holidayZone
            return
        }
        pendingEntry = nil
        pendingHolidayEntries = []
        panel = .types
    }

    /// « Supprimer ce bloc neutre ? ».
    func requestNeutralDeletion() {
        guard targetNeutralId != nil else { return }
        panel = .deleteConfirmation
    }

    /// `deleteTargetNeutralBlock` : l'emplacement quitte la frise et le
    /// centrage revient au bloc suivant.
    func deleteNeutralBlock() {
        guard let targetNeutralId else { return }
        let index = store.entries.firstIndex { $0.id == targetNeutralId }
        store.removeNeutral(targetNeutralId)
        close()
        let focus = index.map { min($0 + 1, store.entries.count) } ?? 0
        focusRequest = HecJourneyFocusRequest(index: focus, count: store.entries.count + 1)
    }

    // MARK: Création

    /// `createPendingEntry` + `persistEntries` : les blocs de vacances
    /// arrivent en lot, le premier prenant l'emplacement neutre choisi.
    func confirmCreation() {
        let entries = pendingHolidayEntries.isEmpty
            ? (pendingEntry.map { [$0] } ?? [])
            : pendingHolidayEntries
        guard !entries.isEmpty else { return }
        let result = store.add(entries, preferredNeutralId: targetNeutralId)
        close()
        focusRequest = HecJourneyFocusRequest(index: result.focusIndex, count: result.blockCount)
    }
}

/// Demande de centrage de la frise. L'identifiant est neuf à chaque demande,
/// pour que la vue réagisse même si deux centrages visent le même bloc.
struct HecJourneyFocusRequest: Equatable {
    let id = UUID()
    let index: Int
    let count: Int
}
