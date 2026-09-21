import Foundation
import Combine

/// Store local du parcours HEC : la frise d'une année, l'admission finale et
/// le jour d'inscription, persistés dans `UserDefaults`.
///
/// Porté de la première moitié de `src/components/HecJourney.tsx` (chargement
/// `useEffect`, `persistEntries`, `deleteOpenedBlock`, `saveAdmission`,
/// `resetAdmission`) et des clés de `src/storage/keys.ts` :
/// `prepapp-hec-journey-timeline:v2:<année>` (une frise par année) et
/// `prepapp-hec-journey-admission:v1` (admission unique).
///
/// Limite assumée : la source reçoit `registeredAt` du compte (`createdAt`
/// serveur). `UserProfile` n'a pas d'équivalent ici, donc le jour d'inscription
/// est la première ouverture du parcours, mémorisée une fois pour toutes
/// (`resolveRegistrationDate`). Il sert d'origine à toute la frise.
final class HecJourneyStore: ObservableObject {

    /// Année affichée : 1 ou 2.
    @Published private(set) var programYear: Int
    /// Entrées de la frise de l'année affichée.
    @Published private(set) var entries: [HecJourneyEntry] = []
    /// Admission enregistrée, partagée par les deux frises.
    @Published private(set) var admission: HecJourneyAdmission?

    /// Origine de la frise (voir la note de classe).
    let registeredAt: Date

    private let defaults: UserDefaults

    private static let timelinePrefix = "com.duello.ios.hec-journey.timeline."
    private static let admissionKey = "com.duello.ios.hec-journey.admission"
    private static let registrationKey = "com.duello.ios.hec-journey.registration-date"

    init(programYear: Int = 1, registeredAt: Date? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.programYear = programYear
        self.registeredAt = Self.resolveRegistrationDate(explicit: registeredAt, defaults: defaults)
        self.admission = HecJourneyAdmissionCodec.parse(defaults.string(forKey: Self.admissionKey))
        loadTimeline()
    }

    // MARK: Année affichée

    /// Bascule sur l'autre frise (1re / 2e année).
    func switchYear(to year: Int) {
        guard year != programYear else { return }
        programYear = year
        loadTimeline()
    }

    /// `timelineEndDate` de `HecJourney.tsx` : la frise de 2e année s'arrête à
    /// la fin de l'année scolaire.
    var timelineEndDate: Date? {
        programYear == 2 ? HecJourneyDates.secondYearEndDate(registeredAt: registeredAt) : nil
    }

    // MARK: Création

    /// `persistEntries` : chaque bloc prend un emplacement (le neutre choisi
    /// pour le premier, le suivant libre ensuite) et la frise renvoie l'index
    /// à mettre en avant.
    @discardableResult
    func add(
        _ newEntries: [HecJourneyEntry],
        preferredNeutralId: String? = nil
    ) -> (assigned: [HecJourneyEntry], focusIndex: Int, blockCount: Int) {
        var next = entries
        var assigned: [HecJourneyEntry] = []
        for (index, entry) in newEntries.enumerated() {
            let result = HecJourneyEntries.assign(
                entry,
                in: next,
                preferredNeutralId: index == 0 ? preferredNeutralId : nil
            )
            next = result.entries
            assigned.append(result.assigned)
        }
        if next != entries {
            entries = next
            persist()
        }
        let index = next.firstIndex { $0.id == assigned.last?.id } ?? -1
        return (assigned, max(0, index + 1), next.count + 1)
    }

    // MARK: Suppression

    /// `deleteOpenedBlock` : un jalon ou un chapitre libère son emplacement
    /// (il redevient neutre), un repère latéral ou un emplacement neutre
    /// disparaît ; l'inscription et le blason final ne se suppriment pas.
    func delete(_ block: HecJourneySceneBlock) {
        switch block.type {
        case .registration, .admission:
            return
        case .block(let type):
            entries = HecJourneyBlocks.isAssessment(type)
                ? HecJourneyEntries.remove(block.id, from: entries)
                : HecJourneyEntries.release(block.id, in: entries)
        }
        persist()
    }

    /// Suppression d'un emplacement neutre depuis la feuille d'ajout.
    func removeNeutral(_ id: String) {
        entries = HecJourneyEntries.remove(id, from: entries)
        persist()
    }

    // MARK: Admission

    /// `saveAdmission`.
    func save(admission: HecJourneyAdmission) {
        self.admission = admission
        defaults.set(HecJourneyAdmissionCodec.serialize(admission), forKey: Self.admissionKey)
    }

    /// `resetAdmission`.
    func resetAdmission() {
        admission = nil
        defaults.removeObject(forKey: Self.admissionKey)
    }

    // MARK: Persistance

    private var timelineKey: String {
        Self.timelinePrefix + String(programYear)
    }

    /// Lecture de la frise, puis graine des 32 emplacements neutres quand la
    /// version enregistrée est dépassée (`shouldSeed` de la source).
    private func loadTimeline() {
        let state = HecJourneyTimelineCodec.parse(
            defaults.string(forKey: timelineKey),
            registeredAt: registeredAt
        )
        guard state.neutralBlocksSeedVersion < HecJourneyTimelineConstants.neutralSeedVersion else {
            entries = state.entries
            return
        }
        entries = HecJourneySeeding.seed(
            entries: state.entries,
            registeredAt: registeredAt,
            now: Date(),
            previousSeedVersion: state.neutralBlocksSeedVersion,
            timelineEndAt: timelineEndDate
        )
        persist()
    }

    private func persist() {
        defaults.set(HecJourneyTimelineCodec.serialize(entries), forKey: timelineKey)
    }

    /// Jour d'inscription retenu : celui fourni, sinon celui déjà mémorisé,
    /// sinon aujourd'hui (mémorisé à son tour).
    private static func resolveRegistrationDate(explicit: Date?, defaults: UserDefaults) -> Date {
        if let explicit, HecJourneyDates.isUsable(explicit) {
            return HecJourneyDates.startOfLocalDay(explicit)
        }
        if let stored = defaults.object(forKey: registrationKey) as? Date {
            return HecJourneyDates.startOfLocalDay(stored)
        }
        let today = HecJourneyDates.startOfLocalDay(Date())
        defaults.set(today, forKey: registrationKey)
        return today
    }
}
