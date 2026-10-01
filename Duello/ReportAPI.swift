//
//  ReportAPI.swift
//  Duello
//
//  Lot « Report » — client local de publication du profil public et helpers de
//  nettoyage / fusion des profils de l'annuaire.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/socialApi.ts             (publicProfile, publishSocialProfile,
//                                          publicProfileId, DirectoryPublication)
//    - src/utils/socialProfileSanitize.ts (sanitizeSocialProfile,
//                                          sanitizeSocialProfiles,
//                                          FALLBACK_PUBLIC_PERFORMANCE)
//    - src/utils/knownSocialProfiles.ts   (mergeKnownSocialProfiles)
//    - src/utils/publicProfileSnapshot.ts (PublicProfileSnapshot — forme publiée)
//
//  L'annuaire social n'est pas exposé par `DuelloAPI` : ce client local
//  réutilise le relais (`DuelloAPI.request`) sur `profiles`, comme
//  `ExGLeaderboardClient` sur `exercise-leaderboard`. `DuelloAPI.swift` n'est
//  pas modifié.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Corps publié sur `PUT /profiles` (`publicProfile` de `utils/socialApi.ts`).
struct ReportPublicProfilePayload: Encodable {
    var id: String
    var displayName: String
    var prepName: String
    var className: String
    var track: String
    var year: String
    var targetSchool: String
    var photoUri: String?
    var isPublic: Bool = true
    var isPremium: Bool
    var schedule: [String] = []
    var performance: ReportPublicPerformance
    /// Journal d'attribution XP par sujet (`xpAwards`), toujours vide côté
    /// téléphone : le serveur le normalise dans `xp_events` puis le retire du
    /// profil consultable (voir `publicProfile` de `utils/socialApi.ts`).
    var xpAwards: [String] = []
    var details: ReportPublicProfileDetails?
}

/// Détails publics d'identité publiés (`PublicProfileDetails` de
/// `data/socialProfiles.ts:33-73`).
///
/// Toute la forme de l'instantané est reproduite : identité, activité, séries
/// d'Elo (globale et par matière), séries temporelles, succès par matière,
/// exercices très durs réussis, série d'XP et dernières notes de corrections.
/// `weeklyXp` (classement hebdo par matière) reste absent : aucune source locale
/// ne l'alimente encore.
struct ReportPublicProfileDetails: Encodable {
    var currentTrack: String
    var specialty: String
    var personalGoal: String
    var activity: ReportPublicActivity
    var elo: ReportPublicEloDetails
    var timeSeries: ReportPublicTimeSeries
    var subjectSuccesses: [ReportPublicSubjectSuccess]
    var veryHardExerciseSuccessIds: [String]
    var xpSeries: [ReportPublicXpPoint]?
    /// `correctionGrades` : dernières notes de corrections, pour l'historique
    /// des visiteurs (`PublicProfileDetails.correctionGrades`).
    var correctionGrades: [CorrectionGradeEntry]?
}

/// `PublicProfileDetails.activity` : compteurs d'entraînement publiés.
struct ReportPublicActivity: Encodable {
    var challengesCompleted: Int
    var exercisesCompleted: Int
    var exerciseMinutes: Int
}

/// `PublicProfileDetails.elo` : série globale et séries par matière.
struct ReportPublicEloDetails: Encodable {
    var overall: ReportPublicEloSeries
    var subjects: [ReportPublicEloSeries]
}

/// `PublicEloSeries` : étiquette, cote courante (`null` si aucune matière jouée)
/// et points de la courbe.
struct ReportPublicEloSeries: Encodable {
    var label: String
    var current: Int?
    var points: [ReportPublicEloPoint]
}

/// `EloSeriesPoint` : cote à un instant (millisecondes depuis l'époque Unix).
struct ReportPublicEloPoint: Encodable {
    var elo: Int
    var at: Double
}

/// `PublicProfileDetails.timeSeries` : colonnes jour / semaine / mois.
struct ReportPublicTimeSeries: Encodable {
    var day: [ReportPublicTimeBucket]
    var week: [ReportPublicTimeBucket]
    var month: [ReportPublicTimeBucket]
}

/// `SubjectTimeBucket` : une colonne de la série temporelle.
struct ReportPublicTimeBucket: Encodable {
    var start: Double
    var minutesBySubject: [String: Int]
    var minutes: Int
}

/// `subjectSuccesses` : réussites par matière (`{ subject, succeeded, total }`).
struct ReportPublicSubjectSuccess: Encodable {
    var subject: String
    var succeeded: Int
    var total: Int
}

/// `XpSeriesPoint` : total d'XP atteint à un instant.
struct ReportPublicXpPoint: Encodable {
    var xp: Double
    var at: Double
}

/// Publication et nettoyage des profils de l'annuaire
/// (`publishSocialProfile`, `sanitizeSocialProfile`, `mergeKnownSocialProfiles`).
enum ReportPublicProfile {

    // MARK: Identité

    /// Identifiant public d'un compte (`publicProfileId`), délégué au socle.
    static func publicProfileId(email: String) -> String {
        DuelloAPI.publicProfileId(email: email)
    }

    // MARK: Nettoyage et fusion

    /// Répond un profil complet (`sanitizeSocialProfile`) : un profil publié
    /// par une ancienne version arrive sans statistiques exploitables.
    ///
    /// Le décodage de `ReportPublicPerformance` comble déjà les champs absents
    /// par le repli ; il ne reste qu'à garantir la présence du bloc.
    static func sanitize(_ profile: ReportSocialProfile) -> ReportSocialProfile {
        var cleaned = profile
        if cleaned.performance == nil { cleaned.performance = .fallback }
        return cleaned
    }

    /// `sanitizeSocialProfiles` : applique le repli à toute une liste.
    static func sanitizeAll(_ profiles: [ReportSocialProfile]) -> [ReportSocialProfile] {
        profiles.map(sanitize)
    }

    /// Réunit l'annuaire des abonnés et les lectures directes
    /// (`mergeKnownSocialProfiles`) : l'annuaire gagne en cas de conflit.
    static func mergeKnown(
        directory: [ReportSocialProfile],
        extra: [ReportSocialProfile]
    ) -> [ReportSocialProfile] {
        var merged: [String: ReportSocialProfile] = [:]
        for member in directory { merged[member.id] = member }
        for member in extra where merged[member.id] == nil { merged[member.id] = member }
        return Array(merged.values)
    }

    // MARK: Publication

    /// Construit le corps publié à partir du profil local (`publicProfile`).
    ///
    /// `details` et `xpAwards` viennent de l'instantané public relu par le
    /// publieur (`ReportPublicProfileSnapshot`) : ce constructeur ne fait que
    /// les recopier, il ne les recalcule pas.
    static func payload(
        profile: UserProfile,
        performance: ReportPublicPerformance,
        premium: Bool,
        details: ReportPublicProfileDetails? = nil,
        xpAwards: [String] = []
    ) -> ReportPublicProfilePayload {
        ReportPublicProfilePayload(
            id: publicProfileId(email: profile.email),
            displayName: trimmed(profile.displayName),
            prepName: trimmed(profile.prepName),
            className: trimmed(profile.className),
            track: profile.track,
            year: profile.year,
            targetSchool: trimmed(profile.targetSchool),
            // Seule la miniature JPEG autonome est transmissible : jamais d'URI locale.
            photoUri: PhotoPickUri.publicProfilePhotoUri(profile.photoUri),
            isPremium: premium,
            performance: performance,
            xpAwards: xpAwards,
            details: details
        )
    }

    /// `PUT /profiles` (`publishSocialProfile`) : publie les informations
    /// visibles dans l'annuaire, jamais l'e-mail ni le mot de passe.
    static func publish(
        _ payload: ReportPublicProfilePayload,
        token: String?
    ) async -> ReportDirectoryPublication {
        guard !payload.displayName.isEmpty else { return .incomplete }
        let body: Data
        do { body = try DuelloAPI.encodeBody(payload) }
        catch { return .unreachable(message: "Publication impossible") }

        do {
            let envelope = try await DuelloAPI.request(
                ReportProfileEnvelope.self,
                "profiles",
                method: "PUT",
                token: token,
                body: body
            )
            return .published(at: Date(), profile: envelope.profile.map(sanitize))
        } catch {
            return publicationFailure(error)
        }
    }

    /// Distingue un refus du profil d'une panne (`publishSocialProfile`) : seul
    /// le premier se corrige depuis le téléphone.
    private static func publicationFailure(_ error: Error) -> ReportDirectoryPublication {
        guard let directoryError = error as? DirectoryError else {
            let message = (error as? LocalizedError)?.errorDescription ?? "Publication impossible"
            return .unreachable(message: message)
        }
        let message = directoryError.status == 401
            ? "ta session Duello a expiré ; reconnecte-toi avec Google"
            : directoryError.message
        let isRejection = (directoryError.status ?? 500) < 500
        return isRejection
            ? .rejected(message: message, authenticationRequired: directoryError.status == 401)
            : .unreachable(message: message)
    }

    /// Retire les espaces de bord, comme `profile.prepName.trim()` d'Expo.
    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Réponse de `PUT /profiles` (`{ profile? }`).
private struct ReportProfileEnvelope: Decodable {
    var profile: ReportSocialProfile?
}
