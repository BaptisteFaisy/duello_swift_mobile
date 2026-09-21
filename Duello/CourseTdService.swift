import Foundation

/// Erreurs d'analyse d'une feuille de TD, alignées sur `courseTdAnalysisError`
/// (`src/utils/courseTdApi.ts`).
enum CtdAnalysisError: LocalizedError {
    /// Délai du relais dépassé (`AbortError`).
    case timedOut
    /// Serveur injoignable (`network request failed`).
    case offline
    /// Refus ou panne du relais, message déjà rédigé par le serveur.
    case relay(String)
    /// Document illisible : Expo laisse remonter l'erreur système, le portage
    /// la remplace par un libellé stable.
    case unreadable(String)
    /// Document au-delà de la limite du relais (`assertDocumentSize`).
    case tooLarge(String)
    /// Analyse rendue par le relais mais inexploitable.
    case incomplete

    var errorDescription: String? {
        switch self {
        case .timedOut:
            return "L’analyse a pris trop de temps. Réessaie dans un instant."
        case .offline:
            return "Le serveur est injoignable. Vérifie ta connexion puis réessaie."
        case .relay(let message):
            return message
        case .unreadable(let label):
            return "\(label) n’a pas pu être ouvert. Réessaie l’import."
        case .tooLarge(let label):
            return "\(label) dépasse 8 Mo. Compresse le fichier, puis réessaie."
        case .incomplete:
            return "L’analyse du TD est incomplète. Réessaie."
        }
    }
}

/// Analyse IA d'une feuille de TD (`analyzeCourseTd`).
///
/// Le relais Duello (`POST /relay`, action `analyze-course-td`) reçoit la
/// feuille et le cours du chapitre en base64, et rend l'indexation concours.
/// Aucune clé de fournisseur n'est utilisée côté client : le jeton de session
/// Duello authentifie l'appel et sert le quota.
enum CtdAnalysisService {
    /// `MAX_DOCUMENT_BYTES` de `courseTdApi.ts`.
    static let maxDocumentBytes = 8 * 1024 * 1024
    /// `setTimeout(…, 180_000)` du relais : l'analyse d'une feuille entière
    /// peut durer plusieurs minutes.
    static let timeout: TimeInterval = 180
    /// Action du relais, mot pour mot de la valeur envoyée par Expo.
    static let analyzeAction = "analyze-course-td"

    /// Envoie la feuille et son cours au relais, puis rend l'analyse.
    static func analyze(
        source: CtdSource,
        course: CtdStoredCourseDocument,
        chapterName: String,
        token: String?
    ) async throws -> CtdAnalysis {
        let tdBase64 = try base64(uri: source.uri, label: "Le TD")
        let courseBase64 = try base64(uri: course.uri, label: "Le cours")
        let body = try requestBody(
            source: source,
            tdBase64: tdBase64,
            course: course,
            courseBase64: courseBase64,
            chapterName: chapterName
        )
        let data = try await post(body: body, token: token)
        guard let analysis = CtdAnalysisParser.parse(
            data,
            analyzedAt: Date().timeIntervalSince1970 * 1000,
            courseUploadedAt: course.uploadedAt
        ) else {
            throw CtdAnalysisError.incomplete
        }
        return analysis
    }

    /// Corps de la requête, mot pour mot des clés envoyées par Expo.
    static func requestBody(
        source: CtdSource,
        tdBase64: String,
        course: CtdStoredCourseDocument,
        courseBase64: String,
        chapterName: String
    ) throws -> Data {
        var payload: [String: Any] = [:]
        payload["action"] = analyzeAction
        payload["chapter"] = chapterName
        payload["tdBase64"] = tdBase64
        payload["tdMimeType"] = source.mimeType.rawValue
        payload["courseBase64"] = courseBase64
        payload["courseMimeType"] = course.mimeType.rawValue
        do {
            return try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            throw CtdAnalysisError.unreadable("Le TD")
        }
    }

    /// `fetch(resolveRelayEndpoint(settings), …)` : requête locale au relais.
    ///
    /// `DuelloAPI.request` plafonne à vingt secondes, insuffisant pour une
    /// analyse complète ; cette requête réutilise `DuelloAPI.baseURL` et le
    /// délai de 180 s du relais, sans modifier le client partagé.
    static func post(body: Data, token: String?) async throws -> Data {
        var request = URLRequest(url: DuelloAPI.baseURL.appendingPathComponent("relay"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let result: (data: Data, response: URLResponse)
        do {
            result = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw CtdAnalysisError.timedOut
        } catch {
            throw CtdAnalysisError.offline
        }
        let data = result.data
        guard let http = result.response as? HTTPURLResponse else { throw CtdAnalysisError.offline }
        guard let payload = relayPayload(data) else {
            throw CtdAnalysisError.relay(
                (200..<300).contains(http.statusCode)
                    ? "Le serveur a renvoyé une analyse illisible."
                    : "Le serveur est momentanément indisponible (\(http.statusCode))."
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            let serverMessage = (payload["error"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw CtdAnalysisError.relay(
                serverMessage.isEmpty
                    ? "Analyse indisponible (\(http.statusCode))."
                    : serverMessage
            )
        }
        return data
    }

    /// `relayData` : corps JSON objet, `nil` s'il est illisible.
    static func relayPayload(_ data: Data) -> [String: Any]? {
        guard !data.isEmpty else { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any]
        else { return nil }
        return dictionary
    }

    /// `base64FromUri` + `assertDocumentSize` : lit le document local et
    /// refuse au-delà de 8 Mo.
    static func base64(uri: String, label: String) throws -> String {
        if uri.hasPrefix("data:") {
            guard let comma = uri.firstIndex(of: ",") else {
                throw CtdAnalysisError.unreadable(label)
            }
            return String(uri[uri.index(after: comma)...])
        }
        guard let url = fileURL(uri), let data = try? Data(contentsOf: url) else {
            throw CtdAnalysisError.unreadable(label)
        }
        guard data.count <= maxDocumentBytes else { throw CtdAnalysisError.tooLarge(label) }
        return data.base64EncodedString()
    }

    /// `data:` (héritage web) ou fichier local ; un chemin nu devient une URL
    /// de fichier.
    static func fileURL(_ uri: String) -> URL? {
        if uri.hasPrefix("data:") { return nil }
        if uri.contains("://") { return URL(string: uri) }
        return URL(fileURLWithPath: uri)
    }

    /// `courseTdAnalysisError` : message affichable pour une erreur d'analyse.
    static func message(for error: Error) -> String {
        if let analysisError = error as? CtdAnalysisError,
           let text = analysisError.errorDescription {
            return text
        }
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
                ? (CtdAnalysisError.timedOut.errorDescription ?? "")
                : (CtdAnalysisError.offline.errorDescription ?? "")
        }
        let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Le TD n’a pas pu être analysé. Réessaie." : text
    }
}
