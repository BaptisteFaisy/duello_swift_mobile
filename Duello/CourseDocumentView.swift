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
/// Le repère de progression de classe (`positioning`) reste hors de ce
/// lecteur : il appartient à la section « Mon cours » de `SubjectsScreen.tsx`.

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

    /// Session Duello (injectée à la racine) : fournit le jeton du prof IA.
    @EnvironmentObject private var session: SessionStore

    @State private var payload: CtdDocumentPayload?
    @State private var failed = false
    @State private var retryRevision = 0
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
        // `ProfTutorSheet` : `onDismiss` remet l'item à `nil`, indispensable au
        // glissement vers le bas, qui ne passe pas par `onClose`.
        .sheet(item: $profRequest, onDismiss: { profRequest = nil }) { request in
            ProfTutorSheet(request: request, token: session.token) { profRequest = nil }
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
                html: CtdDocumentHtml.imageHtml(base64: base64, mimeType: mimeType),
                selectable: true,
                onMessage: handleMessage
            )
        case .pdf(let data):
            CtdPdfDocumentView(data: data)
        }
    }

    /// Le document prévient quand la photo n'a pas pu s'afficher
    /// (`type: "error"`), et publie les événements du pont du prof IA
    /// (sélection expliquée, copie bloquée, page sans texte).
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
        if type == "error" { failed = true }
    }

    /// `onMessage` du pont : une sélection expliquée ouvre la feuille (après
    /// accord IA) ; copie bloquée et page sans texte restent au script.
    private func handleProfBridgeEvent(_ event: ProfBridgeEvent) {
        switch event {
        case .explain(let passage, let page):
            let request = ProfTutorRequest(
                quote: passage,
                context: ProfTutorContext(source: .cours, page: page)
            )
            guard CtdAiConsent.isGranted else {
                profPendingRequest = request
                profConsentVisible = true
                return
            }
            profRequest = request
        case .copyBlocked, .noText:
            break
        }
    }

    /// Accord donné : la demande retenue s'ouvre (`resolveConsent` de
    /// `CourseTdView`).
    private func grantProfConsent() {
        CtdAiConsent.grant()
        guard let pending = profPendingRequest else { return }
        profPendingRequest = nil
        profRequest = pending
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
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
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
