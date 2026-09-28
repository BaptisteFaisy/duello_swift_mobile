import Foundation

// MARK: - Fusion et tri des lignes

/// Comptes d'équipe tenus hors classement (`LEADERBOARD_EXCLUDED_IDS`).
private let excludedLeaderboardIds: Set<String> = ["member-e21172e2", "member-766117b4"]

// MARK: - Portée du classement (subjectLeaderboard.ts)

/// Portée d'un classement (`LeaderboardScope` de `subjectLeaderboard.ts`).
enum LeaderboardScope: String {
    /// Classement général (« Moi »).
    case me
    /// Profils publics de la même prépa, filière et année (« Classe »).
    case classScope = "class"
    /// Établissements agrégés (« Prépas »).
    case preps
}

/// Agrégation d'un classement par prépa (`buildPrepLeaderboard`) : moyenne des
/// cotes pour l'Elo, somme des XP pour la semaine.
enum PrepAggregation {
    case average
    case sum
}

/// Joueur connecté fusionné au classement (`currentUser` de la source) :
/// identité locale, filière et cote/XP frais. Les cotes du serveur peuvent
/// retarder après un défi, la valeur locale gagne dès qu'elle est chargée.
struct RankingCurrentUser {
    let id: String
    let displayName: String
    let prepName: String
    let track: String?
    let currentTrack: String?
    let specialty: String?
    let year: String?
    /// Cote Elo ou XP de la semaine, selon le classement.
    let score: Int
    let photoUri: String?
}

/// Nom de prépa replié en clé de comparaison (`normalizedPrepName`) : sans
/// accents, en minuscules, ponctuation ramenée à un espace simple.
private func normalizedPrepName(_ value: String) -> String {
    let folded = value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))
        .lowercased()
    var out = ""
    for character in folded {
        if let scalar = character.unicodeScalars.first,
           character.unicodeScalars.count == 1,
           (scalar.value >= 97 && scalar.value <= 122)
               || (scalar.value >= 48 && scalar.value <= 57) {
            out.append(character)
        } else {
            out.append(" ")
        }
    }
    return out.split(separator: " ").joined(separator: " ")
}

/// Filtre des entrées selon la portée (`leaderboardEntriesForScope`) : la
/// portée « Classe » ne garde que les profils publics de la même prépa, de la
/// même filière et de la même année ; les autres portées gardent la liste.
func leaderboardEntriesForScope(
    _ entries: [LeaderboardEntry],
    prepName: String,
    track: String,
    year: String,
    scope: LeaderboardScope
) -> [LeaderboardEntry] {
    guard scope == .classScope else { return entries }
    let expected = normalizedPrepName(prepName)
    guard !expected.isEmpty else { return [] }
    return entries.filter { entry in
        entry.isAnonymous != true
            && normalizedPrepName(entry.prepName) == expected
            && (entry.track ?? "") == track
            && (entry.year ?? "") == year
    }
}

/// Accumule les cotes par prépa (`buildPrepLeaderboard`) : ignore les comptes
/// anonymes ou exclus, additionne les scores et compte les élèves. La prépa du
/// compte connecté garde son nom affiché d'origine.
private func prepLeaderboardGroups(
    _ entries: [LeaderboardEntry],
    currentPrep: String,
    currentPrepName: String,
    scoreFor: (LeaderboardEntry) -> Int,
    aggregation: PrepAggregation
) -> [String: (displayName: String, total: Int, count: Int)] {
    var groups: [String: (displayName: String, total: Int, count: Int)] = [:]
    for entry in entries where entry.isAnonymous != true {
        guard !entry.id.isEmpty, !excludedLeaderboardIds.contains(entry.id) else { continue }
        let key = normalizedPrepName(entry.prepName)
        guard !key.isEmpty else { continue }
        let score = max(0, scoreFor(entry))
        if aggregation == .sum && score == 0 { continue }
        var group = groups[key]
            ?? (displayName: entry.prepName.trimmingCharacters(in: .whitespacesAndNewlines), total: 0, count: 0)
        group.total += score
        group.count += 1
        if key == currentPrep {
            group.displayName = currentPrepName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        groups[key] = group
    }
    return groups
}

/// Agrège les profils publics par prépa (`buildPrepLeaderboard`) : cote moyenne
/// pour l'Elo, somme des XP pour la semaine. La prépa du compte est mise en
/// avant (`isCurrentUser`) ; les rangs restent strictement individuels.
///
/// Le joueur connecté est fusionné comme dans `buildPrepLeaderboard` : sa copie
/// distante est écartée puis sa ligne locale (cote/XP frais) ajoutée, dès que
/// sa prépa est renseignée et son score chargé.
func prepLeaderboardRows(
    _ entries: [LeaderboardEntry],
    currentPrepName: String,
    scoreFor: (LeaderboardEntry) -> Int,
    aggregation: PrepAggregation,
    currentUser: RankingCurrentUser? = nil,
    currentUserScoreLoaded: Bool = true
) -> [RankedLeaderboardRow] {
    var source = entries
    if let currentUser, currentUserScoreLoaded,
       !normalizedPrepName(currentUser.prepName).isEmpty {
        source = source.filter { $0.id != currentUser.id }
        source.append(currentUserEntry(currentUser))
    }

    let currentPrep = normalizedPrepName(currentPrepName)
    let groups = prepLeaderboardGroups(
        source,
        currentPrep: currentPrep,
        currentPrepName: currentPrepName,
        scoreFor: scoreFor,
        aggregation: aggregation
    )

    let valueLabel = aggregation == .sum ? "XP" : "ELO MOYEN"
    var aggregates: [(id: String, displayName: String, score: Int, count: Int, isCurrent: Bool)] = []
    for (key, group) in groups {
        let score = aggregation == .average
            ? Int((Double(group.total) / Double(max(1, group.count))).rounded())
            : group.total
        aggregates.append((
            id: "prep-" + key.replacingOccurrences(of: " ", with: "-"),
            displayName: group.displayName,
            score: score,
            count: group.count,
            isCurrent: key == currentPrep
        ))
    }
    let sorted = aggregates.sorted { first, second in
        if first.score != second.score { return first.score > second.score }
        return first.displayName.localizedCaseInsensitiveCompare(second.displayName) == .orderedAscending
    }

    return sorted.enumerated().map { index, item in
        RankedLeaderboardRow(
            id: item.id,
            rank: index + 1,
            displayName: item.displayName,
            initial: String(item.displayName.prefix(1)).uppercased(),
            meta: item.count == 1 ? "1 élève" : "\(item.count) élèves",
            score: item.score,
            valueLabel: valueLabel,
            isCurrentUser: item.isCurrent,
            isAnonymous: false,
            photoUri: nil,
            year: "",
            isPrepRow: true
        )
    }
}

/// Filière, année et, en ECG, option d'une ligne publique
/// (`formatWeeklyXpAcademicLabel`). La filière réellement suivie
/// (`currentTrack`) prime sur la filière historique (`track`) ; vide quand
/// filière ou année manque. L'option ECG reprend `accountAcademicOptionLabel` :
/// les anciennes spécialités « maths appliquées/approfondies » gardent leur nom
/// lisible.
private func weeklyAcademicLabel(
    currentTrack: String?,
    track: String?,
    specialty: String?,
    year: String?
) -> String {
    let trackValue = (currentTrack ?? track ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let yearValue = (year ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trackValue.isEmpty, !yearValue.isEmpty else { return "" }

    var parts = [trackValue, yearValue]
    var option = (specialty ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if trackValue == "ECG", !option.isEmpty {
        let normalized = option.lowercased()
        if normalized.contains("appliqu") {
            option = "Maths appliquées"
        } else if normalized.contains("approfond") {
            option = "Maths approfondies"
        }
        parts.append(option)
    }
    return parts.joined(separator: " · ")
}

/// Nombre groupé par milliers avec une espace, comme `formatElo`/`formatXp`
/// d'Expo (séparateur stable, indépendant de la locale du système).
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car appelé depuis les vues et les lignes de classement — corps
/// inchangé.
func groupedNumber(_ value: Int) -> String {
    let digits = String(abs(value))
    var grouped = ""
    for (index, character) in digits.reversed().enumerated() {
        if index > 0 && index % 3 == 0 { grouped.append(" ") }
        grouped.append(character)
    }
    return (value < 0 ? "-" : "") + String(grouped.reversed())
}

/// Rang français compact : « 1er », puis « 2e », « 3e »… (`formatLeaderboardRank`).
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car appelé par `RankedLeaderboardRow` — corps inchangé.
func leaderboardRankLabel(_ rank: Int) -> String {
    rank == 1 ? "1er" : "\(rank)e"
}

/// Entrée anonyme normalisée (`Anonyme`, sans identité locale).
private func anonymousEntry(id: String, score: Int) -> LeaderboardEntry {
    LeaderboardEntry(
        id: id,
        displayName: "Anonyme",
        prepName: "",
        elo: score,
        isAnonymous: true
    )
}

/// Prépare les lignes du classement Elo (`buildSubjectLeaderboard`) : écarte les
/// comptes exclus et les identifiants vides, **fusionne le joueur connecté**
/// (sa cote locale remplace celle du serveur dès qu'elle est chargée), trie par
/// cote décroissante puis par nom et marque le joueur connecté.
///
/// Un compte privé (`hideCurrentUserIdentity`) n'est jamais relié à sa ligne
/// anonyme distante : la ligne locale n'est pas ajoutée, et une place anonyme
/// n'est créée que si la liste serait vide ou si la portée l'exige
/// (`ensureAnonymousCurrentUser`).
func rankedSubjectRows(
    _ entries: [LeaderboardEntry],
    currentUser: RankingCurrentUser,
    hideCurrentUserIdentity: Bool = false,
    ensureAnonymousCurrentUser: Bool = false,
    currentUserScoreLoaded: Bool = true
) -> [RankedLeaderboardRow] {
    var byId: [String: (entry: LeaderboardEntry, score: Int)] = [:]
    for entry in entries {
        guard !entry.id.isEmpty, !excludedLeaderboardIds.contains(entry.id) else { continue }
        if entry.isAnonymous == true {
            let score = max(0, entry.elo ?? 0)
            byId[entry.id] = (anonymousEntry(id: entry.id, score: score), score)
        } else {
            guard let elo = entry.elo else { continue }
            byId[entry.id] = (entry, max(0, elo))
        }
    }

    let currentExcluded = excludedLeaderboardIds.contains(currentUser.id)
    let currentScore = max(0, currentUser.score)
    if currentUserScoreLoaded && !hideCurrentUserIdentity && !currentExcluded {
        byId[currentUser.id] = (currentUserEntry(currentUser), currentScore)
    } else if hideCurrentUserIdentity, currentUserScoreLoaded, !currentExcluded,
              ensureAnonymousCurrentUser || byId.isEmpty {
        // Premier chargement avant la publication distante : la liste ne reste
        // pas vide, mais aucun attribut local n'est rendu.
        byId["anonymous-local"] = (
            anonymousEntry(id: "anonymous-local", score: currentScore),
            currentScore
        )
    }

    let sorted = byId.values.sorted { first, second in
        if first.score != second.score { return first.score > second.score }
        return first.entry.displayName.localizedCaseInsensitiveCompare(second.entry.displayName) == .orderedAscending
    }

    return sorted.enumerated().map { index, item in
        row(
            entry: item.entry,
            score: item.score,
            rank: index + 1,
            valueLabel: "ELO",
            isCurrentUser: !hideCurrentUserIdentity && item.entry.id == currentUser.id
        )
    }
}

/// Prépare les lignes du classement XP hebdo (`buildWeeklyXpLeaderboard`) :
/// même fusion et même tri que l'Elo, sur les XP, avec la filière et l'année en
/// contexte (`formatWeeklyXpAcademicLabel`).
///
/// `currentTracks` apporte la filière réellement suivie par identifiant quand
/// une réponse ancienne ne la porte pas encore (`entry.currentTrack ?? track`).
func rankedWeeklyRows(
    _ entries: [LeaderboardEntry],
    currentUser: RankingCurrentUser,
    currentTracks: [String: String] = [:],
    hideCurrentUserIdentity: Bool = false,
    currentUserScoreLoaded: Bool = true
) -> [RankedLeaderboardRow] {
    var byId: [String: (entry: LeaderboardEntry, score: Int)] = [:]
    for entry in entries {
        guard !entry.id.isEmpty, !excludedLeaderboardIds.contains(entry.id) else { continue }
        guard let rawXp = entry.xp, rawXp.isFinite, rawXp >= 0 else { continue }
        let score = max(0, Int(rawXp.rounded()))
        if entry.isAnonymous == true {
            byId[entry.id] = (anonymousEntry(id: entry.id, score: score), score)
        } else {
            byId[entry.id] = (entry, score)
        }
    }

    let currentXp = max(0, currentUser.score)
    let currentExcluded = excludedLeaderboardIds.contains(currentUser.id)
    if !currentExcluded && currentUserScoreLoaded {
        if hideCurrentUserIdentity {
            // Compte privé : sa ligne vient du serveur. Tant qu'elle n'est pas
            // publiée, une ligne anonyme locale tient sa place sans rien révéler.
            let publishedAnonymously = byId.values.contains {
                $0.entry.isAnonymous == true && $0.score == currentXp
            }
            if !publishedAnonymously {
                byId["anonymous-local"] = (
                    anonymousEntry(id: "anonymous-local", score: currentXp),
                    currentXp
                )
            }
        } else {
            byId[currentUser.id] = (currentUserEntry(currentUser), currentXp)
        }
    }

    let sorted = byId.values.sorted { first, second in
        if first.score != second.score { return first.score > second.score }
        return first.entry.displayName.localizedCaseInsensitiveCompare(second.entry.displayName) == .orderedAscending
    }

    return sorted.enumerated().map { index, item in
        let anonymous = item.entry.isAnonymous == true
        let academic = anonymous ? "" : weeklyAcademicLabel(
            currentTrack: item.entry.currentTrack ?? currentTracks[item.entry.id],
            track: item.entry.track,
            specialty: item.entry.specialty,
            year: item.entry.year
        )
        return row(
            entry: item.entry,
            score: item.score,
            rank: index + 1,
            valueLabel: "XP",
            isCurrentUser: !hideCurrentUserIdentity && item.entry.id == currentUser.id,
            meta: anonymous
                ? "Compte privé"
                : (academic.isEmpty
                    ? (item.entry.prepName.isEmpty ? "—" : item.entry.prepName)
                    : academic)
        )
    }
}

/// Ligne anonyme distante ou locale, prête à afficher.
private func row(
    entry: LeaderboardEntry,
    score: Int,
    rank: Int,
    valueLabel: String,
    isCurrentUser: Bool,
    meta: String? = nil
) -> RankedLeaderboardRow {
    let anonymous = entry.isAnonymous == true
    let name = anonymous ? "Anonyme" : (entry.displayName.isEmpty ? "Élève" : entry.displayName)
    return RankedLeaderboardRow(
        id: entry.id,
        rank: rank,
        displayName: name,
        initial: String(name.prefix(1)).uppercased(),
        meta: meta ?? (anonymous ? "Compte privé" : ""),
        score: score,
        valueLabel: valueLabel,
        isCurrentUser: isCurrentUser,
        isAnonymous: anonymous,
        photoUri: nil,
        year: anonymous ? "" : (entry.year ?? ""),
        isPrepRow: false
    )
}

/// Entrée de classement du joueur connecté (`currentUser` de la source).
private func currentUserEntry(_ user: RankingCurrentUser) -> LeaderboardEntry {
    LeaderboardEntry(
        id: user.id,
        displayName: user.displayName,
        prepName: user.prepName,
        track: user.track,
        currentTrack: user.currentTrack,
        specialty: user.specialty,
        year: user.year,
        elo: user.score,
        xp: Double(user.score)
    )
}

/// Filières réellement suivies (`currentTrack`) d'une réponse `/weekly-xp`,
/// indexées par identifiant : la relecture tolérante laisse la table vide en
/// cas d'anomalie, et la ligne retombe sur le champ décodé `currentTrack`.
func weeklyXpCurrentTracks(from data: Data) -> [String: String] {
    struct Item: Decodable {
        var id: String?
        var currentTrack: String?
    }
    struct Payload: Decodable {
        var entries: [Item]?
    }
    guard let payload = try? DuelloAPI.decoder.decode(Payload.self, from: data) else {
        return [:]
    }
    var tracks: [String: String] = [:]
    for item in payload.entries ?? [] {
        guard let id = item.id, !id.isEmpty,
              let track = item.currentTrack, !track.isEmpty
        else { continue }
        tracks[id] = track
    }
    return tracks
}
