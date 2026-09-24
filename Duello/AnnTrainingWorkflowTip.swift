// Port de src/utils/trainingWorkflowTip.ts (RN) — machine à états du conseil de
// parcours (« RÉDACTION → PHOTO → CORRECTION ») affiché dans le lecteur
// d'annale.
//
// Fichiers source Expo portés (noms et constantes repris mot pour mot) :
//   - `src/utils/trainingWorkflowTip.ts` — `TRAINING_WORKFLOW_TIP_EXPOSURE_POSITIONS`,
//     `TrainingWorkflowTipState`, `readTrainingWorkflowTipState`,
//     `openTrainingWorkflowTipItem`, `completeTrainingWorkflowTip` ;
//   - `src/storage/keys.ts` — `ACCOUNT_STORAGE_KEYS.trainingWorkflowTipState`
//     (`prepapp-training-workflow-tip-state:v2`) et
//     `ACCOUNT_STORAGE_KEYS.trainingWorkflowTipDismissed`
//     (`prepapp-training-workflow-tip-dismissed:v1`) ;
//   - `src/components/AnnaleViewer.tsx` — les deux effets qui lisent puis
//     écrivent l'état à chaque ouverture de sujet et à la fermeture.
//
// Le rendu du conseil lui-même (la frise) est déjà porté par
// `SubjTrainingWorkflow.swift` (lot 9-B) ; ce fichier n'apporte que l'état.
//
// Limite assumée (24/09/2026) : la source passe par `AccountStorage`
// (asynchrone, cloisonné par compte). Le portage conserve la clé logique dans
// `UserDefaults` (portée = appareil), comme `AnnaleSplit`/`ChapterNotebook`.
//
// Cible : iOS 16, aucune dépendance externe (CoreFoundation est un framework
// système, utilisé seulement pour distinguer un vrai booléen JSON d'un nombre).
//
import Foundation
import CoreFoundation

// MARK: - État

/// `TrainingWorkflowTipState` : ce qui a déjà été montré au compte.
///
/// `Equatable` : la source teste `opened.state === current` (identité) pour
/// savoir s'il faut réécrire le stockage ; en Swift (valeurs), l'appelant
/// compare `opened.state == current`.
struct TrainingWorkflowTipState: Equatable {
    var completed: Bool
    var openedItemIds: [String]
    var impressionCount: Int

    /// État neuf (`EMPTY_TRAINING_WORKFLOW_TIP_STATE`).
    static let empty = TrainingWorkflowTipState(
        completed: false,
        openedItemIds: [],
        impressionCount: 0
    )
}

// MARK: - Machine à états

/// `trainingWorkflowTip.ts` : lecture, ouverture d'un sujet et clôture du
/// conseil.
enum TrainingWorkflowTip {
    /// `TRAINING_WORKFLOW_TIP_EXPOSURE_POSITIONS` : le conseil revient aux
    /// ouvertures 1, 2, 4, 6 et 8 — puis s'arrête définitivement.
    static let TRAINING_WORKFLOW_TIP_EXPOSURE_POSITIONS = [1, 2, 4, 6, 8]

    /// `ACCOUNT_STORAGE_KEYS.trainingWorkflowTipState` : clé logique conservée.
    static let STORAGE_KEY = "prepapp-training-workflow-tip-state:v2"

    /// `ACCOUNT_STORAGE_KEYS.trainingWorkflowTipDismissed` : fermeture
    /// définitive, indépendante de l'état de comptage.
    static let DISMISSED_KEY = "prepapp-training-workflow-tip-dismissed:v1"

    /// `readTrainingWorkflowTipState` : un état illisible revient à un état
    /// neuf ; l'ancienne forme `itemIds` est migrée.
    static func readTrainingWorkflowTipState(_ stored: String?) -> TrainingWorkflowTipState {
        guard let stored,
              let data = stored.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any]
        else { return .empty }

        let legacyItemIds = stringArray(payload["itemIds"])
        let openedItemIds = payload["openedItemIds"] != nil
            ? stringArray(payload["openedItemIds"])
            : legacyItemIds

        return TrainingWorkflowTipState(
            completed: jsonTrue(payload["completed"]),
            openedItemIds: openedItemIds,
            impressionCount: impressionCount(payload["impressionCount"], legacy: legacyItemIds)
        )
    }

    /// `openTrainingWorkflowTipItem` : un même sujet ne compte jamais deux fois
    /// et un conseil clôturé ne revient pas. `visible` dit s'il faut l'afficher.
    static func openTrainingWorkflowTipItem(
        _ state: TrainingWorkflowTipState,
        itemId: String
    ) -> (state: TrainingWorkflowTipState, visible: Bool) {
        if state.completed || state.openedItemIds.contains(itemId) {
            return (state, false)
        }

        let openedItemIds = state.openedItemIds + [itemId]
        let visible = TRAINING_WORKFLOW_TIP_EXPOSURE_POSITIONS.contains(openedItemIds.count)
        let impressionCount = state.impressionCount + (visible ? 1 : 0)
        let next = TrainingWorkflowTipState(
            completed: impressionCount >= TRAINING_WORKFLOW_TIP_EXPOSURE_POSITIONS.count,
            openedItemIds: openedItemIds,
            impressionCount: impressionCount
        )
        return (next, visible)
    }

    /// `completeTrainingWorkflowTip` : un appui sur Photo ou une fermeture
    /// arrête définitivement le conseil. Idempotent.
    static func completeTrainingWorkflowTip(
        _ state: TrainingWorkflowTipState
    ) -> TrainingWorkflowTipState {
        state.completed
            ? state
            : TrainingWorkflowTipState(
                completed: true,
                openedItemIds: state.openedItemIds,
                impressionCount: state.impressionCount
            )
    }

    // MARK: Détails

    /// `impressionCount` : entier positif sinon repli sur le nombre d'anciens
    /// identifiants (migration de la forme `itemIds`).
    private static func impressionCount(_ value: Any?, legacy: [String]) -> Int {
        guard let value,
              let number = value as? NSNumber,
              !isJSONBoolean(number)
        else { return legacy.count }
        let raw = number.doubleValue
        guard raw.isFinite, raw >= 0, raw == raw.rounded() else { return legacy.count }
        return Int(raw)
    }

    /// `Array.isArray(...).filter(typeof === 'string')`.
    private static func stringArray(_ value: Any?) -> [String] {
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { $0 as? String }
    }

    /// `parsed.completed === true` : seul un vrai booléen JSON compte.
    private static func jsonTrue(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber, isJSONBoolean(number) else { return false }
        return number.boolValue
    }

    /// Vrai si `number` est un booléen JSON (`true`/`false`) et non un nombre :
    /// `NSNumber(1)` répondrait `true` à `is Bool`, on interroge donc le type
    /// CoreFoundation sous-jacent.
    private static func isJSONBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}

// MARK: - Persistance locale

extension TrainingWorkflowTip {
    /// Relecture de l'état dans les préférences (`readTrainingWorkflowTipState`).
    static func loadTrainingWorkflowTipState() -> TrainingWorkflowTipState {
        readTrainingWorkflowTipState(UserDefaults.standard.string(forKey: STORAGE_KEY))
    }

    /// Écriture de l'état dans les préférences (`JSON.stringify(state)`).
    static func saveTrainingWorkflowTipState(_ state: TrainingWorkflowTipState) {
        let payload: [String: Any] = [
            "completed": state.completed,
            "openedItemIds": state.openedItemIds,
            "impressionCount": state.impressionCount,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(text, forKey: STORAGE_KEY)
    }
}
