import SwiftUI

// V1 2026-09-26 (U06#4) : fichier neuf. Surface « Cartes » d'un chapitre :
// onglets « Générer / Créer / Réviser » (`coursePage === 'flashcards'`,
// `SubjectsScreen.tsx:8506-8736`) — génération (`generateFlashcards` `5069`,
// ici la génération locale déterministe `CollFlashcards.generate` via un
// protocole injectable : seam honnête, le relais IA restant indisponible),
// création avec persistance (`saveFlashcardEditor` `5562`) et panneau de
// révision (`TrainFlashcardReviewPanel`).
//
// Onglets « Lire / Générer / Créer / Réviser » de la source (`8044/8075/8117/
// 8158`) : « Lire » est la page « Mon cours » elle-même (`TrainCoursePage`),
// les trois autres vivent ici.

/// Génération de flashcards : la source appelle le relais IA
/// (`generateCourseFlashcardsFromPdf`). Le port iOS n'a pas de relais : le
/// protocole rend cette dépendance explicite, et l'implémentation par défaut
/// produit la génération locale déterministe (`CollFlashcards.generate`), qui
/// reste disponible hors connexion.
protocol TrainFlashcardGenerator {
    func generate(chapterName: String, sourceName: String) -> CollFlashcardsDocument
}

/// Génération locale déterministe, disponible hors connexion.
struct TrainLocalFlashcardGenerator: TrainFlashcardGenerator {
    func generate(chapterName: String, sourceName: String) -> CollFlashcardsDocument {
        CollFlashcards.generate(chapterName: chapterName, sourceName: sourceName)
    }
}

/// Surface « Cartes » d'un chapitre : onglets Générer / Créer / Réviser.
struct TrainFlashcardsPanel: View {
    let subject: String
    let chapterId: String
    let chapterName: String
    /// Document de cours : la génération exige un cours importé.
    let hasCourseDocument: Bool
    /// Position du repère (`coursePosition`) : la révision s'arrête au repère.
    let coursePosition: Double
    /// Persistance d'un document de chapitre (`saveFlashcardChapterDocument`).
    var onSave: ((String, CollFlashcardsDocument) -> Void)? = nil
    var generator: TrainFlashcardGenerator = TrainLocalFlashcardGenerator()

    /// Cartes du chapitre (`courseFlashcards`), relues à l'ouverture.
    @State private var document: CollFlashcardsDocument?
    @State private var loaded = false
    @State private var panel: TrainFlashcardPanelTab = .generate
    @State private var generating = false

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
                tabRow
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

    // MARK: - Onglets

    /// Onglets Générer / Créer / Réviser (`8075/8117/8158`).
    private var tabRow: some View {
        HStack(spacing: 8) {
            ForEach(TrainFlashcardPanelTab.allCases) { tab in
                Button {
                    panel = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 16))
                        Text(tab.label)
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(panel == tab ? Theme.surface : Theme.inkSoft)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(panel == tab ? Theme.ink : Theme.surface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Theme.border, lineWidth: panel == tab ? 0 : 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.accessibilityLabel)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Générer

    /// Panneau « Générer » (`flashcardPanel === 'generate'`, `8508-8560`) :
    /// hint, bouton d'obtention/régénération, statut des cartes générées.
    private var generatePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hasCourseDocument
                ? "La génération couvre tout le cours. La révision s’arrête au repère du cours vu en classe."
                : "Ajoute un cours PDF, JPEG ou PNG dans « Mon cours » pour utiliser la génération automatique.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                generate()
            } label: {
                HStack(spacing: 8) {
                    if generating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Theme.surface)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 17))
                    }
                    Text(hasGenerated ? "Régénérer mes flashcards" : "Obtenir les flashcards de mon cours")
                        .font(.system(size: 15, weight: .heavy))
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(DuelloPrimaryButton())
            .disabled(generating)
            .accessibilityLabel(hasGenerated ? "Régénérer mes flashcards" : "Obtenir les flashcards de mon cours")
            if hasGenerated, let document {
                let total = document.cards.filter { $0.origin != .user }.count
                let revisable = CollFlashcardReview.seenSoFar(document.cards.filter { $0.origin != .user }, coursePosition: coursePosition).count
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.progress)
                    Text("\(total) flashcard\(total > 1 ? "s" : "") générée\(total > 1 ? "s" : ""). \(revisable) révisable\(revisable > 1 ? "s" : "") jusqu’au repère actuel.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// `generateFlashcards` : exige un cours, produit les cartes et les fusionne
    /// avec les cartes manuelles conservées, puis persiste.
    private func generate() {
        guard !generating else { return }
        guard hasCourseDocument else {
            alertMessage = "Télécharge d’abord ton cours en PDF, JPEG ou PNG pour générer tes flashcards."
            return
        }
        generating = true
        defer { generating = false }
        let generated = generator.generate(chapterName: chapterName, sourceName: chapterName)
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
                Image(systemName: editingCardId != nil ? "checkmark" : "plus")
                    .font(.system(size: 17, weight: .bold))
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
        let customKey = customLabel.isEmpty ? nil : TrainFlashcardsPanel.customDeckKey(customLabel, fallback: now)
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
                id: "user-\(Int(now))-\(TrainFlashcardsPanel.randomSuffix())",
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

    var systemImage: String {
        switch self {
        case .generate: return "sparkles"
        case .create: return "plus"
        case .review: return "play"
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

/// Normalisation d'un nom de paquet personnalisé (`custom-…`).
enum TrainFlashcardsPanel {
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
