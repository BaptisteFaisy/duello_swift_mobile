//
//  CourseDocumentView.swift
//  Duello
//
//  Port de `src/components/CourseDocumentViewer.native.tsx` (+ la section
//  « Mon cours » de `src/screens/SubjectsScreen.tsx`).
//
//  Parité RN↔Swift (vague 2, 2026-09-29) :
//    - chevron de la fiche du prof IA (P1) : `ProfTutorSheet` reçoit
//      `onOpenProfile`, qui ouvre la fiche dans l'onglet « Mon compte »
//      (`SubjectsScreen.tsx:8555-8560`, `openMemberProfile` `App.tsx:1471-1490`) ;
//      même couture de routage que le tap de notification
//      (`PushNotifRootCoordinator`, `PushNotifRootMount.swift`).
//
//  Parité RN↔Swift (vague 6, 2026-09-30) :
//    - texte du cours joint au prof IA (`useProfCourseText`,
//      `SubjectsScreen.tsx:4043-4084`) : `CtdDocumentViewer` monte
//      `ProfCourseTextSession`, le relit à chaque changement de document et
//      porte le texte dans `ProfDocuments.course` (`courseDocument`).
//
//  Écarts assumés :
//    - PDF.js (~3,3 Mo de JavaScript, `src/utils/courseDocumentPdf.ts`) n'est pas
//      portable : PDFKit rend les PDF nativement, contrat du lecteur inchangé.
//
import SwiftUI

/// Rendu du contenu d'un document de chapitre (cours ou feuille de TD).
///
/// Porté de `src/components/CourseDocumentViewer.native.tsx`, qui monte une
/// WebView `HtmlDocumentView` : les photos passent par le document HTML de
/// `CtdDocumentHtml`, les PDF par PDF.js. PDF.js (~3,3 Mo de JavaScript
/// embarqué, `src/utils/courseDocumentPdf.ts`) n'est pas portable — aucune
/// dépendance externe — et iOS rend les PDF nativement : `CtdPdfDocumentView`
/// remplace ce moteur sans changer le contrat du lecteur.
///
/// Le repère de progression de classe (`positioning`, `initialPosition`,
/// `onPositionChange`) et le pont du prof IA sont portés par ce lecteur : les
/// hôtes de la section « Mon cours » les raccordent (`TrainCoursePage`).
/// Écart assumé : iOS 16 n'a pas d'API d'offset de défilement (`contentOffset`
/// de RN) ; la position se règle donc par la glissière de `TrainCoursePage`
/// tant que l'hôte ne pilote pas la ligne rouge par le défilement.

// MARK: - Contenu chargé

/// Contenu prêt à l'affichage.
enum CtdDocumentPayload {
    /// Photo de cours ou de TD (JPEG ou PNG), rendue par le document HTML.
    case image(base64: String, mimeType: CtdMimeType)
    /// PDF, rendu par PDFKit.
    case pdf(Data)
}

/// Erreur de lecture d'un document local.
enum CtdDocumentError: LocalizedError {
    case unreadable

    var errorDescription: String? { "Le cours n’a pas pu être ouvert." }
}

/// Lecture d'un document local (`readCourseDocumentBase64` de
/// `CourseDocumentViewer.native.tsx`).
enum CtdDocumentLoader {
    /// Charge le document : base64 pour une photo, octets pour un PDF.
    static func load(uri: String, mimeType: CtdMimeType) throws -> CtdDocumentPayload {
        let data = try data(uri: uri)
        guard mimeType.isImage else { return .pdf(data) }
        return .image(base64: data.base64EncodedString(), mimeType: mimeType)
    }

    /// Octets du document : fichier local, ou contenu d'une URI `data:`
    /// héritée du web.
    static func data(uri: String) throws -> Data {
        if uri.hasPrefix("data:"), let comma = uri.firstIndex(of: ",") {
            let encoded = String(uri[uri.index(after: comma)...])
            guard let decoded = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) else {
                throw CtdDocumentError.unreadable
            }
            return decoded
        }
        guard let url = fileURL(uri), let data = try? Data(contentsOf: url) else {
            throw CtdDocumentError.unreadable
        }
        return data
    }

    /// `data:` ou `file://` acceptés ; un chemin nu devient une URL de
    /// fichier.
    static func fileURL(_ uri: String) -> URL? {
        if uri.hasPrefix("data:") { return nil }
        if uri.contains("://") { return URL(string: uri) }
        return URL(fileURLWithPath: uri)
    }
}

// MARK: - Lecteur

/// Lecteur d'un document de chapitre : états de préparation, d'échec et de
/// contenu, comme `CourseDocumentViewer`.
struct CtdDocumentViewer: View {
    let uri: String
    let mimeType: CtdMimeType
    /// `revision` : date d'import du document, qui force une nouvelle lecture
    /// quand un import remplace le fichier affiché.
    let revision: Double
    var height: CGFloat = 330
    /// `positioning` : le repère rouge est affiché et suit le défilement, pour
    /// que l'élève place la position atteinte (`CourseDocumentViewer.native.tsx:178-182`).
    var positioning: Bool = false
    /// `initialPosition` : position (0…1) à retrouver à l'ouverture.
    var initialPosition: Double? = nil
    /// `onPositionChange` : position (0…1) du repère, à chaque défilement.
    var onPositionChange: ((Double) -> Void)? = nil
    /// `onReady` : le premier contenu est affiché.
    var onReady: (() -> Void)? = nil
    /// `onComplete` : le document est entièrement rendu.
    var onComplete: (() -> Void)? = nil
    /// Document de cours du chapitre, quand l'hôte le connaît : son texte
    /// extrait accompagne chaque demande au prof IA (`useProfCourseText`,
    /// `ProfDocuments.course`). `nil` pour un énoncé de colle ou une feuille de
    /// TD, qui ne sont pas le cours du chapitre (`storedCourseDocument`).
    var courseDocument: CtdStoredCourseDocument? = nil

    /// Session Duello (injectée à la racine) : fournit le jeton du prof IA.
    @EnvironmentObject private var session: SessionStore

    @State private var payload: CtdDocumentPayload?
    @State private var failed = false
    @State private var retryRevision = 0
    /// Texte du cours du chapitre, prêt pour le prof IA (`useProfCourseText`) :
    /// relu dès qu'un cours est montré, jamais à la première question.
    @StateObject private var courseText = ProfCourseTextSession()
    /// Demande du prof IA posée par le pont ; `nil` ferme la feuille.
    @State private var profRequest: ProfTutorRequest?
    /// Demande retenue le temps que l'élève accorde (ou refuse) l'IA.
    @State private var profPendingRequest: ProfTutorRequest?
    @State private var profConsentVisible = false

    var body: some View {
        Group {
            if failed {
                failure
            } else if let payload {
                content(payload)
            } else {
                loading
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .task(id: loadKey) { load() }
        // `useProfCourseText` : le texte du cours est demandé dès que le
        // document est montré, jamais à la première question ; changer de
        // document relance la lecture (`useEffect([document, storage])`).
        .task(id: courseDocument?.id) { @MainActor in
            courseText.update(document: courseDocument, token: session.token)
        }
        // `ProfTutorSheet` : `onDismiss` remet l'item à `nil`, indispensable au
        // glissement vers le bas, qui ne passe pas par `onClose`.
        .sheet(item: $profRequest, onDismiss: { profRequest = nil }) { request in
            ProfTutorSheet(
                request: request,
                token: session.token,
                // `onOpenProfile` : le chevron de l'en-tête ouvre la fiche du
                // prof IA (`SubjectsScreen.tsx:8555-8560`) dans l'onglet
                // « Mon compte », via le coordinateur racine — même couture que
                // le tap de notification (`PushNotifRootMount`).
                onOpenProfile: { memberId in
                    Task { @MainActor in
                        PushNotifRootCoordinator.shared.pendingMember =
                            PushNotifPendingMember(id: memberId)
                    }
                }
            ) { profRequest = nil }
        }
        // `requireAiDataSharingConsent` : l'explication transmet le passage au
        // relais, donc l'accord de l'élève est demandé d'abord.
        .alert(CtdAiConsent.title, isPresented: $profConsentVisible) {
            Button(CtdAiConsent.denyLabel, role: .cancel) { profPendingRequest = nil }
            Button(CtdAiConsent.allowLabel) { grantProfConsent() }
        } message: {
            Text(CtdAiConsent.message)
        }
    }

    /// Clé de rechargement : document, révision et essai manuel.
    private var loadKey: String { "\(uri)#\(revision)#\(retryRevision)" }

    /// `readCourseDocumentBase64` : relit le document, et bascule sur l'échec
    /// si le fichier ne peut plus être ouvert.
    private func load() {
        failed = false
        payload = nil
        do {
            payload = try CtdDocumentLoader.load(uri: uri, mimeType: mimeType)
        } catch {
            failed = true
        }
    }

    @ViewBuilder
    private func content(_ loaded: CtdDocumentPayload) -> some View {
        switch loaded {
        case .image(let base64, let mimeType):
            // `textSelection` de la source : la sélection est ouverte pour que
            // le pont du prof IA (« Expliquer ce passage ») puisse la lire ; le
            // pont bloque lui-même copie, coupe et menu contextuel.
            CtdHtmlDocumentView(
                html: CtdDocumentHtml.imageHtml(
                    base64: base64,
                    mimeType: mimeType,
                    positioning: positioning,
                    initialPosition: initialPosition,
                    // Le pont « Expliquer cette photo » est toujours disponible :
                    // le lecteur relaie `duello-prof-explain-image` au prof IA.
                    profExplain: true
                ),
                selectable: true,
                onMessage: handleMessage
            )
        case .pdf(let data):
            CtdPdfDocumentView(
                data: data,
                positioning: positioning,
                initialPosition: initialPosition,
                onPositionChange: onPositionChange,
                onReady: onReady,
                onComplete: onComplete,
                // « Expliquer ce passage » : la sélection PDFKit part au prof IA
                // comme une sélection du pont HTML (`courseDocumentPdf.ts:50,83`,
                // `CoursePdfView`). Même couture que `handleMessage(.explain)`.
                onExplain: { text, page in
                    handleProfBridgeEvent(.explain(text: text, page: page))
                }
            )
        }
    }

    /// Le document prévient quand la photo n'a pas pu s'afficher
    /// (`type: "error"`), publie les événements de cycle de vie (`ready`,
    /// `complete`, `position`) et les messages du pont du prof IA (sélection
    /// expliquée, copie bloquée, page sans texte).
    private func handleMessage(_ text: String) {
        if let profEvent = parseProfBridgeMessage(text) {
            handleProfBridgeEvent(profEvent)
            return
        }
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let event = object as? [String: Any],
              let type = event["type"] as? String
        else { return }
        switch type {
        case "error":
            failed = true
        case "ready":
            onReady?()
            // Une photo est complète dès qu'elle est affichée ; un PDF, non.
            if mimeType.isImage { onComplete?() }
        case "complete":
            onComplete?()
        case "position":
            if let position = event["position"] as? Double { onPositionChange?(position) }
        default:
            break
        }
    }

    /// `onMessage` du pont : une sélection (ou une photo) expliquée ouvre la
    /// feuille après accord IA ; copie bloquée et page sans texte restent au
    /// script (`CourseDocumentViewer.native.tsx:118-151`).
    private func handleProfBridgeEvent(_ event: ProfBridgeEvent) {
        switch event {
        case .explain(let passage, let page):
            presentProf(ProfTutorRequest(
                quote: passage,
                context: ProfTutorContext(
                    source: .cours,
                    page: page,
                    student: profStudent,
                    documents: profCourseDocuments
                )
            ))
        case .explainImage(let image, let page):
            // Photo ou page scannée : `quote` est vide, le relais vision lit
            // l'image (`parseProfImageDataUrl`).
            guard let parsed = parseProfImageDataUrl(image) else { return }
            presentProf(ProfTutorRequest(
                quote: "",
                image: parsed.base64,
                mimeType: parsed.mimeType,
                context: ProfTutorContext(
                    source: .cours,
                    page: page,
                    student: profStudent,
                    documents: profCourseDocuments
                )
            ))
        case .copyBlocked, .noText:
            break
        }
    }

    /// Ouvre la feuille du prof IA, après accord de partage si nécessaire.
    private func presentProf(_ request: ProfTutorRequest) {
        guard CtdAiConsent.isGranted else {
            profPendingRequest = request
            profConsentVisible = true
            return
        }
        profRequest = request
    }

    /// Accord donné : la demande retenue s'ouvre (`resolveConsent` de
    /// `CourseTdView`).
    private func grantProfConsent() {
        CtdAiConsent.grant()
        guard let pending = profPendingRequest else { return }
        profPendingRequest = nil
        profRequest = pending
    }

    /// Socle v2 de la fenêtre de contexte du prof (`profStudentContext`,
    /// `profTutor.ts:56`) : identité de l'élève et programme de sa filière et de
    /// son année, joints à chaque demande du cours (`SubjectsScreen.tsx:4043,
    /// 4053-4084`). L'année suit `toProgramYear` du profil.
    private var profStudent: ProfStudent {
        profStudentContext(
            profile: session.profile,
            programYear: HecJourneyProfile.programYear(from: session.profile.year)
        )
    }

    /// `ProfDocuments` du cours affiché (`profContextBase.course`,
    /// `SubjectsScreen.tsx:4043-4084`) : texte extrait du cours du chapitre
    /// (`useProfCourseText`) et nom du fichier, rognés par `profTutorContext`
    /// (`PROF_COURSE_MAX_CHARS`). `nil` quand l'hôte n'a pas fourni le cours
    /// (énoncé de colle, feuille de TD) ou qu'aucun texte exploitable n'en a été
    /// extrait (photo, scan) — le prof s'en tient alors à la page sélectionnée.
    private var profCourseDocuments: ProfDocuments? {
        guard let courseDocument else { return nil }
        let input = ProfContextInput(
            source: .cours,
            student: profStudent,
            course: (name: courseDocument.name, text: courseText.courseText)
        )
        return profTutorContext(input).documents
    }

    private var loading: some View {
        VStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Theme.ink)
            Text("Préparation du cours…")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var failure: some View {
        VStack(spacing: 10) {
            Text("Le cours n’a pas pu être ouvert.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button { retryRevision += 1 } label: {
                Text("Réessayer")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.surface)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Réessayer d’ouvrir le cours")
        }
        .padding(24)
    }
}

// MARK: - Plein écran

/// Bouton d'ouverture plein écran, posé sur le lecteur.
///
/// Reprend le bouton de la section « Mon cours » de `SubjectsScreen.tsx` :
/// carré arrondi blanc à bord fin, posé en haut à droite du document.
struct CtdFullscreenButton: View {
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            IonIcon(name: "expand-outline", size: 22, color: Theme.ink)
                .frame(width: 42, height: 42)
                .background(Theme.surface.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Afficher le cours en plein écran")
        .padding(10)
    }
}
