import SwiftUI

/// État persistant du panneau « Mon TD » d'un chapitre.
///
/// L'app Expo range la feuille dans `AccountStorage`, sous la clé logique
/// `courseTdStorageKey(chapterId)`. Le portage iOS conserve la même clé dans
/// les préférences : les autres écrans portés (`AnnCopyStore`,
/// `TrainCourseStatusStore`) suivent déjà cette convention, la portée par
/// compte restant à ajouter avec `AccountStorage`.
final class CtdDocumentStore: ObservableObject {
    @Published private(set) var document: CtdDocument = .empty

    private var chapterId = ""

    /// `useEffect` d'ouverture du panneau : relit la feuille du chapitre.
    func load(chapterId: String) {
        self.chapterId = chapterId
        let raw = UserDefaults.standard.string(forKey: CtdStorage.documentKey(chapterId: chapterId))
        document = CtdDocumentCodec.parse(raw)
    }

    /// `save` après un import : la nouvelle feuille remplace la précédente et
    /// son analyse, qui portait sur un autre document.
    func store(source: CtdSource, analysis: CtdAnalysis?) {
        document = CtdDocument(version: 1, source: source, analysis: analysis)
        persist()
    }

    /// `save` après une analyse : la feuille importée est conservée.
    func store(analysis: CtdAnalysis?) {
        document.analysis = analysis
        persist()
    }

    private func persist() {
        guard let raw = CtdDocumentCodec.encode(document) else { return }
        UserDefaults.standard.set(raw, forKey: CtdStorage.documentKey(chapterId: chapterId))
    }
}
