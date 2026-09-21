//
//  CollCompletionStore.swift
//  Duello
//
//  État persistant de la colle d'un chapitre.
//
//  Fichiers source Expo portés :
//    - src/components/ColleCompletionPanel.tsx
//        les trois `useEffect` de persistance : relecture au changement de
//        chapitre, écriture différée de 350 ms, écriture à la fermeture.
//
//  L'app Expo range la colle dans `AccountStorage`, sous la clé logique
//  `colleCompletionStorageKey(chapterId)`. Le portage iOS conserve la même clé
//  dans les préférences, comme `CtdDocumentStore`.
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

/// Colle d'un chapitre : relecture, mise à jour et écriture différée.
final class CollCompletionStore: ObservableObject {
    @Published private(set) var value: CollCompletionDocument = CollCompletion.empty()

    private var chapterId = ""
    private var saveTask: Task<Void, Never>?

    /// `useEffect([chapterId])` : relit la colle du chapitre ouvert.
    func load(chapterId: String) {
        self.chapterId = chapterId
        let raw = UserDefaults.standard.string(forKey: CollStorage.completionKey(chapterId: chapterId))
        value = CollCompletion.parse(raw)
    }

    /// Mise à jour locale : la valeur publiée déclenche l'écriture différée.
    func update(_ transform: (inout CollCompletionDocument) -> Void) {
        var current = value
        transform(&current)
        value = current
    }

    /// `setTimeout(…, 350)` : une écriture à la fois, la dernière gagne.
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            persistNow()
        }
    }

    /// Écriture immédiate, horodatée (`updatedAt: Date.now()`).
    func persistNow() {
        saveTask?.cancel()
        saveTask = nil
        guard !chapterId.isEmpty else { return }
        let stamped = CollCompletionDocument(
            version: value.version,
            statement: value.statement,
            questions: value.questions,
            updatedAt: CollCompletion.now()
        )
        guard let raw = CollCompletion.serialize(stamped) else { return }
        UserDefaults.standard.set(raw, forKey: CollStorage.completionKey(chapterId: chapterId))
    }
}
