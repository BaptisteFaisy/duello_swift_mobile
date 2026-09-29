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
/// serveur, `App.tsx:2828` → `HecJourney.tsx:153,172`). `UserProfile` ne le
/// porte pas ; le magasin le résout donc, dans l'ordre : la valeur injectée par
/// l'appelant, le `createdAt` du compte du registre local (`accountEmail`),
/// puis — en dernier recours, écart assumé — la première ouverture du parcours.
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

    private static let timelinePrefix = "prepapp-hec-journey-timeline:v2:"
    private static let admissionKey = "prepapp-hec-journey-admission:v1"
    /// Clé propre à Swift, **dernier recours** quand ni l'appelant ni le
    /// registre ne fournissent le `createdAt` du compte (écart assumé).
    private static let registrationKey = "prepapp-hec-journey-registration-date:v1"

    init(
        programYear: Int = 1,
        registeredAt: Date? = nil,
        accountEmail: String? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.programYear = programYear
        self.registeredAt = Self.resolveRegistrationDate(
            explicit: registeredAt,
            accountEmail: accountEmail,
            defaults: defaults
        )
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

    /// Jour d'inscription retenu : celui fourni, sinon le `createdAt` du compte
    /// du registre local (`accountEmail`), sinon celui déjà mémorisé, sinon
    /// aujourd'hui (mémorisé à son tour) — écart assumé, voir la note de classe.
    private static func resolveRegistrationDate(
        explicit: Date?,
        accountEmail: String?,
        defaults: UserDefaults
    ) -> Date {
        if let explicit, HecJourneyDates.isUsable(explicit) {
            return HecJourneyDates.startOfLocalDay(explicit)
        }
        if let accountEmail, let created = accountCreatedAt(email: accountEmail) {
            return HecJourneyDates.startOfLocalDay(created)
        }
        if let stored = defaults.object(forKey: registrationKey) as? Date {
            return HecJourneyDates.startOfLocalDay(stored)
        }
        let today = HecJourneyDates.startOfLocalDay(Date())
        defaults.set(today, forKey: registrationKey)
        return today
    }

    /// `createdAt` du compte du registre local (`AcctStoredAccount.createdAt`,
    /// instant epoch en millisecondes, `App.tsx:2828`).
    private static func accountCreatedAt(email: String) -> Date? {
        let accounts = AcctLocalRegistry.loadAccounts()
        guard let account = AcctLocalRegistry.findAccountByEmail(accounts, email: email),
              let createdAt = account.createdAt else { return nil }
        return Date(timeIntervalSince1970: createdAt / 1000)
    }
}
