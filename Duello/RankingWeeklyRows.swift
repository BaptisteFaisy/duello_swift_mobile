import Foundation

// MARK: - Lignes du classement hebdo (weeklyXpLeaderboard.ts)

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
    mergeWeeklyCurrentUser(
        &byId,
        currentUser: currentUser,
        currentXp: currentXp,
        hideCurrentUserIdentity: hideCurrentUserIdentity,
        currentUserScoreLoaded: currentUserScoreLoaded
    )

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

/// Fusionne le joueur connecté dans la table du classement hebdo
/// (`buildWeeklyXpLeaderboard`) : compte privé → une ligne anonyme locale tient
/// sa place tant que la ligne publiée n'apparaît pas ; sinon la ligne locale
/// (XP frais) remplace la copie distante. Extraction de `rankedWeeklyRows`
/// (2026-09-29, ratchet Hermes) — corps inchangé.
private func mergeWeeklyCurrentUser(
    _ byId: inout [String: (entry: LeaderboardEntry, score: Int)],
    currentUser: RankingCurrentUser,
    currentXp: Int,
    hideCurrentUserIdentity: Bool,
    currentUserScoreLoaded: Bool
) {
    guard !excludedLeaderboardIds.contains(currentUser.id), currentUserScoreLoaded else { return }
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

// MARK: - Formatage des lignes de classement

/// Nombre groupé par milliers avec une espace, comme `formatElo`/`formatXp`
/// d'Expo (séparateur stable, indépendant de la locale du système).
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car appelé depuis les vues et les lignes de classement — corps
/// inchangé. Déplacé ici depuis `RankingRowBuilder.swift` (2026-09-29, ratchet
/// Hermes) — corps inchangé.
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
/// `internal` car appelé par `RankedLeaderboardRow` — corps inchangé. Déplacé
/// ici depuis `RankingRowBuilder.swift` (2026-09-29, ratchet Hermes) — corps
/// inchangé.
func leaderboardRankLabel(_ rank: Int) -> String {
    rank == 1 ? "1er" : "\(rank)e"
}
