import Foundation

/// Erreur de l'annuaire, alignée sur `DirectoryError` côté Expo.
struct DirectoryError: LocalizedError, Decodable {
    let message: String
    let status: Int?

    var errorDescription: String? { message }

    enum CodingKeys: String, CodingKey { case message = "error" }

    init(message: String, status: Int? = nil) {
        self.message = message
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        message = (try? c.decode(String.self, forKey: .message)) ?? "Service indisponible"
        status = nil
    }
}

/// Client HTTP du backend Duello (voir `src/utils/socialApi.ts`).
/// Adresse figée dans le bundle : relay Cloudflare en production, comme l'app Expo.
enum DuelloAPI {
    /// `DUELLO_API_URL` de `src/config/platform.ts`, en variante production.
    static let baseURL = URL(string: "https://duello-api-relay.duello.workers.dev/api")!

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    /// Identifiant public d'un compte : FNV-1a 32 bits de l'e-mail normalisé,
    /// préfixé `member-` (aligné sur `publicProfileId` de `socialApi.ts`, qui
    /// hache les unités de code UTF-16 de `charCodeAt`).
    static func publicProfileId(email: String) -> String {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let units = Array(normalized.utf16)
        var hash: UInt32 = 0x811c9dc5
        for unit in units {
            hash ^= UInt32(unit)
            hash = hash &* 0x01000193
        }
        return String(format: "member-%x", hash)
    }

    // MARK: Requête générique

    static func request(
        _ path: String,
        method: String = "GET",
        token: String? = nil,
        body: Data? = nil,
        query: [URLQueryItem] = []
    ) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DirectoryError(message: "Le serveur Duello est injoignable.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? decoder.decode(DirectoryError.self, from: data)
            throw DirectoryError(
                message: payload?.message ?? "Service indisponible (\(http.statusCode)).",
                status: http.statusCode
            )
        }
        return data
    }

    static func request<T: Decodable>(
        _ type: T.Type,
        _ path: String,
        method: String = "GET",
        token: String? = nil,
        body: Data? = nil,
        query: [URLQueryItem] = []
    ) async throws -> T {
        let data = try await request(path, method: method, token: token, body: body, query: query)
        return try decoder.decode(T.self, from: data)
    }

    static func encodeBody<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    // MARK: Authentification (voir serverSession.ts)

    struct SessionPayload: Codable {
        var token: String
        var expiresAt: String
        var publicId: String
        var email: String
    }

    struct AuthResponse: Decodable {
        var session: SessionPayload?
        var account: AccountPayload?
        var error: String?
    }

    struct AccountPayload: Decodable {
        var email: String?
        var displayName: String?
        var profile: UserProfile?
    }

    /// `POST /auth/password/login`
    static func login(email: String, password: String) async throws -> SessionPayload {
        let body = try encodeBody(["email": email, "password": password])
        let response = try await request(
            AuthResponse.self,
            "auth/password/login",
            method: "POST",
            body: body
        )
        guard let session = response.session else {
            throw DirectoryError(message: response.error ?? "Authentification Duello indisponible.")
        }
        return session
    }

    /// `POST /auth/password/register`
    static func register(email: String, password: String, displayName: String, deviceId: String) async throws -> SessionPayload {
        let body = try encodeBody([
            "email": email,
            "password": password,
            "displayName": displayName,
            "deviceId": deviceId,
        ])
        let response = try await request(
            AuthResponse.self,
            "auth/password/register",
            method: "POST",
            body: body
        )
        guard let session = response.session else {
            throw DirectoryError(message: response.error ?? "La création du compte est momentanément indisponible.")
        }
        return session
    }

    /// `POST /auth/logout`
    static func logout(token: String) async {
        _ = try? await request("auth/logout", method: "POST", token: token, body: Data("{}".utf8))
    }

    // MARK: Connexion Google

    /// Envelope de la réponse `POST /auth/google`.
    struct GoogleAuthEnvelope: Decodable {
        var identity: GoogleIdentityEnvelope?
        var session: SessionPayload?
        var error: String?
    }

    /// Identité telle que renvoyée par le serveur, avant la revalidation
    /// stricte de `GoogleIdentity.parse` (miroir de `parseGoogleIdentity`).
    struct GoogleIdentityEnvelope: Decodable {
        var subject: String?
        var email: String?
        var displayName: String?
        var firstName: String?
        var lastName: String?
        var photoUrl: String?
    }

    /// `POST /auth/google` — échange le jeton Google contre une session
    /// Duello, exactement comme `verifyGoogleIdToken` (Expo, délai 10 s).
    /// Le serveur contrôle la signature, les audiences, l'émetteur,
    /// l'expiration et l'e-mail vérifié avant d'ouvrir la session ; le
    /// client ne décode jamais le jeton lui-même.
    static func googleAuth(
        idToken: String,
        deviceId: String,
        username: String?
    ) async throws -> (identity: GoogleIdentity, session: SessionPayload) {
        struct Body: Encodable {
            var idToken: String
            var deviceId: String
            var username: String?
        }
        guard !idToken.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw GoogleAuthError.invalidIdentity("Google n'a pas fourni de preuve de connexion.")
        }
        let body = try encodeBody(Body(idToken: idToken, deviceId: deviceId, username: username))

        var request = URLRequest(url: baseURL.appendingPathComponent("auth/google"))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let data: Data
        let http: HTTPURLResponse
        do {
            let (payload, response) = try await URLSession.shared.data(for: request)
            guard let urlResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            data = payload
            http = urlResponse
        } catch let error as URLError where error.code == .timedOut {
            throw GoogleAuthError.network("Le serveur Duello met trop de temps à vérifier Google.")
        } catch {
            throw GoogleAuthError.network("Le serveur Duello est injoignable. Vérifie ta connexion.")
        }

        let envelope = try? decoder.decode(GoogleAuthEnvelope.self, from: data)
        guard (200..<300).contains(http.statusCode) else {
            let serverMessage = envelope?.error?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let message = serverMessage.isEmpty ? "Connexion Google indisponible (\(http.statusCode))." : serverMessage
            throw GoogleAuthError.server(message, status: http.statusCode)
        }
        guard let identityEnvelope = envelope?.identity else {
            if let message = envelope?.error?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                throw GoogleAuthError.server(message, status: http.statusCode)
            }
            throw GoogleAuthError.invalidIdentity("Google n'a pas renvoyé une identité exploitable.")
        }
        let identity = try GoogleIdentity.parse(identityEnvelope)
        guard let session = envelope?.session else {
            throw GoogleAuthError.server("Le serveur n'a pas créé de session Duello.", status: http.statusCode)
        }
        return (identity, session)
    }

    // MARK: Classements

    struct LeaderboardResponse: Decodable {
        var entries: [LeaderboardEntry]?
    }

    /// `GET /leaderboard?subject=…` — classement d'une matière.
    static func subjectLeaderboard(subject: String, token: String?) async throws -> [LeaderboardEntry] {
        let response = try await request(
            LeaderboardResponse.self,
            "leaderboard",
            token: token,
            query: [URLQueryItem(name: "subject", value: subject)]
        )
        return response.entries ?? []
    }

    /// `GET /weekly-xp?subject=…&week=…` — classement hebdo d'une matière.
    static func weeklyXpLeaderboard(subject: String, week: String, token: String?) async throws -> [LeaderboardEntry] {
        let response = try await request(
            LeaderboardResponse.self,
            "weekly-xp",
            token: token,
            query: [
                URLQueryItem(name: "subject", value: subject),
                URLQueryItem(name: "week", value: week),
            ]
        )
        return response.entries ?? []
    }

    // MARK: File d'attente des défis

    struct QueueEnvelope: Decodable {
        var state: String?
        var ticket: String?
        var waitedMs: Double?
        var eloWindow: Int?
        var queued: Int?
        var match: MatchView?
        var error: String?
    }

    /// `POST /queue` — entre dans la file d'attente partagée.
    static func joinQueue(_ entry: QueueRequest, token: String) async throws -> QueueState {
        let body = try encodeBody(entry)
        let envelope = try await request(QueueEnvelope.self, "queue", method: "POST", token: token, body: body)
        return Self.queueState(from: envelope)
    }

    /// `GET /queue?ticket=…` — prend des nouvelles de la file.
    static func pollQueue(ticket: String, token: String) async throws -> QueueState {
        let envelope = try await request(
            QueueEnvelope.self,
            "queue",
            token: token,
            query: [URLQueryItem(name: "ticket", value: ticket)]
        )
        return Self.queueState(from: envelope)
    }

    /// `DELETE /queue?ticket=…` — quitte la file.
    static func leaveQueue(ticket: String, token: String) async {
        _ = try? await request("queue", method: "DELETE", token: token, query: [URLQueryItem(name: "ticket", value: ticket)])
    }

    private static func queueState(from envelope: QueueEnvelope) -> QueueState {
        switch envelope.state {
        case "matched":
            if let ticket = envelope.ticket, let match = envelope.match {
                return .matched(ticket: ticket, match: match)
            }
            return .expired
        case "waiting":
            if let ticket = envelope.ticket {
                return .waiting(
                    ticket: ticket,
                    waitedMs: envelope.waitedMs ?? 0,
                    eloWindow: envelope.eloWindow ?? 80,
                    queued: envelope.queued ?? 1
                )
            }
            return .expired
        default:
            return .expired
        }
    }

    // MARK: Résultat d'un défi

    /// Copie adverse dévoilée après la remise des deux copies. Décodée
    /// souplement : le serveur peut l'envoyer incomplète selon l'état du défi.
    struct OpponentSubmission: Decodable {
        var score: Int?
        var note: String?
        var graded: Bool?
        var answers: [String: String]?
    }

    struct DuelResultEnvelope: Decodable {
        var state: String?
        var deadline: Double?
        var opponent: OpponentSubmission?
        var reason: String?
        var before: Int?
        var after: Int?
        var delta: Int?
        var outcome: String?
        var error: String?
    }

    private static func duelResultState(from envelope: DuelResultEnvelope) -> DuelResultState {
        switch envelope.state {
        case "waiting":
            return .waiting(deadline: envelope.deadline ?? 0)
        case "settled":
            let opponent: DuelSubmission? = envelope.opponent.map { submission in
                DuelSubmission(
                    score: submission.score ?? 0,
                    note: submission.note ?? "",
                    graded: submission.graded ?? false,
                    answers: submission.answers ?? [:]
                )
            }
            let elo: EloResult? = {
                guard let before = envelope.before, let after = envelope.after,
                      let delta = envelope.delta, let outcome = envelope.outcome else { return nil }
                return EloResult(before: before, after: after, delta: delta, outcome: outcome)
            }()
            return .settled(opponent: opponent, reason: envelope.reason, elo: elo)
        default:
            return .expired
        }
    }

    /// `POST /duel` — dépose la note de sa copie.
    static func submitDuelGrade(matchId: String, userId: String, grade: DuelSubmission, token: String) async throws -> DuelResultState {
        struct Body: Encodable {
            var matchId: String
            var userId: String
            var score: Int
            var note: String
            var graded: Bool
            var answers: [String: String]
        }
        let body = try encodeBody(Body(
            matchId: matchId,
            userId: userId,
            score: grade.score,
            note: grade.note,
            graded: grade.graded,
            answers: grade.answers
        ))
        let envelope = try await request(DuelResultEnvelope.self, "duel", method: "POST", token: token, body: body)
        return duelResultState(from: envelope)
    }

    /// `GET /duel?match=…&user=…` — prend des nouvelles du résultat.
    static func pollDuelResult(matchId: String, userId: String, token: String) async throws -> DuelResultState {
        let envelope = try await request(
            DuelResultEnvelope.self,
            "duel",
            token: token,
            query: [
                URLQueryItem(name: "match", value: matchId),
                URLQueryItem(name: "user", value: userId),
            ]
        )
        return duelResultState(from: envelope)
    }

    /// `DELETE /duel?match=…&user=…` — abandonne le défi.
    static func abandonDuel(matchId: String, userId: String, token: String) async {
        _ = try? await request(
            "duel",
            method: "DELETE",
            token: token,
            query: [
                URLQueryItem(name: "match", value: matchId),
                URLQueryItem(name: "user", value: userId),
            ]
        )
    }

    // MARK: Contenu servi (énoncés réels)

    /// Descripteur d'une banque servie (`ContentBundleDescriptor`).
    struct ContentBundleDescriptor: Decodable {
        var id: String
        var file: String
        var size: Int
        var sha256: String
        var count: Int
    }

    /// Descripteur d'un chapitre au sein du manifeste.
    struct ContentChapterDescriptor: Decodable {
        var bundleId: String
        var chapterId: String
        var file: String
        var size: Int
        var sha256: String
        var count: Int
    }

    /// Manifeste du contenu servi (`GET /content/manifest.json`).
    struct ContentManifest: Decodable {
        var version: Int
        var publishedAt: String?
        var bundles: [ContentBundleDescriptor]?
        var chapters: [ContentChapterDescriptor]?
    }

    /// `GET /content/manifest.json` — descripteurs des banques servies.
    static func contentManifest() async throws -> ContentManifest {
        try await request(ContentManifest.self, "content/manifest.json")
    }

    /// Énoncé réel servi par le serveur (`ExerciseSeedShape` de
    /// `content/servedBank.ts`). Seuls les champs lus par le joueur sont
    /// décodés ; `source` et les liens d'attribution restent côté écran web.
    struct ChapterExercise: Decodable {
        var key: String
        var chapterId: String
        var title: String
        var difficulty: Int?
        var statement: String
        var solution: String?
    }

    /// `GET /content/<chemin du descripteur>` — énoncés d'un chapitre.
    static func chapterExercises(_ descriptor: ContentChapterDescriptor) async throws -> [ChapterExercise] {
        let data = try await request("content/" + descriptor.file)
        return try decoder.decode([ChapterExercise].self, from: data)
    }

    // MARK: Correcteur IA (relais)

    enum GradingError: Error {
        /// Le quota serveur est un refus produit, jamais une panne à masquer
        /// localement. `nextFreeAt` arrive en millisecondes.
        case quota(String, nextFreeAt: Double?)
        case refused(String)
    }

    struct RelayGradingResponse: Decodable {
        var score: Double?
        var note: String?
        var error: String?
        var nextFreeAt: Double?
    }

    /// `POST /relay` avec `action: "grade-duel-copy"` — fait noter une copie
    /// par l'IA, exactement comme `gradeCopyWithAi` (Expo). Le jeton de
    /// session Duello authentifie l'appel et sert le quota ; l'application
    /// n'appelle jamais OpenAI ni Anthropic directement.
    static func gradeCopyWithAi(
        subject: String,
        prompt: String,
        solution: String?,
        copy: String,
        durationMinutes: Int,
        operationKey: String,
        token: String
    ) async throws -> ProductionAssessment {
        struct Body: Encodable {
            var action: String
            var subject: String
            var prompt: String
            var solution: String?
            var copy: String
            var durationMinutes: Int
            var operationKey: String
        }
        let body = try encodeBody(Body(
            action: "grade-duel-copy",
            subject: subject,
            prompt: prompt,
            solution: solution,
            copy: copy,
            durationMinutes: durationMinutes,
            operationKey: operationKey
        ))

        var request = URLRequest(url: baseURL.appendingPathComponent("relay"))
        request.httpMethod = "POST"
        // Aucun minuteur applicatif : l'effort maximal du correcteur peut
        // légitimement dépasser trente secondes.
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DirectoryError(message: "Le correcteur est injoignable.")
        }
        let payload = try? decoder.decode(RelayGradingResponse.self, from: data)
        if http.statusCode == 402 {
            throw GradingError.quota(
                payload?.error ?? "Quota de défis épuisé",
                nextFreeAt: payload?.nextFreeAt
            )
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw GradingError.refused("Accès à la notation refusé")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw DirectoryError(
                message: payload?.error ?? "Notation indisponible (\(http.statusCode)).",
                status: http.statusCode
            )
        }
        let note = (payload?.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty, let score = payload?.score, score.isFinite else {
            throw DirectoryError(message: "Réponse inattendue du correcteur.")
        }
        return ProductionAssessment(score: min(100, max(0, Int(score.rounded()))), note: note)
    }
}
