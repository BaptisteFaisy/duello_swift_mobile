import SwiftUI

// V1 2026-09-26 (U06#4) : fichier neuf. Révision des flashcards d'un chapitre :
// sélection (chapitres, paquet, ordre, correction), bouton « Go » et fenêtre
// plein écran `SubjFlashcardReviewModal`. Panneau « Réviser » de
// `SubjectsScreen.tsx:8678-8736` + `startFlashcardReview` `5620`,
// `recordFlashcardVerdict` `5740`, `abandonFlashcardReview` `5726`,
// `closeFlashcardReview` `5715`.

/// Révision des flashcards du chapitre (`flashcardPanel === 'review'`) :
/// menus de sélection, bouton « Go », puis `SubjFlashcardReviewModal`.
struct TrainFlashcardReviewPanel: View {
    /// Banques des chapitres pourvus (`flashcardChapterSourcesForReview`).
    let sources: [CollFlashcardChapterSource]
    /// Sélection du paquet, `nil` = tous les types.
    @Binding var deck: String?
    @Binding var correctionMode: SubjFlashcardCorrectionMode
    @Binding var shuffle: Bool
    /// Persistance d'un document de chapitre (`saveFlashcardChapterDocument`).
    let onSave: (String, CollFlashcardsDocument) -> Void
    /// Rafraîchir l'écran parent après chaque verdict.
    let onVerdictSaved: () -> Void

    /// Chapitres retenus : par défaut, tous ceux qui ont des cartes.
    @State private var chapterSelection: SubjFlashcardChapterSelection = .all
    /// File de la session, clés `reviewEntryKey`.
    @State private var queue: [String] = []
    /// Verdicts par clé (`flashcardReviewVerdicts`).
    @State private var verdicts: [String: CollFlashcardVerdict] = [:]
    /// Étape de session : force la remise à zéro quand la même carte revient
    /// en tête (session d'une seule carte).
    @State private var step = 0
    @State private var reviewOpen = false
    @State private var startedAt: Double = 0
    @State private var sessionChapterIds: [String] = []
    @State private var summary: SubjFlashcardReviewSummary?
    @State private var alertMessage: String?

    private var chapters: [CollFlashcardChapterSource] { sources }

    var body: some View {
        selectionForm
            .fullScreenCover(isPresented: $reviewOpen) {
                reviewCover
            }
            .alert("Révision impossible", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
    }

    /// Menus de sélection + bouton « Go ».
    private var selectionForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            SubjFlashcardChapterDropdown(
                options: chapterOptions,
                selected: chapterSelection,
                loading: false,
                onSelect: { chapterSelection = $0 }
            )
            SubjFlashcardDropdown(
                label: "Type de flashcards",
                options: reviewDecks,
                selected: deck ?? SubjFlashcardSelectionKey.all,
                onSelect: { deck = $0 == SubjFlashcardSelectionKey.all ? nil : $0 },
                allowAll: true
            )
            orderDropdown
            correctionDropdown
            goButton
        }
    }

    /// Menu « Ordre » : dans l'ordre / dans le désordre.
    private var orderDropdown: some View {
        SubjFlashcardDropdown(
            label: "Ordre",
            options: [
                CollDeckDefinition(key: "ordered", label: "Dans l’ordre", description: nil),
                CollDeckDefinition(key: "shuffled", label: "Dans le désordre", description: nil),
            ],
            selected: shuffle ? "shuffled" : "ordered",
            onSelect: { shuffle = $0 == "shuffled" }
        )
    }

    /// Menu « Mode de correction » (`FLASHCARD_CORRECTION_OPTIONS`).
    private var correctionDropdown: some View {
        SubjFlashcardDropdown(
            label: "Mode de correction",
            options: SubjFlashcardCorrectionOptions.all,
            selected: correctionMode.rawValue,
            onSelect: { correctionMode = SubjFlashcardCorrectionMode(rawValue: $0) ?? .selfCorrection }
        )
    }

    /// Fenêtre de révision (`FlashcardReviewModal`, `8836`).
    @ViewBuilder
    private var reviewCover: some View {
        if let entry = currentEntry, let source = source(of: entry) {
            SubjFlashcardReviewModal(
                card: entry.card,
                reviewStep: step,
                correctionMode: correctionMode,
                chapterId: entry.chapterId,
                chapterName: entry.chapterName,
                gradingProgram: "",
                subject: entry.subject,
                sessionCounts: CollFlashcardReview.sessionCounts(verdicts),
                xpGain: nil,
                sessionXp: 0,
                successSummary: summary,
                onVerdict: { verdict in await recordVerdict(verdict, entry: entry, source: source) },
                onAbandon: { abandonReview() },
                onClaimSuccess: { closeReview() }
            )
        }
    }

    // MARK: - Options

    /// Options du menu « Chapitres » : les chapitres pourvus en cartes.
    private var chapterOptions: [CollDeckDefinition] {
        chapters.map { CollDeckDefinition(key: $0.chapterId, label: $0.chapterName, description: nil) }
    }

    /// Paquets des chapitres retenus (`flashcardReviewDecks`).
    private var reviewDecks: [CollDeckDefinition] {
        var decks = CollFlashcards.standardDecks
        for source in selectedSources {
            for card in source.document.cards where !decks.contains(where: { $0.key == card.deck }) {
                decks.append(CollDeckDefinition(key: card.deck, label: card.deck, description: nil))
            }
        }
        return decks
    }

    /// Chapitres retenus par le menu, dans l'ordre du programme.
    private var selectedSources: [CollFlashcardChapterSource] {
        chapters.filter { chapterSelection.contains($0.chapterId) }
    }

    /// Bouton « Go » (`Commencer la révision`) : inerte sans chapitre retenu.
    private var goButton: some View {
        Button {
            startReview()
        } label: {
            HStack(spacing: 8) {
                Text("Go")
                    .font(.system(size: 15, weight: .heavy))
                Image(systemName: "arrow.forward")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(goEnabled ? Theme.primary : Theme.inkFaint)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(!goEnabled)
        .accessibilityLabel("Commencer la révision")
    }

    private var goEnabled: Bool {
        !selectedSources.flatMap { $0.document.cards }.isEmpty
    }

    // MARK: - Session

    /// Carte courante : tête de file, relue dans la banque à jour.
    private var currentEntry: CollFlashcardReviewEntry? {
        guard let key = queue.first else { return nil }
        for source in chapters {
            for card in source.document.cards {
                if CollFlashcardSession.reviewEntryKey(chapterId: source.chapterId, cardId: card.id) == key {
                    return CollFlashcardReviewEntry(
                        key: key,
                        chapterId: source.chapterId,
                        chapterName: source.chapterName,
                        subject: source.subject,
                        card: card
                    )
                }
            }
        }
        return nil
    }

    private func source(of entry: CollFlashcardReviewEntry) -> CollFlashcardChapterSource? {
        chapters.first { $0.chapterId == entry.chapterId }
    }

    /// `startFlashcardReview` : réunit les cartes révisables des chapitres
    /// retenus (`reviewSessionForChapters`), arme la file et ouvre la fenêtre.
    private func startReview() {
        let selectedIds = selectedSources.map { $0.chapterId }
        guard !selectedIds.isEmpty else {
            alertMessage = "Choisis au moins un chapitre qui contient des flashcards."
            return
        }
        let session = CollFlashcardSession.reviewSessionForChapters(
            sources: chapters,
            selectedChapterIds: selectedIds,
            deck: deck,
            shuffle: shuffle
        )
        guard !session.isEmpty else {
            alertMessage = "Aucune flashcard de ce type ne correspond encore à la partie du cours vue en classe."
            return
        }
        for source in selectedSources {
            let sessionIds = Set(session.filter { $0.chapterId == source.chapterId }.map { $0.card.id })
            onSave(source.chapterId, CollFlashcardsDocument(
                version: source.document.version,
                generatedAt: source.document.generatedAt,
                sourceName: source.document.sourceName,
                cards: source.document.cards.map { sessionIds.contains($0.id) ? CollFlashcardReview.prepareForReview($0) : $0 },
                decks: source.document.decks
            ))
        }
        queue = session.map { $0.key }
        step = 0
        verdicts = [:]
        startedAt = TrainChapterFlashcards.now()
        sessionChapterIds = selectedIds
        summary = nil
        reviewOpen = true
    }

    /// `recordFlashcardVerdict` : applique le verdict, persiste la carte, avance
    /// la file (la carte non maîtrisée revient en queue) ou dresse le bilan.
    private func recordVerdict(
        _ verdict: CollFlashcardVerdict,
        entry: CollFlashcardReviewEntry,
        source: CollFlashcardChapterSource
    ) async {
        guard queue.first == entry.key else { return }
        let reviewed = CollFlashcardReview.recordVerdict(
            entry.card,
            verdict: verdict,
            seenAt: TrainChapterFlashcards.now()
        )
        let next = CollFlashcardsDocument(
            version: source.document.version,
            generatedAt: source.document.generatedAt,
            sourceName: source.document.sourceName,
            cards: source.document.cards.map { $0.id == entry.card.id ? reviewed : $0 },
            decks: source.document.decks
        )
        onSave(entry.chapterId, next)
        onVerdictSaved()
        verdicts[entry.key] = verdict
        let mastered = CollFlashcardReview.isMastered(reviewed)
        let following = mastered ? Array(queue.dropFirst()) : Array(queue.dropFirst()) + [entry.key]
        if !following.isEmpty {
            queue = following
            step += 1
            return
        }
        summary = SubjFlashcardReviewSummary(
            xp: 0,
            seconds: max(0, (TrainChapterFlashcards.now() - startedAt) / 1000),
            chapterMastery: CollFlashcardReview.masteryPercentage(chapters.flatMap { source in
                guard sessionChapterIds.contains(source.chapterId) else { return [] }
                return source.chapterId == entry.chapterId ? next.cards : source.document.cards
            })
        )
    }

    /// `abandonFlashcardReview` : referme la fenêtre et vide la session.
    private func abandonReview() {
        queue = []
        verdicts = [:]
        sessionChapterIds = []
        summary = nil
        reviewOpen = false
    }

    /// `closeFlashcardReview` (bilan « Recevoir mes XP ») : même fermeture.
    private func closeReview() {
        queue = []
        verdicts = [:]
        sessionChapterIds = []
        summary = nil
        reviewOpen = false
    }
}
