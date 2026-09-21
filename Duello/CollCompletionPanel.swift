//
//  CollCompletionPanel.swift
//  Duello
//
//  Panneau « Ma colle » d'un chapitre : import de l'énoncé PDF, repère de la
//  position atteinte, puis questions restantes corrigées par l'IA.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/ColleCompletionPanel.tsx
//        bouton « Ma colle », note de la colle, les trois étapes du flux,
//        cartes de question, alerte « Énoncé non importé ».
//
//  Les sous-vues (étapes, note, fiche de question, correction) vivent dans
//  `CollCompletionViews.swift` ; l'état persistant, dans `CollCompletionStore.swift`.
//
//  Limite documentée : la source suit la position de lecture de l'énoncé via le
//  moteur PDF.js (`positioning` / `onPositionChange`). Ce suivi n'est pas
//  portable ; le lecteur PDF natif `CtdDocumentViewer` est réutilisé et la
//  position est réglée par un curseur borné `[0, 1]`.
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI
import UniformTypeIdentifiers

/// Panneau de fin de colle d'un chapitre.
struct CollCompletionPanel: View {
    let chapterId: String
    let chapterName: String
    /// Filière, année et option dont le programme borne les méthodes admises.
    let gradingProgram: String
    /// Appelé quand la correction refuse la session locale.
    var onAuthenticationRequired: (() -> Void)? = nil

    @EnvironmentObject private var session: SessionStore
    @StateObject private var store = CollCompletionStore()

    @State private var open = false
    @State private var loaded = false
    @State private var positionDraft: Double = 0
    @State private var importing = false
    @State private var gradingQuestionId: String?
    @State private var questionErrors: [String: String] = [:]
    @State private var pickerVisible = false
    @State private var importFailedVisible = false

    /// `calculateColleScore(value.questions)`.
    private var score: CollGradingScore { CollGradingScore.colle(store.value.questions) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !loaded {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                finishButton
                if let scoreOn20 = score.scoreOn20 {
                    CollScoreCard(score: score, scoreOn20: scoreOn20)
                }
                if open { workflow }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: chapterId) { reload() }
        .onChange(of: store.value) { _ in store.scheduleSave() }
        .onDisappear { store.persistNow() }
        .fileImporter(
            isPresented: $pickerVisible,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false,
            onCompletion: handlePickedFile
        )
        .alert("Énoncé non importé", isPresented: $importFailedVisible) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Choisis un fichier PDF lisible, puis réessaie.")
        }
    }

    // MARK: - Bouton d'en-tête

    private var finishButton: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 9) {
                Image(systemName: "flag")
                    .font(.system(size: 17, weight: .semibold))
                Text("Ma colle")
                    .font(.system(size: 15, weight: .heavy))
                Spacer(minLength: 8)
                Image(systemName: open ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(Theme.surface)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ma colle")
    }

    // MARK: - Flux

    @ViewBuilder
    private var workflow: some View {
        CollStepHeading(number: 1, title: "Importe l’énoncé", hint: "Le PDF reste enregistré uniquement dans ton compte.")
        if let statement = store.value.statement {
            CtdFileRow(
                name: statement.name,
                sizeLabel: CtdFormatters.fileSize(statement.size),
                busy: importing,
                onReplace: presentPicker
            )
            CollStepHeading(number: 2, title: "Place le curseur où tu t’es arrêté", hint: "Fais défiler l’énoncé : le trait rouge indique jusqu’où tu as réussi.")
            statementViewer(statement)
            Button(action: saveReachedPosition) {
                Text(statement.reachedPosition == nil
                     ? "J’ai réussi jusque-là"
                     : "Mettre à jour ma progression")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMedium)
                            .stroke(Theme.ink, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        } else {
            importButton
        }
        if store.value.statement?.reachedPosition != nil {
            CollStepHeading(number: 3, title: "Termine les questions restantes", hint: "Ajoute une fiche par question, puis soumets ta réponse à l’IA.")
            questionList
            addQuestionButton
        }
    }

    /// Lecteur de l'énoncé et curseur de position (voir limite en en-tête).
    private func statementViewer(_ statement: CollStatementDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CtdDocumentViewer(
                uri: statement.uri,
                mimeType: .pdf,
                revision: statement.importedAt,
                height: 390
            )
            Slider(value: $positionDraft, in: 0...1)
                .tint(Theme.like)
                .accessibilityLabel("Position atteinte dans l’énoncé")
        }
    }

    private var importButton: some View {
        Button(action: presentPicker) {
            HStack(spacing: 8) {
                if importing {
                    ProgressView().progressViewStyle(.circular).tint(Theme.surface)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                }
                Text("Importer l’énoncé en PDF")
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(importing)
    }

    private var questionList: some View {
        ForEach(Array(store.value.questions.indices), id: \.self) { index in
            let question = store.value.questions[index]
            CollQuestionCard(
                index: index,
                question: question,
                grading: gradingQuestionId == question.id,
                disabled: gradingQuestionId != nil,
                error: questionErrors[question.id],
                onChangePrompt: { updateQuestion(question.id, prompt: $0, answer: nil) },
                onChangeAnswer: { updateQuestion(question.id, prompt: nil, answer: $0) },
                onDelete: { store.update { $0.questions.removeAll { $0.id == question.id } } },
                onSubmit: { submitQuestion(question) }
            )
        }
    }

    private var addQuestionButton: some View {
        Button {
            store.update { $0.questions.append(CollCompletionPanel.emptyQuestion()) }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                Text("Ajouter une question restante")
                    .font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 47)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    /// `useEffect([chapterId])` : relit la colle, ouvre le flux si un énoncé
    /// existe déjà, et recale le curseur de position.
    private func reload() {
        loaded = false
        store.load(chapterId: chapterId)
        positionDraft = store.value.statement?.reachedPosition ?? 0
        open = store.value.statement != nil
        questionErrors = [:]
        loaded = true
    }

    /// `emptyQuestion()` : identifiant unique de la source.
    private static func emptyQuestion() -> CollRemainingQuestion {
        CollRemainingQuestion(
            id: "colle-question-\(Int(CollCompletion.now()))-\(UUID().uuidString.prefix(6).lowercased())",
            prompt: "",
            answer: "",
            points: nil,
            grade: nil
        )
    }

    /// `updateQuestion` : modifie un champ et efface la correction périmée.
    private func updateQuestion(_ id: String, prompt: String?, answer: String?) {
        store.update { document in
            guard let index = document.questions.firstIndex(where: { $0.id == id }) else { return }
            if let prompt { document.questions[index].prompt = prompt }
            if let answer { document.questions[index].answer = answer }
            document.questions[index].grade = nil
        }
        questionErrors[id] = nil
    }

    /// `importStatement` : ouvre le sélecteur de documents.
    private func presentPicker() {
        importing = true
        pickerVisible = true
    }

    /// PDF choisi, copié sous `duello-colles`, puis enregistré comme énoncé.
    private func handlePickedFile(_ result: Result<[URL], Error>) {
        defer { importing = false }
        guard case .success(let urls) = result, let url = urls.first else { return }
        importStatement(from: url)
    }

    /// `importStatement` : copie le PDF dans le dossier local du compte.
    private func importStatement(from url: URL) {
        let name = url.lastPathComponent
        guard name.lowercased().hasSuffix(".pdf") else {
            importFailedVisible = true
            return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            importFailedVisible = true
            return
        }
        let directory = CollStorage.importsDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let accountId = session.session?.publicId ?? "local"
        let destination = directory.appendingPathComponent("\(accountId)-\(chapterId).pdf")
        try? FileManager.default.removeItem(at: destination)
        do {
            try data.write(to: destination)
        } catch {
            importFailedVisible = true
            return
        }
        let statement = CollStatementDocument(
            uri: destination.absoluteString,
            name: name,
            mimeType: CollCompletion.pdfMimeType,
            size: Double(data.count),
            importedAt: CollCompletion.now(),
            reachedPosition: nil
        )
        store.update { document in
            document.statement = statement
            document.questions = []
        }
        positionDraft = 0
    }

    /// `saveReachedPosition` : enregistre la position et crée la première fiche.
    private func saveReachedPosition() {
        store.update { document in
            guard var statement = document.statement else { return }
            statement.reachedPosition = CollCompletion.normalizedPosition(positionDraft)
            document.statement = statement
            if document.questions.isEmpty {
                document.questions = [CollCompletionPanel.emptyQuestion()]
            }
        }
    }

    /// `submitQuestion` : contrôle les champs, puis note la réponse par l'IA.
    private func submitQuestion(_ question: CollRemainingQuestion) {
        let prompt = question.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = question.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !answer.isEmpty else {
            questionErrors[question.id] = "Renseigne la question et ta réponse avant de les soumettre."
            return
        }
        questionErrors[question.id] = nil
        gradingQuestionId = question.id
        Task { @MainActor in
            defer { gradingQuestionId = nil }
            do {
                let grade = try await CollGradingService.grade(
                    question: question,
                    chapterName: chapterName,
                    program: gradingProgram,
                    token: session.token
                )
                store.update { document in
                    if let index = document.questions.firstIndex(where: { $0.id == question.id }) {
                        document.questions[index].grade = grade
                    }
                }
            } catch {
                if let gradingError = error as? CollGradingError {
                    if case .authentication = gradingError {
                        onAuthenticationRequired?()
                    }
                    questionErrors[question.id] = gradingError.errorDescription
                        ?? "Correction automatique indisponible. Réessaie."
                } else {
                    questionErrors[question.id] = "Correction automatique indisponible. Réessaie."
                }
            }
        }
    }
}
