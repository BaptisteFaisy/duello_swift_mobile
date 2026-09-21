//
//  SocialInviteModels.swift
//  Duello
//
//  Lot « Social » — types partagés par l'invitation à un défi : profil public
//  de l'annuaire, chapitre jouable, canaux de partage et textes d'invitation.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/data/socialProfiles.ts        (SocialProfile, PublicProfileDetails)
//    - src/utils/subjectProgress.ts      (EligibleChallengeChapter)
//    - src/utils/challengeInvites.ts     (challengeInviteMessage, inviteSubtitle,
//                                         invitedNamesSummary)
//    - src/utils/socialApi.ts            (MAX_SEARCH_CANDIDATES)
//    - src/utils/subjectElo.ts           (INITIAL_SUBJECT_ELO)
//    - src/config/platform.ts            (DUELLO_DOWNLOAD_URL)
//    - src/utils/search.ts               (normalizeSearch)
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

// MARK: - Défi préparé

/// Nature du défi préparé (`challengeKind` de `ChallengeInviteModal.tsx`).
enum SocChallengeKind: String {
    case course
    case exercise

    /// Titre du volet, mot pour mot.
    var title: String {
        switch self {
        case .course: return "Défi-Cours"
        case .exercise: return "Défi-Exercice"
        }
    }

    /// Un Défi-Cours garde des chapitres qui ne sont pas forcément communs :
    /// le volet liste déjà ceux où l'inviteur a des flashcards, l'invité peut
    /// les jouer dès que son programme les contient.
    var requiresCommonChapter: Bool { self != .course }
}

/// Chapitre jouable d'un défi (`EligibleChallengeChapter` de
/// `utils/subjectProgress.ts`).
struct SocChallengeChapter: Identifiable, Hashable {
    /// Clé complète `<année>:<matière>:<chapitre>`, exactement celle que le
    /// serveur attend pour apparier les deux programmes.
    let key: String
    /// Identifiant du chapitre dans le programme.
    let id: String
    let name: String
    /// Année du programme : 1 ou 2 (`toProgramYear` de `data/tracks.ts`).
    let year: Int
}

// MARK: - Profil public

/// Profil public d'un membre de l'annuaire (`SocialProfile` de
/// `data/socialProfiles.ts`), réduit aux champs que l'invitation exploite.
struct SocSocialProfile: Identifiable, Hashable, Decodable {
    let id: String
    let displayName: String
    /// Filière publiée (`PrepTrack`), comparée telle quelle à celle du joueur.
    let track: String
    /// Année publiée (« 1re année », « 2e année »).
    let year: String
    /// Photo publiée, `nil` quand le profil n'en a pas.
    let photoUri: String?
    /// Fiche publique ; un profil privé reste invitable, il est seulement
    /// signalé par un cadenas dans la liste. La recherche d'annuaire force la
    /// valeur à vrai, comme `searchSocialProfiles` côté Expo.
    var isPublic: Bool
    /// Abonnement au moment de la dernière publication : absent sur un profil
    /// publié par une ancienne version, traité comme « non abonné ».
    let isPremium: Bool
    /// Spécialité publiée (`details.specialty`), vide si elle est absente.
    let specialty: String
    /// Elo global publié (`details.elo.overall.current`), `nil` s'il est absent.
    let elo: Double?

    enum CodingKeys: String, CodingKey {
        case id, displayName, track, year, photoUri, isPublic, isPremium, details
    }

    enum DetailsKeys: String, CodingKey {
        case specialty, elo
    }

    enum EloKeys: String, CodingKey {
        case overall
    }

    enum OverallKeys: String, CodingKey {
        case current
    }

    /// Décodage tolérant, comme `Models.swift` : le serveur omet parfois un
    /// champ, et une ancienne version ne publie ni spécialité ni Elo.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? ""
        displayName = (try? container.decode(String.self, forKey: .displayName)) ?? ""
        track = (try? container.decode(String.self, forKey: .track)) ?? ""
        year = (try? container.decode(String.self, forKey: .year)) ?? ""
        photoUri = try? container.decodeIfPresent(String.self, forKey: .photoUri)
        isPublic = (try? container.decode(Bool.self, forKey: .isPublic)) ?? false
        isPremium = (try? container.decode(Bool.self, forKey: .isPremium)) ?? false
        specialty = SocSocialProfile.decodeSpecialty(container)
        elo = SocSocialProfile.decodeElo(container)
    }

    /// Construction directe : tests, aperçus, et profil choisi depuis sa fiche.
    init(
        id: String,
        displayName: String,
        track: String = "",
        year: String = "",
        photoUri: String? = nil,
        isPublic: Bool = true,
        isPremium: Bool = false,
        specialty: String = "",
        elo: Double? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.track = track
        self.year = year
        self.photoUri = photoUri
        self.isPublic = isPublic
        self.isPremium = isPremium
        self.specialty = specialty
        self.elo = elo
    }

    /// `details.specialty`, ou une chaîne vide pour un profil ancien.
    private static func decodeSpecialty(_ container: KeyedDecodingContainer<CodingKeys>) -> String {
        guard let details = try? container.nestedContainer(keyedBy: DetailsKeys.self, forKey: .details) else {
            return ""
        }
        return (try? details.decodeIfPresent(String.self, forKey: .specialty)) ?? ""
    }

    /// `details.elo.overall.current`, ou `nil` quand l'Elo n'est pas publié.
    private static func decodeElo(_ container: KeyedDecodingContainer<CodingKeys>) -> Double? {
        guard let details = try? container.nestedContainer(keyedBy: DetailsKeys.self, forKey: .details),
              let elo = try? details.nestedContainer(keyedBy: EloKeys.self, forKey: .elo),
              let overall = try? elo.nestedContainer(keyedBy: OverallKeys.self, forKey: .overall)
        else { return nil }
        return try? overall.decodeIfPresent(Double.self, forKey: .current)
    }
}

// MARK: - Programme des défis

/// Programme d'un défi (`getChallengeTrackSubjects` de `data/tracks.ts`) :
/// seules les mathématiques existent en défis, et les chapitres d'informatique
/// sont écartés — le même filtre que `DuelloExerciseCatalog.forProfile`.
enum SocChallengeProgram {
    /// Identifiant de la matière des défis (`subject.id === 'maths'`).
    static let mathsId = "maths"

    /// Vrai pour un chapitre d'informatique : le domaine vaut « informatique »
    /// (le catalogue Swift le porte capitalisé) ou l'identifiant commence par
    /// `python-`.
    static func isInformatique(_ chapter: TrackChapter) -> Bool {
        if chapter.id.hasPrefix("python-") { return true }
        return (chapter.domain ?? "").lowercased() == "informatique"
    }
}

// MARK: - Canaux de partage

/// Canaux de partage proposés pour un ami qui n'a pas encore de compte
/// (`openShareChannel` de `ChallengeInviteModal.tsx`) : Message, WhatsApp,
/// Instagram.
enum SocShareChannel: String, CaseIterable, Identifiable {
    case sms
    case whatsapp
    case instagram

    var id: String { rawValue }

    /// Libellé du menu, mot pour mot.
    var label: String {
        switch self {
        case .sms: return "Message"
        case .whatsapp: return "WhatsApp"
        case .instagram: return "Instagram"
        }
    }

    /// Icône SF Symbol du menu : les icônes Ionicons d'Expo n'existent pas ici,
    /// le libellé reste seul porteur du sens.
    var icon: String {
        switch self {
        case .sms: return "message"
        case .whatsapp: return "phone.bubble.left"
        case .instagram: return "camera"
        }
    }

    /// Échec d'ouverture, mot pour mot du message Expo.
    var failureMessage: String {
        switch self {
        case .instagram: return "Le message a été copié. Ouvre Instagram pour le partager."
        case .sms, .whatsapp: return "Impossible d’ouvrir \(label) sur cet appareil."
        }
    }

    /// Adresse ouverte par le canal, reprise de `Linking.openURL`.
    ///
    /// Limite assumée : `sms:` n'accepte plus de corps prérempli depuis iOS 8
    /// (`SMS.sendSMSAsync` n'a pas d'équivalent par URL). Le message est donc
    /// copié dans le presse-papiers avant l'ouverture, comme le fait Instagram
    /// côté Expo — l'appelant en informe la personne par `failureMessage` si
    /// l'ouverture échoue.
    func url(message: String) -> URL? {
        switch self {
        case .sms:
            return URL(string: "sms:")
        case .whatsapp:
            // `encodeURIComponent` d'Expo : la valeur est encodée en entier,
            // aucun caractère réservé ne peut casser le message.
            let encoded = message.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            return URL(string: "whatsapp://send?text=\(encoded)")
        case .instagram:
            return URL(string: "https://www.instagram.com/direct/inbox/")
        }
    }
}

// MARK: - Textes de l'invitation

/// Textes et adresses de l'invitation (`utils/challengeInvites.ts`,
/// `config/platform.ts`).
enum SocInviteCopy {
    /// `DUELLO_DOWNLOAD_URL` de `config/platform.ts` : la production publie
    /// `extra.downloadUrl = apiUrl + "/download"`, la même origine que
    /// `DuelloAPI.baseURL` — jamais recopiée en dur.
    static var downloadURL: String {
        DuelloAPI.baseURL.appendingPathComponent("download").absoluteString
    }

    /// Annuaire injoignable : ce n'est pas la même chose qu'un annuaire vide.
    static let directoryUnreachable = "Annuaire injoignable"

    /// Message envoyé par la feuille de partage, avec le lien stable dans le
    /// corps (`challengeInviteMessage`).
    static func inviteMessage(downloadURL: String = SocInviteCopy.downloadURL) -> String {
        [
            "Viens me défier sur un exo de maths, 20 minutes chrono, sur Duello !",
            "Télécharge Duello ici : \(downloadURL)",
        ].joined(separator: "\n")
    }

    /// Programme, chapitres communs et Elo classé du profil (`inviteSubtitle`).
    /// L'année, la filière et la spécialité n'apparaissent que si le profil les
    /// publie : un segment vide est omis plutôt qu'affiché en blanc.
    static func subtitle(_ member: SocSocialProfile, commonChapterCount: Int) -> String {
        let elo = member.elo
            .flatMap { $0.isFinite ? $0 : nil }
            .map { Int(max(0, $0.rounded())) }
            ?? SocChallengeInvites.initialSubjectElo
        let count = max(0, commonChapterCount)
        let parts = [
            member.year,
            member.track,
            SocChallengeInvites.inviteSpecialty(member),
            "\(count) chapitre\(count > 1 ? "s" : "") en commun",
            "\(elo) Elo",
        ]
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Récapitulatif des personnes invitées (`invitedNamesSummary`).
    /// Au-delà de deux noms, la phrase compte le reste plutôt que de s'allonger.
    static func invitedNamesSummary(_ names: [String]) -> String {
        let clean = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard clean.count > 1 else { return clean.first ?? "" }
        if clean.count == 2 { return "\(clean[0]) et \(clean[1])" }
        let others = clean.count - 2
        return "\(clean[0]), \(clean[1]) et \(others) autre\(others > 1 ? "s" : "")"
    }
}

// MARK: - Recherche insensible aux accents

extension String {
    /// Normalisation de recherche (`normalizeSearch` de `utils/search.ts`) :
    /// minuscules, sans accents. Elle sert à la pertinence des résultats et au
    /// filtre des chapitres, exactement comme côté Expo.
    var socSearchNormalized: String {
        folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
