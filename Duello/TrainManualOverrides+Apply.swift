//
//  TrainManualOverrides+Apply.swift
//  Duello
//
//  Port de src/data/manualExerciseOverrides.ts (RN) — application d'une
//  correction à un sujet, et résolution de l'identifiant visé.
//
//  Découpage : les modèles, la validation, la fusion des couches et le recalcul
//  (questions, fiche de prérequis) vivent dans `TrainManualOverrides.swift` ;
//  ici, seule l'entrée publique — variantes prenant la table en paramètre, et
//  variantes lisant `TrainManualOverrides.current`.
//
//  ⚠️ La table de corrections en vigueur (`manualExerciseOverrides()`, via
//  `servedRecord` + tables ECG) n'est PAS portée → branchement servedBank à
//  raccorder (vague 5).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension TrainManualOverrides {

    /// `applyManualExerciseOverrideFrom` : sujet relu, ou le sujet d'origine
    /// lorsqu'aucune correction ne le vise. L'identifiant est résolu par
    /// `overrides[item.id]`, puis par la permutation `::colle::` ↔
    /// `::exercice::`, puis par le dernier segment après `::`.
    static func applyManualExerciseOverrideFrom(
        _ item: TrainOverrideItem,
        overrides: [String: TrainManualOverride]
    ) -> TrainOverrideItem {
        // Une même source peut être montée comme colle ou comme exercice selon
        // l'écran. Les deux identifiants doivent partager la même relecture.
        let cle = item.id.components(separatedBy: "::").last ?? item.id
        let identifiantExercice = item.id.replacingOccurrences(of: "::colle::", with: "::exercice::")
        let identifiantColle = item.id.replacingOccurrences(of: "::exercice::", with: "::colle::")
        guard let override = overrides[item.id]
            ?? overrides[identifiantExercice]
            ?? overrides[identifiantColle]
            ?? overrides[cle]
        else {
            return withoutExplicitlyDamagedSolution(item)
        }

        // Une nouvelle transcription visuelle d'un corrigé Drive peut rendre
        // obsolète une ancienne surcharge issue de la couche texte défectueuse
        // du PDF. Dans ce cas, la transcription complète reprend la priorité.
        let solutionLength = item.solution?.count ?? 0
        let refreshedDriveSolution =
            item.source == "Dossier Google Drive partagé"
            && solutionLength >= 10_000
            && override.solution != nil
            && solutionLength >= (override.solution?.count ?? 0) * 3
        guard refreshedDriveSolution else {
            return withoutExplicitlyDamagedSolution(overrideChapterItem(item, override))
        }

        var currentOverride = override
        currentOverride.solution = nil
        return withoutExplicitlyDamagedSolution(overrideChapterItem(item, currentOverride))
    }

    /// `applyManualExerciseOverride` : sujet relu selon la table en vigueur.
    static func applyManualExerciseOverride(_ item: TrainOverrideItem) -> TrainOverrideItem {
        applyManualExerciseOverride(item, overrides: current)
    }

    /// `applyManualExerciseOverride` : variante prenant la table en paramètre.
    static func applyManualExerciseOverride(
        _ item: TrainOverrideItem,
        overrides: [String: TrainManualOverride]
    ) -> TrainOverrideItem {
        applyManualExerciseOverrideFrom(item, overrides: overrides)
    }

    /// `applyManualExerciseOverrides` : liste relue selon la table en vigueur.
    static func applyManualExerciseOverrides(_ items: [TrainOverrideItem]) -> [TrainOverrideItem] {
        applyManualExerciseOverrides(items, overrides: current)
    }

    /// `applyManualExerciseOverrides` : variante prenant la table en paramètre.
    static func applyManualExerciseOverrides(
        _ items: [TrainOverrideItem],
        overrides: [String: TrainManualOverride]
    ) -> [TrainOverrideItem] {
        if overrides.isEmpty { return items }
        return items.map { applyManualExerciseOverrideFrom($0, overrides: overrides) }
    }

    /// `manualExerciseOverrideFor` : correction en vigueur pour un sujet, sans
    /// construire le sujet lui-même.
    static func manualExerciseOverrideFor(_ itemId: String) -> TrainManualOverride? {
        manualExerciseOverrideFor(itemId, overrides: current)
    }

    /// `manualExerciseOverrideFor` : variante prenant la table en paramètre.
    static func manualExerciseOverrideFor(
        _ itemId: String,
        overrides: [String: TrainManualOverride]
    ) -> TrainManualOverride? {
        overrides[itemId]
    }
}
