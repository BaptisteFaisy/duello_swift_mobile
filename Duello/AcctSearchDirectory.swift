//
//  AcctSearchDirectory.swift
//  Duello
//
//  Lot « AcctSearch » (10-D) — annuaire de recherche du compte : profil public
//  lu dans l'annuaire, client réseau local, cache paginé et classement des
//  résultats.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx  (classement de `searchResults`,
//                                      loadMoreDirectoryProfiles)
//    - src/utils/socialApi.ts         (searchSocialProfiles,
//                                      browseSocialProfiles,
//                                      browseMoreSocialProfiles,
//                                      cachedBrowseSocialProfiles,
//                                      hasMoreBrowseSocialProfiles,
//                                      prefetchBrowseSocialProfiles,
//                                      fetchSocialProfilesByIds,
//                                      MAX_SEARCH_PROFILES, MAX_PROFILE_IDS,
//                                      DIRECTORY_BROWSE_PAGE_SIZE,
//                                      DIRECTORY_BROWSE_REFRESH_MS)
//    - src/utils/search.ts            (searchRank, compareSearchLabels)
//
//  `DuelloAPI` n'expose pas ces points d'entrée : le client reste local à ce
//  lot et réutilise le relais (`DuelloAPI.request`) sur `profiles`, comme
//  `SocInviteDirectory` — `DuelloAPI.swift` n'est jamais modifié.
//
//  Les seuils de la recherche (`SEARCH_VISIBLE_RESULT_COUNT`, `SEARCH_RESULT_HEIGHT`,
//  `SEARCH_DEBOUNCE_MS`) sont ceux déjà figés par `AcctSearchConstants.swift`
//  (lot « annuaire ») : ce fichier ne les redéfinit pas.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import CoreGraphics

// MARK: - Réglages et textes

/// Réglages de l'annuaire que `AcctSearchConstants` ne porte pas : plafonds
/// d'`utils/socialApi.ts` et libellés d'`AccountScreen.tsx`.
enum AcctSearchSettings {
    /// Frappe laissée au clavier avant d'interroger l'annuaire
    /// (`SEARCH_DEBOUNCE_MS`), exprimée pour `Task.sleep`.
    static let debounceNanoseconds = UInt64(AcctSearchConstants.debounceSeconds * 1_000_000_000)
    /// Profils montrés pour une recherche (`MAX_SEARCH_PROFILES`).
    static let searchMaxResults = 3
    /// Profils relus d'un coup par identifiant (`MAX_PROFILE_IDS`).
    static let maxProfileIds = 60
    /// Taille d'une page alphabétique (`DIRECTORY_BROWSE_PAGE_SIZE`).
    static let browsePageSize = 20
    /// Ancienneté tolérée avant de rafraîchir le cache
    /// (`DIRECTORY_BROWSE_REFRESH_MS`).
    static let browseRefreshSeconds: TimeInterval = 60
    /// Délai entre deux relectures de la fiche ouverte (`30_000` d'Expo).
    static let selectedProfileRefreshNanoseconds: UInt64 = 30_000_000_000
    /// Invite du champ (`placeholder` d'Expo).
    static let placeholder = "Nom, filière, spécialité, Elo ou XP…"
    /// Annuaire injoignable : ce n'est pas la même chose qu'un annuaire vide.
    static let unreachable = "Annuaire injoignable"
}

// MARK: - État de la fiche ouverte

/// État de la fiche publique ouverte (`selectedProfileState` d'`AccountScreen`).
enum AcctSearchProfileState: Equatable {
    case idle
    case loading
    case refreshing
    case failed
}

// MARK: - Profil de l'annuaire

/// Profil public de l'annuaire, tel que la recherche du compte l'affiche.
///
/// **Compose** `SocSocialProfile` (lot « Social », portage de `SocialProfile`)
/// plutôt que de le redéfinir : son décodage tolérant porte toute l'identité
/// (pseudo, photo, filière, année, spécialité, Elo, abonnement). Ce lot ajoute
/// seulement les trois champs que la ligne d'annuaire du compte affiche en plus
/// — `className`, `prepName` et les XP publiés (`performance.xp`).
struct AcctSearchMember: Identifiable, Hashable, Decodable {
    /// Identité publiée, décodée par `SocSocialProfile`.
    let profile: SocSocialProfile
    /// Classe de prépa publiée, vide si elle est absente.
    let className: String
    /// Nom de la prépa publiée, vide s'il est absent.
    let prepName: String
    /// XP publiés (`performance.xp`), zéro s'ils sont absents.
    let xp: Double

    var id: String { profile.id }
    var displayName: String { profile.displayName }
    var photoUri: String? { profile.photoUri }
    var track: String { profile.track }
    var year: String { profile.year }
    var isPremium: Bool { profile.isPremium }
    var isPublic: Bool { profile.isPublic }
    /// Spécialité publiée (`details.specialty`), vide si elle est absente.
    var specialty: String { profile.specialty }
    /// Elo global publié (`details.elo.overall.current`), `nil` s'il est absent.
    var elo: Double? { profile.elo }

    enum CodingKeys: String, CodingKey { case className, prepName, performance }
    enum PerformanceKeys: String, CodingKey { case xp }

    init(profile: SocSocialProfile, className: String = "", prepName: String = "", xp: Double = 0) {
        self.profile = profile
        self.className = className
        self.prepName = prepName
        self.xp = xp
    }

    /// Décodage tolérant : `SocSocialProfile` lit l'identité, ce type complète.
    init(from decoder: Decoder) throws {
        profile = try SocSocialProfile(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        className = (try? container.decode(String.self, forKey: .className)) ?? ""
        prepName = (try? container.decode(String.self, forKey: .prepName)) ?? ""
        if let performance = try? container.nestedContainer(keyedBy: PerformanceKeys.self, forKey: .performance) {
            xp = (try? performance.decode(Double.self, forKey: .xp)) ?? 0
        } else {
            xp = 0
        }
    }

    /// Profil publié : l'annuaire ne renvoie que des comptes visibles
    /// (`isPublic: true` forcé côté Expo sur chaque lecture).
    var published: AcctSearchMember {
        var copy = profile
        copy.isPublic = true
        return AcctSearchMember(profile: copy, className: className, prepName: prepName, xp: xp)
    }
}

// MARK: - Client de l'annuaire

/// Page alphabétique de l'annuaire (`DirectoryBrowsePage` de `socialApi.ts`).
struct AcctSearchDirectoryPage {
    var profiles: [AcctSearchMember]
    var nextOffset: Int?
}

/// Client local de l'annuaire (`searchSocialProfiles`, `browseSocialProfiles`,
/// `browseMoreSocialProfiles`, `fetchSocialProfilesByIds`).
enum AcctSearchDirectory {
    /// `GET /profiles?q=…` : le serveur classe par pertinence, on ne garde que
    /// les premiers (`MAX_SEARCH_PROFILES`).
    static func search(
        _ query: String,
        token: String?,
        limit: Int = AcctSearchSettings.searchMaxResults
    ) async throws -> [AcctSearchMember] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Une seule lettre suffit pour chercher : elle est traitée comme une initiale.
        guard !normalized.isEmpty else { return [] }

        let data = try await DuelloAPI.request(
            "/profiles",
            method: "GET",
            token: token,
            query: [URLQueryItem(name: "q", value: normalized)]
        )
        let envelope = try DuelloAPI.decoder.decode(AcctSearchProfilesEnvelope.self, from: data)
        return Array(envelope.published.prefix(max(0, limit)))
    }

    /// `GET /profiles?ids=…` : relit des profils par identifiant
    /// (`fetchSocialProfilesByIds`), plafonné à `MAX_PROFILE_IDS`.
    static func profilesByIds(_ ids: [String], token: String?) async throws -> [AcctSearchMember] {
        let wanted = Array(ids.filter { !$0.isEmpty }.prefix(AcctSearchSettings.maxProfileIds))
        guard !wanted.isEmpty else { return [] }

        let data = try await DuelloAPI.request(
            "/profiles",
            method: "GET",
            token: token,
            query: [URLQueryItem(name: "ids", value: wanted.joined(separator: ","))]
        )
        let envelope = try DuelloAPI.decoder.decode(AcctSearchProfilesEnvelope.self, from: data)
        return envelope.published
    }

    /// `GET /profiles?browse=1&offset=…&limit=…` : page alphabétique
    /// (`loadBrowseSocialProfilesPage`). Un serveur ancien qui ignore `browse`
    /// est rattrapé par la requête `q=%`.
    static func browsePage(offset: Int, token: String?) async throws -> AcctSearchDirectoryPage {
        let data = try await DuelloAPI.request(
            "/profiles",
            method: "GET",
            token: token,
            query: [
                URLQueryItem(name: "browse", value: "1"),
                URLQueryItem(name: "offset", value: String(max(0, offset))),
                URLQueryItem(name: "limit", value: String(AcctSearchSettings.browsePageSize)),
            ]
        )
        let envelope = try DuelloAPI.decoder.decode(AcctSearchProfilesEnvelope.self, from: data)
        if envelope.browse == true {
            // Le serveur peut répéter sa première page : `nextOffset` doit
            // progresser, sinon on s'arrête.
            let next = envelope.nextOffset.flatMap { $0 > offset ? $0 : nil }
            return AcctSearchDirectoryPage(profiles: envelope.published, nextOffset: next)
        }
        if offset > 0 { return AcctSearchDirectoryPage(profiles: [], nextOffset: nil) }

        // Compatibilité avec un ancien serveur qui ne connaît pas `browse`.
        let legacy = try await DuelloAPI.request(
            "/profiles",
            method: "GET",
            token: token,
            query: [URLQueryItem(name: "q", value: "%")]
        )
        let legacyEnvelope = try DuelloAPI.decoder.decode(AcctSearchProfilesEnvelope.self, from: legacy)
        return AcctSearchDirectoryPage(profiles: legacyEnvelope.published, nextOffset: nil)
    }
}

/// Enveloppe `{ profiles, browse?, nextOffset? }` de l'annuaire.
private struct AcctSearchProfilesEnvelope: Decodable {
    var profiles: [AcctSearchMember]
    var browse: Bool?
    var nextOffset: Int?

    enum CodingKeys: String, CodingKey { case profiles, browse, nextOffset }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profiles = (try? container.decodeIfPresent([AcctSearchMember].self, forKey: .profiles)) ?? []
        browse = try? container.decodeIfPresent(Bool.self, forKey: .browse)
        nextOffset = try? container.decodeIfPresent(Int.self, forKey: .nextOffset)
    }

    /// Chaque profil lu dans l'annuaire est publié, comme
    /// `sanitizeSocialProfiles` + `isPublic: true` côté Expo.
    var published: [AcctSearchMember] { profiles.map(\.published) }
}

// MARK: - Cache de la page alphabétique

/// Cache partagé de la page alphabétique (`directoryBrowseCache` d'Expo) : une
/// copie ancienne reste affichable pendant sa relève, et une seule requête de
/// préchargement court à la fois.
@MainActor
final class AcctSearchBrowseCache {
    /// Instance partagée : le préchargement profite à tous les écrans.
    static let shared = AcctSearchBrowseCache()

    private var profiles: [AcctSearchMember] = []
    private var nextOffset: Int?
    private var refreshedAt: Date?
    private var loadingFirst = false
    private var loadingMore = false

    /// Dernière page disponible immédiatement, `nil` tant qu'aucune n'a abouti.
    var cached: [AcctSearchMember]? { refreshedAt == nil ? nil : profiles }
    /// Vrai tant que le serveur annonce une page suivante.
    var hasMore: Bool { nextOffset != nil }

    /// Précharge une seule fois l'annuaire (`prefetchBrowseSocialProfiles`).
    func prefetch(token: String?) async throws -> [AcctSearchMember] {
        if let refreshedAt,
           Date().timeIntervalSince(refreshedAt) < AcctSearchSettings.browseRefreshSeconds {
            return profiles
        }
        if loadingFirst { return profiles }
        loadingFirst = true
        defer { loadingFirst = false }

        do {
            let page = try await AcctSearchDirectory.browsePage(offset: 0, token: token)
            profiles = page.profiles
            nextOffset = page.nextOffset
            refreshedAt = Date()
            return profiles
        } catch {
            // Une copie ancienne reste affichable si l'actualisation échoue.
            if refreshedAt != nil { return profiles }
            throw error
        }
    }

    /// Premiers pseudos de l'annuaire, demandés sans attendre une saisie
    /// (`browseSocialProfiles`) : le résultat visible reste instantané.
    func browse(token: String?) async throws -> [AcctSearchMember] {
        if let cached {
            Task { _ = try? await prefetch(token: token) }
            return cached
        }
        return try await prefetch(token: token)
    }

    /// Ajoute la page alphabétique suivante au cache partagé
    /// (`browseMoreSocialProfiles`).
    func browseMore(token: String?) async throws -> [AcctSearchMember] {
        if refreshedAt == nil { _ = try? await prefetch(token: token) }
        guard let requested = nextOffset, !loadingMore else { return profiles }
        loadingMore = true
        defer { loadingMore = false }

        let page = try await AcctSearchDirectory.browsePage(offset: requested, token: token)
        // Une page demandée puis dépassée est ignorée, comme côté Expo.
        guard nextOffset == requested else { return profiles }

        var merged: [String: AcctSearchMember] = [:]
        for member in profiles { merged[member.id] = member }
        for member in page.profiles { merged[member.id] = member }
        let grew = merged.count > profiles.count
        profiles = Array(merged.values)
        // Un serveur ancien peut ignorer l'offset et répéter sa première page :
        // on s'arrête au lieu de relancer indéfiniment la requête.
        nextOffset = grew ? page.nextOffset : nil
        refreshedAt = Date()
        return profiles
    }
}

// MARK: - Classement des résultats

/// Classement des résultats (`searchRank`, `compareSearchLabels` de
/// `utils/search.ts`), insensible à la casse et aux accents.
enum AcctSearchRanking {
    /// Pertinence d'un résultat : plus la valeur est basse, plus il remonte.
    /// Un nom qui commence par la recherche passe avant une correspondance au
    /// milieu.
    static func rank(primary: String, query: String) -> Int {
        let terms = query.socSearchNormalized
            .split(whereSeparator: { " \t\n,.'-".contains($0) })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard let first = terms.first else { return 3 }

        let normalized = primary.socSearchNormalized
        if normalized.hasPrefix(first) { return 0 }
        // Un mot du nom qui commence par la recherche : « Bernard » pour « ber ».
        let words = normalized
            .split(whereSeparator: { " \t-".contains($0) })
            .map(String.init)
        if words.contains(where: { $0.hasPrefix(first) }) { return 1 }
        return normalized.contains(first) ? 2 : 3
    }

    /// Ordre alphabétique stable des pseudos (`compareSearchLabels`).
    static func compareLabels(_ first: String, _ second: String) -> ComparisonResult {
        let locale = Locale(identifier: "fr_FR")
        let primary = first.socSearchNormalized
            .compare(second.socSearchNormalized, options: [], range: nil, locale: locale)
        if primary != .orderedSame { return primary }
        return first.compare(second, options: [], range: nil, locale: locale)
    }
}
