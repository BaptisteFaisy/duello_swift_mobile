import SwiftUI

// V1 2026-09-26 (U06#4) : fichier neuf. Surface « Cartes » d'un chapitre :
// génération, création avec persistance (`saveFlashcardEditor` `5562`) et
// panneau de révision (`TrainFlashcardReviewPanel`).
//
// V2 2026-09-28 (U06#4, #12) : la génération passe par le **relais IA**
// (`generateCourseFlashcardsFromPdf`, `CollFlashcardsApi`), avec l'accord de
// partage IA, l'avancement publié (`flashcardGenerationProgress`) et
// l'annulation — au lieu du générateur local de cinq cartes génériques. Le
// panneau ne porte plus sa propre barre d'onglets : les sections sont choisies
// par les onglets de la page « Mon cours » (`TrainCoursePageTab`), comme la
// source (`coursePage === 'flashcards'`).

/// Surface « Cartes » d'un chapitre : un seul panneau (Générer / Créer /
/// Réviser), choisi par la page « Mon cours ».
struct TrainFlashcardsPanel: View {
    let subject: String
    let chapterId: String
    let chapterName: String
    /// Année du programme : le document de cours est rangé par année.
    let programYear: Int
    /// Document de cours : la génération exige un cours importé.
    let hasCourseDocument: Bool
    /// Position du repère (`coursePosition`) : la révision s'arrête au repère.
    let coursePosition: Double
    /// Panneau affiché (`flashcardPanel` de la source).
    let panel: TrainFlashcardPanelTab
    /// Persistance d'un document de chapitre (`saveFlashcardChapterDocument`).
    var onSave: ((String, CollFlashcardsDocument) -> Void)? = nil

    @EnvironmentObject private var session: SessionStore

    /// Cartes du chapitre (`courseFlashcards`), relues à l'ouverture.
    @State private var document: CollFlashcardsDocument?
    @State private var loaded = false
    @State private var generating = false
    @State private var generationProgress: CollFlashcardGenerationProgress?
    @State private var generationTask: Task<Void, Never>?
    @State private var consentVisible = false
    @State private var pendingGeneration = false

    // Création (`saveFlashcardEditor`)
    @State private var createDeck = "definitions"
    @State private var customDeckName = ""
    @State private var front = ""
    @State private var back = ""
    @State private var editingCardId: String?

    // Révision (`startFlashcardReview`)
    @State private var reviewDeck: String?
    @State private var correctionMode: SubjFlashcardCorrectionMode = .selfCorrection
    @State private var shuffle = false
    @State private var alertMessage: String?

    private var cards: [CollFlashcard] { document?.cards ?? [] }
    private var hasGenerated: Bool { CollFlashcards.hasGenerated(document) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !loaded {
                SubjDeferredInlineFallback(label: "Ouverture des cartes…")
            } else {
                switch panel {
                case .generate: generatePanel
                case .create: createPanel
                case .review:
                    TrainFlashcardReviewPanel(
                        sources: reviewSources,
                        deck: $reviewDeck,
                        correctionMode: $correctionMode,
                        shuffle: $shuffle,
                        onSave: saveChapter,
                        onVerdictSaved: reload
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: chapterId) { reload() }
        .onDisappear { generationTask?.cancel() }
        .alert("Carte incomplète", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: - Chargement

    private func reload() {
        loaded = false
        resetEditor()
        reviewDeck = nil
        document = TrainChapterFlashcards.load(chapterId: chapterId)
        loaded = true
    }

    /// `saveFlashcardChapterDocument` : persiste et republie le chapitre courant.
    private func saveChapter(_ id: String, _ value: CollFlashcardsDocument) {
        TrainChapterFlashcards.save(value, chapterId: id)
        onSave?(id, value)
        if id == chapterId { document = value }
    }

    /// Banque du chapitre pour la révision (`CollFlashcardChapterSource`).
    private var reviewSources: [CollFlashcardChapterSource] {
        guard let document, !document.cards.isEmpty else { return [] }
        return [CollFlashcardChapterSource(
            chapterId: chapterId,
            chapterName: chapterName,
            subject: subject,
            coursePosition: coursePosition,
            document: document
        )]
    }

    // MARK: - Générer

    /// Panneau « Générer » (`flashcardPanel === 'generate'`, `8508-8560`).
    private var generatePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hasCourseDocument
                ? "La génération couvre tout le cours. La révision s’arrête au repère du cours vu en classe."
                : "Ajoute un cours PDF, JPEG ou PNG dans « Mon cours » pour utiliser la génération automatique.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if generating {
                generationEstimate
                Button {
                    generationTask?.cancel()
                } label: {
                    HStack(spacing: 8) {
                        IonIcon(name: "close-outline", size: 20, color: Theme.surface)
                        Text("Annuler la génération")
                            .font(.system(size: 15, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(DuelloPrimaryButton())
                .accessibilityLabel("Annuler la génération des flashcards")
            } else {
                Button {
                    generate()
                } label: {
                    HStack(spacing: 8) {
                        IonIcon(name: "sparkles-outline", size: 17, color: Theme.surface)
                        Text(hasGenerated ? "Régénérer mes flashcards" : "Obtenir les flashcards de mon cours")
                            .font(.system(size: 15, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(DuelloPrimaryButton())
                .accessibilityLabel(hasGenerated ? "Régénérer mes flashcards" : "Obtenir les flashcards de mon cours")
            }
            if hasGenerated, let document {
                let total = document.cards.filter { $0.origin != .user }.count
                let revisable = CollFlashcardReview.seenSoFar(
                    document.cards.filter { $0.origin != .user },
                    coursePosition: coursePosition
                ).count
                HStack(spacing: 8) {
                    IonIcon(name: "checkmark-circle", size: 17, color: Theme.progress)
                    Text("\(total) flashcard\(total > 1 ? "s" : "") générée\(total > 1 ? "s" : ""). \(revisable) révisable\(revisable > 1 ? "s" : "") jusqu’au repère actuel.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .alert(CtdAiConsent.title, isPresented: $consentVisible) {
            Button(CtdAiConsent.denyLabel, role: .cancel) { pendingGeneration = false }
            Button(CtdAiConsent.allowLabel) {
                CtdAiConsent.grant()
                if pendingGeneration { pendingGeneration = false; startGeneration() }
            }
        } message: {
            Text(CtdAiConsent.message)
        }
    }

    /// Avancement de la génération (`flashcardGenerationEstimate`) : phase
    /// courante et estimation de durée.
    private var generationEstimate: some View {
        HStack(alignment: .top, spacing: 10) {
            ProgressView().controlSize(.small).tint(Theme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(generationPhaseLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Temps de génération estimé : 2 à 5 min selon la longueur du cours.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    /// `flashcardGenerationProgress` : libellé de la phase en cours.
    private var generationPhaseLabel: String {
        switch generationProgress?.phase {
        case .uploading:
            let percent = Int(((generationProgress?.fraction ?? 0) * 100).rounded())
            return "Téléversement du cours · \(percent) %"
        case .queued: return "Génération en attente…"
        case .analyzing: return "Création des flashcards…"
        case .preparing, nil: return "Préparation du cours…"
        }
    }

    /// `generateFlashcards` : exige un cours et l'accord IA, puis interroge le
    /// relais. Les cartes manuelles sont conservées, le résultat persisté.
    private func generate() {
        guard !generating else { return }
        guard hasCourseDocument, TrainCourseDocument.load(year: programYear, chapterId: chapterId) != nil else {
            alertMessage = "Télécharge d’abord ton cours en PDF, JPEG ou PNG pour générer tes flashcards."
            return
        }
        guard CtdAiConsent.isGranted else {
            pendingGeneration = true
            consentVisible = true
            return
        }
        startGeneration()
    }

    /// Lance la génération par le relais (`generateCourseFlashcardsFromPdf`).
    private func startGeneration() {
        guard !generating else { return }
        guard let course = TrainCourseDocument.load(year: programYear, chapterId: chapterId) else { return }
        let accountId = session.session?.publicId ?? ""
        let storage = CollUserDefaultsFlashcardJobStorage(accountId: accountId)
        generating = true
        generationTask = Task {
            defer { generating = false; generationProgress = nil; generationTask = nil }
            do {
                let generated = try await CollFlashcardsApi.generateCourseFlashcardsFromPdf(
                    accountId: accountId,
                    document: course,
                    chapterName: chapterName,
                    storage: storage,
                    token: session.token,
                    options: CollFlashcardGenerationOptions(
                        jobStorageKey: TrainCourseKnowledge.jobStorageKey(
                            year: programYear, chapterId: chapterId
                        ),
                        onProgress: { progress in
                            Task { @MainActor in generationProgress = progress }
                        }
                    )
                )
                let keptUserCards = cards.filter { $0.origin == .user }
                let next = CollFlashcardsDocument(
                    version: generated.version,
                    generatedAt: generated.generatedAt,
                    sourceName: generated.sourceName,
                    cards: generated.cards + keptUserCards,
                    decks: document?.decks ?? generated.decks
                )
                saveChapter(chapterId, next)
                reviewDeck = nil
            } catch {
                if error is CollFlashcardGenerationCancelledError { return }
                alertMessage = CollFlashcardsApi.generationErrorMessage(error)
            }
        }
    }

    // MARK: - Créer

    /// Paquets du menu de création (`courseFlashcardDecks`).
    private var createDecks: [CollDeckDefinition] {
        CollFlashcards.deckDefinitions(for: document)
    }

    /// Panneau « Créer » (`FlashcardEditorFields` + boutons Ajouter/Enregistrer,
    /// `8597-8676`) : menu de paquet, éditeur, liste des cartes existantes.
    private var createPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SubjFlashcardDropdown(
                label: "Type de flashcards",
                options: createDecks,
                selected: createDeck,
                onSelect: { key in
                    createDeck = key
                    if key != SubjFlashcardSelectionKey.create { customDeckName = "" }
                },
                allowCreate: true
            )
            if createDeck == SubjFlashcardSelectionKey.create {
                TextField("Nom du nouveau type", text: $customDeckName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 13)
                    .frame(minHeight: 46)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMedium)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            }
            SubjFlashcardEditor(
                front: front,
                back: back,
                chapterId: chapterId,
                chapterName: chapterName,
                subject: subject,
                onChangeFront: { front = $0 },
                onChangeBack: { back = $0 }
            )
            addButton
            if editingCardId != nil {
                Button("Annuler la modification") { resetEditor() }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .buttonStyle(.plain)
            }
            if !cards.isEmpty {
                existingCards
            }
        }
    }

    /// Bouton Ajouter/Enregistrer (`8624-8643`).
    private var addButton: some View {
        Button {
            saveEditor()
        } label: {
            HStack(spacing: 8) {
                IonIcon(
                    name: editingCardId != nil ? "checkmark" : "add-outline",
                    size: 17,
                    color: Theme.surface
                )
                Text(editingCardId != nil ? "Enregistrer" : "Ajouter")
                    .font(.system(size: 15, weight: .heavy))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
        .accessibilityLabel(editingCardId != nil ? "Enregistrer la flashcard" : "Ajouter la flashcard")
    }

    /// Cartes existantes, chacune rouvrant l'éditeur (`editFlashcard`).
    private var existingCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cartes existantes")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
            ForEach(cards) { card in
                Button {
                    editingCardId = card.id
                    createDeck = card.deck
                    customDeckName = ""
                    front = card.question
                    back = card.answer
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(createDecks.first { $0.key == card.deck }?.label ?? card.deck)
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(Theme.inkFaint)
                            Text(card.question)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 19))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(12)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMedium)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// `saveFlashcardEditor` : contrôle recto/verso + nom du type, fusionne la
    /// carte (création `user-…` ou modification) et persiste.
    private func saveEditor() {
        let question = front.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = back.trimmingCharacters(in: .whitespacesAndNewlines)
        let customLabel = customDeckName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !answer.isEmpty else {
            alertMessage = "Renseigne le recto et le verso de la flashcard."
            return
        }
        if createDeck == SubjFlashcardSelectionKey.create, customLabel.isEmpty {
            alertMessage = "Donne un nom au nouveau type de flashcards."
            return
        }
        let now = TrainChapterFlashcards.now()
        let customKey = customLabel.isEmpty ? nil : TrainFlashcardDeckNaming.customDeckKey(customLabel, fallback: now)
        let deck = createDeck == SubjFlashcardSelectionKey.create ? customKey! : createDeck
        let current = document ?? CollFlashcardsDocument(
            version: 1, generatedAt: now, sourceName: "Création manuelle", cards: [], decks: nil
        )
        var decks = current.decks
        if let customKey, !(decks ?? []).contains(where: { $0.key == customKey }) {
            decks = (decks ?? []) + [CollDeckDefinition(key: customKey, label: customLabel, description: nil)]
        }
        let cards: [CollFlashcard]
        if let editingCardId, current.cards.contains(where: { $0.id == editingCardId }) {
            cards = current.cards.map { $0.id == editingCardId
                ? CollFlashcard(id: $0.id, deck: deck, question: question, answer: answer,
                                verdict: $0.verdict, seenAt: $0.seenAt, origin: $0.origin,
                                sourcePosition: $0.sourcePosition,
                                correctStreak: $0.correctStreak, requiredCorrect: $0.requiredCorrect)
                : $0 }
        } else {
            cards = current.cards + [CollFlashcard(
                id: "user-\(Int(now))-\(TrainFlashcardDeckNaming.randomSuffix())",
                deck: deck, question: question, answer: answer,
                verdict: nil, seenAt: nil, origin: .user
            )]
        }
        saveChapter(chapterId, CollFlashcardsDocument(
            version: current.version,
            generatedAt: current.generatedAt,
            sourceName: current.sourceName,
            cards: cards,
            decks: (decks?.isEmpty == false) ? decks : nil
        ))
        resetEditor()
    }

    /// `resetFlashcardEditor` : vide l'éditeur.
    private func resetEditor() {
        editingCardId = nil
        createDeck = "definitions"
        customDeckName = ""
        front = ""
        back = ""
    }
}

/// Onglets de la surface « Cartes » : Générer / Créer / Réviser.
enum TrainFlashcardPanelTab: String, CaseIterable, Identifiable {
    case generate
    case create
    case review

    var id: String { rawValue }

    var label: String {
        switch self {
        case .generate: return "Générer"
        case .create: return "Créer"
        case .review: return "Réviser"
        }
    }

    var ionName: String {
        switch self {
        case .generate: return "sparkles-outline"
        case .create: return "add-outline"
        case .review: return "play-outline"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .generate: return "Générer les flashcards"
        case .create: return "Créer une flashcard"
        case .review: return "Réviser mes flashcards"
        }
    }
}

/// Normalisation d'un nom de paquet personnalisé (`custom-…`). Espace de noms
/// distinct de la vue `TrainFlashcardsPanel` (une seule déclaration de type par
/// nom).
enum TrainFlashcardDeckNaming {
    /// Clé `custom-xxx` ASCII (`normalize('NFD')`, minuscules, tirets).
    static func customDeckKey(_ label: String, fallback: Double) -> String {
        let folded = label.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let slug = folded.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return "custom-\(slug.isEmpty ? String(Int(fallback)) : slug)"
    }

    /// Suffixe aléatoire d'une carte manuelle (`Math.random().toString(36)`).
    static func randomSuffix() -> String {
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        return String((0..<6).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
    }
}
