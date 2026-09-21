//
//  CollTrainingTimeStore.swift
//  Duello
//
//  Journal de temps de travail persisté localement.
//
//  Fichiers source Expo portés :
//    - src/utils/trainingTime.ts
//        `loadTrainingTime`, `recordTrainingTime` et l'écriture sous la clé
//        `prepapp-training-time:v1`.
//
//  Limite documentée : la source sérialise les écritures par compte via une file
//  (`logQueues`). Le store iOS est lié au fil principal et n'a qu'un compte à la
//  fois : la file n'est pas nécessaire.
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

/// Journal de temps d'un compte, persisté dans les préférences.
final class CollTrainingTimeStore: ObservableObject {
    @Published private(set) var log: CollTrainingTimeLog = .empty

    /// `ACCOUNT_STORAGE_KEYS.trainingTime`.
    private static let storageKey = "prepapp-training-time:v1"

    init() {
        restore()
    }

    /// `loadTrainingTime` : un journal illisible ne doit pas empêcher de travailler,
    /// on repart à vide.
    func restore() {
        guard let raw = UserDefaults.standard.string(forKey: Self.storageKey),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(CollTrainingTimeLog.self, from: data)
        else {
            log = .empty
            return
        }
        log = CollTrainingTime.normalize(decoded)
    }

    /// `recordTrainingTime` : ajoute un temps mesuré au journal et publie le
    /// journal à jour. Une seconde perdue ne vaut pas une écriture.
    func record(_ measure: CollTrainingTimeMeasure) {
        let at = measure.at ?? CollCompletion.now()
        let seconds = max(0, measure.milliseconds) / 1000
        let subject = measure.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard seconds >= 1, !subject.isEmpty else { return }

        let entry = CollTrainingTimeEntry(
            day: CollTrainingTime.dayKey(at: at),
            subject: subject,
            activity: measure.activity,
            seconds: seconds
        )
        log = CollTrainingTime.normalize(
            CollTrainingTimeLog(version: 1, entries: log.entries + [entry]),
            at: at
        )
        persist()
    }

    /// Écriture du journal dans les préférences ; l'échec laisse la mesure en
    /// mémoire pour la session en cours.
    private func persist() {
        guard let data = try? JSONEncoder().encode(log),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(raw, forKey: Self.storageKey)
    }
}
