//
//  ProfCourseTextSession.swift
//  Duello
//
//  Texte du cours uploadé du chapitre, prêt à partir vers le prof IA.
//
//  Fichier source Expo porté : `src/hooks/useProfCourseText.ts`
//  (`useProfCourseText`). Le mémo et l'extraction vivent dans
//  `ProfCourseText.swift` / `ProfCourseTextRelay.swift` (lot TR-08) ; ce fichier
//  ne porte que le **cycle de vie** : lire le mémo dès qu'un cours est montré,
//  puis demander l'extraction si elle manque.
//
//  L'extraction est demandée dès que le cours est ouvert, jamais à la première
//  question : le prof peut ainsi s'y référer tout de suite, depuis n'importe
//  quelle page, sans faire attendre l'élève. Un cours sans texte exploitable
//  (photo, scan) reste `nil` et le prof s'en tient à la page sélectionnée.
//
//  La source relit le mémo à chaque changement de document et ignore une
//  réponse tardive (`current = false` à la destruction de l'effet) : le portage
//  annule la tâche précédente et vérifie l'identité du document avant d'écrire.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Combine
import Foundation

/// Cycle de vie du texte de cours pour la fenêtre de contexte du prof
/// (`useProfCourseText`).
@MainActor
final class ProfCourseTextSession: ObservableObject {

    /// Texte du cours, ou `nil` tant qu'aucun texte exploitable n'est disponible.
    @Published private(set) var text: String?

    private var document: CtdStoredCourseDocument?
    private var task: Task<Void, Never>?

    /// Change de cours affiché : relit le mémo puis, s'il manque, demande
    /// l'extraction au relais.
    func update(document: CtdStoredCourseDocument?, token: String?) {
        self.document = document
        task?.cancel()
        let cached = ProfCourseTextCache.cachedProfCourseText(document)
        text = cached
        guard let document, cached == nil else { return }
        task = Task { [weak self] in
            let extracted = try? await ProfCourseTextRelay.loadProfCourseText(document, token: token)
            guard let self, !Task.isCancelled, self.document?.id == document.id else { return }
            self.text = (extracted?.isEmpty == false) ? extracted : nil
        }
    }

    /// Texte à porter dans `ProfDocuments.course` : `nil` quand aucun texte
    /// exploitable n'a été extrait.
    var courseText: String? { text }
}
