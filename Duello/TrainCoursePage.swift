import SwiftUI
import UniformTypeIdentifiers

// V1 2026-09-26 (U06#3) : fichier neuf. Page « Mon cours » d'un chapitre
// (`selectedMode === 'cours'`, `SubjectsScreen.tsx:7942-8502`) : bouton de
// repère (`placeCourseProgress` `6069`), lecteur (`CourseDocumentViewer`),
// import/remplacement (`uploadCourseDocument` `5828`), suppression
// (`deleteCourseDocument` + `confirmCourseDocumentDeletion`).
//
// V2 2026-09-28 (U06#3, #12) : la page porte désormais les onglets de la
// source « Lire / Générer / Créer / Réviser » (`8044/8075/8117/8158`) ; les
// trois onglets de cartes hébergent `TrainFlashcardsPanel` — l'accès aux
// flashcards vit donc **dans le cours**, plus dans une barre de navigation.
// L'analyse des notions du cours (`indexCourseKnowledge` `4934`,
// `courseAnalysisStatus` `8244`) est montée sous le repère, avec sa reprise
// « Réessayer » (`retryCourseKnowledgeAnalysis` `5061`).
//
// V3 2026-09-29 (complexité) : découpe en extensions de fichier — repère de
// progression (`TrainCoursePagePositioning.swift`), analyse des notions
// (`TrainCoursePageKnowledge.swift`), lecteur + import/remplacement/suppression
// (`TrainCoursePageDocument.swift`), boutons et types auxiliaires
// (`TrainCoursePageChrome.swift`). Swift limite `private` au FICHIER : les
// membres partagés par ces extensions perdent leur `private` (élargis à
// `internal`), corps inchangés.

/// Page « Mon cours » d'un chapitre : onglets Lire / Générer / Créer / Réviser,
/// repère de progression, lecteur du document importé, import/remplacement/
/// suppression, analyse des notions.
struct TrainCoursePage: View {
    let subjectName: String
    let chapter: TrackChapter
    /// Année du programme (`programYear`) : le document est rangé par année.
    let programYear: Int
    /// Statut posé par le repère (`courseStatusAtPosition`).
    var onCourseStatus: ((TrainCourseStatus) -> Void)? = nil
    var onClose: (() -> Void)? = nil

    // V3 : `session` et les états lus par les extensions de ce type vivent
    // désormais dans d'autres fichiers — `private` (portée FICHIER) est retiré,
    // élargi à `internal`. Usages et corps inchangés.
    @EnvironmentObject var session: SessionStore

    /// Document du chapitre (`storedCourseDocument`), relu à l'ouverture.
    @State var document: CtdStoredCourseDocument?
    @State private var loaded = false
    @State var pickerVisible = false
    @State var fullscreenOpen = false
    @State var uploadPending = false
    @State var deletePending = false
    /// Mode de placement du repère (`coursePositioning`) : le lecteur suit le
    /// brouillon, « Enregistrer » le valide.
    @State var positioning = false
    /// Brouillon de position (`coursePositionDraftRef`), 0 à 1.
    @State var positionDraft: Double = 0
    @State var alert: TrainCourseAlert?

    /// Onglet de la page (`coursePage` + `flashcardPanel`).
    @State private var tab: TrainCoursePageTab = .lire

    // Analyse des notions (`courseKnowledgeIndexesByKey`).
    @State var knowledgeIndex: CollKnowledgeDocument?
    @State var knowledgeError: String?
    @State var knowledgeAnalyzing = false
    @State var knowledgeProgress: CollFlashcardGenerationProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if !loaded {
                SubjDeferredInlineFallback(label: "Ouverture du cours…")
            } else {
                tabRow
                switch tab {
                case .lire:
                    courseSection
                case .generate, .create, .review:
                    TrainFlashcardsPanel(
                        subject: subjectName,
                        chapterId: chapter.id,
                        chapterName: chapter.name,
                        programYear: programYear,
                        hasCourseDocument: document != nil,
                        coursePosition: document?.classProgress?.position ?? 0,
                        panel: tab.flashcardPanel ?? .generate
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: chapter.id) { reload() }
        .onDisappear { validateOnLeave() }
        .fileImporter(
            isPresented: $pickerVisible,
            allowedContentTypes: [.pdf, .jpeg, .png],
            allowsMultipleSelection: false,
            onCompletion: handlePickedFile
        )
        .fullScreenCover(isPresented: $fullscreenOpen) {
            if let document {
                TrainCourseFullscreen(
                    document: document,
                    onClose: { fullscreenOpen = false }
                )
            }
        }
        .alert(alertTitle, isPresented: alertBinding) {
            alertButtons
        } message: {
            if let alert { Text(alert.message) }
        }
    }

    // MARK: - Onglets

    /// Barre « Lire / Générer / Créer / Réviser » (`styles.modeTabs`).
    private var tabRow: some View {
        HStack(spacing: 5) {
            ForEach(TrainCoursePageTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    HStack(spacing: 6) {
                        IonIcon(
                            name: item.ionName,
                            size: 16,
                            color: tab == item ? Color.white : Theme.inkSoft
                        )
                        Text(item.label)
                            .font(.system(size: 13, weight: .heavy))
                            .lineLimit(1)
                            .foregroundStyle(tab == item ? Color.white : Theme.inkSoft)
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(tab == item ? Theme.primary : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.accessibilityLabel)
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Contenu de l'onglet « Lire » (`coursePage === 'course'`).
    @ViewBuilder
    private var courseSection: some View {
        if let document {
            positionBlock(document: document)
            knowledgeStatus(document: document)
            documentFrame(document: document)
            replaceButton
            deleteButton
        } else {
            uploadButton
            Text("Importe un PDF ou une photo JPEG/PNG pour générer automatiquement tes flashcards.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Chargement

    /// Relecture du document à l'ouverture du chapitre.
    private func reload() {
        loaded = false
        positioning = false
        tab = .lire
        document = TrainCourseDocument.load(year: programYear, chapterId: chapter.id)
        positionDraft = document?.classProgress?.position ?? 0
        knowledgeIndex = TrainCourseKnowledge.load(year: programYear, chapterId: chapter.id)
        knowledgeError = nil
        knowledgeAnalyzing = false
        knowledgeProgress = nil
        loaded = true
        if let document { startKnowledgeAnalysisIfNeeded(document: document) }
    }

    /// Quitter après avoir déplacé le repère vaut validation : cela évite de
    /// perdre silencieusement la position (`leaveCoursePage`).
    private func validateOnLeave() {
        if positioning { placeProgress() }
    }

    // MARK: - Analyse des notions

    /// Bandeau d'analyse des notions (`courseAnalysisStatus`), montré pour un
    /// PDF seulement.
    @ViewBuilder
    private func knowledgeStatus(document: CtdStoredCourseDocument) -> some View {
        if document.mimeType == .pdf {
            let hasError = knowledgeError != nil
            HStack(alignment: .center, spacing: 8) {
                if knowledgeAnalyzing {
                    ProgressView().controlSize(.small).tint(Theme.inkSoft)
                } else {
                    IonIcon(
                        name: knowledgeIndex != nil
                            ? "checkmark-circle-outline"
                            : hasError ? "alert-circle-outline" : "time-outline",
                        size: 17,
                        color: hasError ? Color(hex: 0xA31616) : Theme.inkSoft
                    )
                }
                Text(knowledgeStatusText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if hasError {
                    Button {
                        retryKnowledgeAnalysis()
                    } label: {
                        Text("Réessayer")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color(hex: 0xA31616))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 30)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Réessayer l’analyse du cours")
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(minHeight: 42, alignment: .leading)
            .background(hasError ? Color(hex: 0xFFF1F1) : Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: - Alertes

    private var alertTitle: String {
        switch alert {
        case .confirmDeletion: return "Supprimer le document ?"
        case .importFailed: return "Cours non importé"
        case .deleteFailed: return "Suppression impossible"
        case nil: return ""
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alert != nil },
            set: { if !$0 { alert = nil } }
        )
    }

    @ViewBuilder
    private var alertButtons: some View {
        switch alert {
        case .confirmDeletion:
            Button("Annuler", role: .cancel) { alert = nil }
            Button("Supprimer", role: .destructive) {
                alert = nil
                deleteCourseDocument()
            }
        case .importFailed, .deleteFailed, nil:
            Button("OK", role: .cancel) { alert = nil }
        }
    }
}
