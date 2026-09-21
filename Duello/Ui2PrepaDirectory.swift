//
//  Ui2PrepaDirectory.swift
//  Duello
//
//  Lot 7-F « UI générique » (préfixe `Ui2`).
//
//  Fichier source Expo porté :
//    - src/components/PrepaSearchModal.tsx (référentiel national :
//      `OFFICIAL_CPGE_API`, `OFFICIAL_CPGE_CACHE_KEY`, `OFFICIAL_CPGE_PAGE_SIZE`,
//      `fetchOfficialDirectory`, `parseCachedDirectory`, `normalizeSector`)
//
//  Le modèle `Prepa` et le filtre `searchPrepas` (de `src/data/prepas.ts`) sont
//  déjà portés par le lot « Données d'onboarding » sous `OnbDataPrepas` : ils
//  sont réutilisés tels quels, sans redéfinition. Ce module ne porte donc que le
//  référentiel en ligne (chargement, pagination, cache local), laissé hors du
//  périmètre d'`OnbDataPrepas`.
//
//  Le référentiel CPGE est un service public tiers
//  (data.enseignementsup-recherche.gouv.fr), hors backend Duello : il ne passe
//  pas par `DuelloAPI` (qui vise l'API Duello). Un relais local `URLSession` le
//  reproduit donc, avec cache `UserDefaults` (équivalent d'`AsyncStorage`).
//  Cible iOS 16.
//
import Foundation

/// Référentiel national des CPGE (`PrepaSearchModal.tsx`).
enum Ui2PrepaDirectory {
    /// `OFFICIAL_CPGE_API` de la source.
    static let officialAPI =
        "https://data.enseignementsup-recherche.gouv.fr/api/explore/v2.1/catalog/datasets/fr-esr-effectifs-d-etudiants-inscrits-en-classes-preparatoires-aux-grandes-ecole/records"
    /// `OFFICIAL_CPGE_CACHE_KEY` de la source.
    static let cacheKey = "@prepapp/official-cpge-directory-v1"
    /// `OFFICIAL_CPGE_PAGE_SIZE` de la source.
    static let pageSize = 100

    /// Contenu du cache (`OfficialPrepaCache`).
    struct CachedDirectory {
        let referenceYear: String
        let prepas: [OnbDataPrepas.Prepa]
    }

    /// Lit le cache local (`AsyncStorage.getItem` → `UserDefaults`).
    static func loadCached() -> CachedDirectory? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(CachedDirectoryPayload.self, from: data),
              !decoded.referenceYear.isEmpty, !decoded.prepas.isEmpty
        else { return nil }

        let prepas = decoded.prepas.map {
            OnbDataPrepas.Prepa(id: $0.id, name: $0.name, city: $0.city, country: $0.country, type: $0.type)
        }
        return CachedDirectory(referenceYear: decoded.referenceYear, prepas: prepas)
    }

    /// Écrit le cache local (`AsyncStorage.setItem`).
    static func saveCache(_ directory: CachedDirectory) {
        let payload = CachedDirectoryPayload(
            referenceYear: directory.referenceYear,
            prepas: directory.prepas.map {
                CachedPrepa(id: $0.id, name: $0.name, city: $0.city, country: $0.country, type: $0.type)
            }
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    /// Charge le référentiel national (`fetchOfficialDirectory`).
    static func fetchOfficial() async throws -> CachedDirectory {
        let referenceYear = try await fetchReferenceYear()
        var records: [OfficialRecord] = []
        var offset = 0
        while true {
            let page = try await fetchPage(referenceYear: referenceYear, offset: offset)
            records.append(contentsOf: page)
            if page.count < pageSize { break }
            offset += pageSize
        }

        var unique: [String: OnbDataPrepas.Prepa] = [:]
        for item in records {
            guard let uai = item.uai, !uai.isEmpty,
                  let libelle = item.libelle, !libelle.isEmpty,
                  let city = item.comNom, !city.isEmpty
            else { continue }
            let id = uai.uppercased()
            unique[id] = OnbDataPrepas.Prepa(
                id: id,
                name: libelle.trimmingCharacters(in: .whitespacesAndNewlines),
                city: city
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                country: "France",
                type: normalizeSector(item.secteur)
            )
        }

        let locale = Locale(identifier: "fr")
        let sorted = unique.values.sorted { left, right in
            let nameOrder = left.name.compare(right.name, options: .caseInsensitive, locale: locale)
            if nameOrder == .orderedSame {
                return left.city.compare(right.city, options: .caseInsensitive, locale: locale) == .orderedAscending
            }
            return nameOrder == .orderedAscending
        }
        return CachedDirectory(referenceYear: referenceYear, prepas: sorted)
    }

    /// `normalizeSector` : « priv » ⇒ privé, sinon public.
    private static func normalizeSector(_ sector: String?) -> OnbDataPrepas.Kind {
        (sector ?? "").lowercased().contains("priv") ? .privatePrep : .publicPrep
    }

    // MARK: Réseau local

    /// Année de référence la plus récente (`annee_scolaire`).
    private static func fetchReferenceYear() async throws -> String {
        let url = makeURL([
            URLQueryItem(name: "select", value: "annee_scolaire"),
            URLQueryItem(name: "group_by", value: "annee_scolaire"),
            URLQueryItem(name: "order_by", value: "annee_scolaire DESC"),
            URLQueryItem(name: "limit", value: "1"),
        ])
        let data = try await get(url)
        let payload = try JSONDecoder().decode(ReferenceYearPayload.self, from: data)
        guard let year = payload.results.first?.anneeScolaire, !year.isEmpty else {
            throw DirectoryError(message: "Le référentiel national est indisponible.")
        }
        return year
    }

    /// Une page d'établissements (`offset`/`limit` de la source).
    private static func fetchPage(referenceYear: String, offset: Int) async throws -> [OfficialRecord] {
        let fields = "uai,libelle_de_l_etablissement,com_nom,secteur_d_etablissement"
        let url = makeURL([
            URLQueryItem(name: "select", value: fields),
            URLQueryItem(name: "where", value: "annee_scolaire=\"\(referenceYear)\""),
            URLQueryItem(name: "group_by", value: fields),
            URLQueryItem(name: "order_by", value: "uai"),
            URLQueryItem(name: "limit", value: String(pageSize)),
            URLQueryItem(name: "offset", value: String(offset)),
        ])
        let data = try await get(url)
        return try JSONDecoder().decode(RecordsPayload.self, from: data).results
    }

    /// Requête GET JSON générique vers le référentiel.
    private static func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DirectoryError(message: "Le référentiel national est indisponible.")
        }
        return data
    }

    private static func makeURL(_ items: [URLQueryItem]) -> URL {
        var components = URLComponents(string: officialAPI)!
        components.queryItems = items
        return components.url!
    }
}

// MARK: Modèles de décodage

/// Un enregistrement brut du référentiel (`OfficialPrepaRecord`).
private struct OfficialRecord: Decodable {
    let uai: String?
    let libelle: String?
    let comNom: String?
    let secteur: String?

    enum CodingKeys: String, CodingKey {
        case uai
        case libelle = "libelle_de_l_etablissement"
        case comNom = "com_nom"
        case secteur = "secteur_d_etablissement"
    }
}

private struct RecordsPayload: Decodable { let results: [OfficialRecord] }

private struct ReferenceYearPayload: Decodable { let results: [YearResult] }

private struct YearResult: Decodable {
    let anneeScolaire: String?
    enum CodingKeys: String, CodingKey { case anneeScolaire = "annee_scolaire" }
}

/// Forme persistée du cache (`OfficialPrepaCache`).
private struct CachedDirectoryPayload: Codable {
    let referenceYear: String
    let prepas: [CachedPrepa]
}

private struct CachedPrepa: Codable {
    let id: String
    let name: String
    let city: String
    let country: String
    let type: OnbDataPrepas.Kind
}
