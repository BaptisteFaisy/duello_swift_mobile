import Foundation

// MARK: - Fusion et tri des lignes

/// Comptes d'équipe tenus hors classement (`LEADERBOARD_EXCLUDED_IDS`).
private let excludedLeaderboardIds: Set<String> = ["member-e21172e2", "member-766117b4"]

/// Libellé d'option ECG repris de `accountAcademicOptionLabel` : les anciennes
/// spécialités « maths appliquées/approfondies » gardent leur nom lisible.
private func academicOptionLabel(track: String, specialty: String) -> String {
    let option = specialty.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !option.isEmpty, track == "ECG" else { return option }
    let normalized = option.lowercased()
    if normalized.contains("appliqu") { return "Maths appliquées" }
    if normalized.contains("approfond") { return "Maths approfondies" }
    return option
}

/// Filière, année et, en ECG, option d'une ligne publique
/// (`formatWeeklyXpAcademicLabel`). Vide quand filière ou année manque.
private func weeklyAcademicLabel(track: String?, specialty: String?, year: String?) -> String {
    let trackValue = (track ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let yearValue = (year ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trackValue.isEmpty, !yearValue.isEmpty else { return "" }

    var parts = [trackValue, yearValue]
    let option = academicOptionLabel(track: trackValue, specialty: specialty ?? "")
    if trackValue == "ECG", !option.isEmpty {
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

/// Prépare les lignes du classement Elo : filtre les comptes exclus, écarte les
/// identifiants vides, trie par cote décroissante puis par nom, et marque le
/// joueur connecté (`buildSubjectLeaderboard`).
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car appelé par `RankingSubjectLeaderboard` — corps inchangé.
func rankedSubjectRows(_ entries: [LeaderboardEntry], currentId: String) -> [RankedLeaderboardRow] {
    let sorted = entries
        .filter { !$0.id.isEmpty && !excludedLeaderboardIds.contains($0.id) }
        .map { entry in (entry: entry, score: max(0, entry.elo ?? 0)) }
        .sorted { first, second in
            if first.score != second.score { return first.score > second.score }
            return first.entry.displayName.localizedCaseInsensitiveCompare(second.entry.displayName) == .orderedAscending
        }

    return sorted.enumerated().map { index, item in
        let anonymous = item.entry.isAnonymous == true
        let name = anonymous
            ? "Anonyme"
            : (item.entry.displayName.isEmpty ? "Élève" : item.entry.displayName)
        return RankedLeaderboardRow(
            id: item.entry.id,
            rank: index + 1,
            displayName: name,
            initial: String(name.prefix(1)).uppercased(),
            meta: anonymous
                ? "Compte privé"
                : (item.entry.prepName.isEmpty ? "—" : item.entry.prepName),
            score: item.score,
            valueLabel: "Elo",
            isCurrentUser: !anonymous && item.entry.id == currentId,
            isAnonymous: anonymous
        )
    }
}

/// Prépare les lignes du classement XP hebdo : même filtre et même tri que le
/// classement Elo, sur les XP, avec la filière et l'année en contexte
/// (`buildWeeklyXpLeaderboard`).
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car appelé par `RankingWeeklyXp` — corps inchangé.
func rankedWeeklyRows(_ entries: [LeaderboardEntry], currentId: String) -> [RankedLeaderboardRow] {
    let sorted = entries
        .filter { !$0.id.isEmpty && !excludedLeaderboardIds.contains($0.id) }
        .map { entry in (entry: entry, score: max(0, Int((entry.xp ?? 0).rounded()))) }
        .sorted { first, second in
            if first.score != second.score { return first.score > second.score }
            return first.entry.displayName.localizedCaseInsensitiveCompare(second.entry.displayName) == .orderedAscending
        }

    return sorted.enumerated().map { index, item in
        let anonymous = item.entry.isAnonymous == true
        let name = anonymous
            ? "Anonyme"
            : (item.entry.displayName.isEmpty ? "Élève" : item.entry.displayName)
        let academic = weeklyAcademicLabel(
            track: item.entry.track,
            specialty: item.entry.specialty,
            year: item.entry.year
        )
        let meta: String
        if anonymous {
            meta = "Compte privé"
        } else if !academic.isEmpty {
            meta = academic
        } else {
            meta = item.entry.prepName.isEmpty ? "—" : item.entry.prepName
        }
        return RankedLeaderboardRow(
            id: item.entry.id,
            rank: index + 1,
            displayName: name,
            initial: String(name.prefix(1)).uppercased(),
            meta: meta,
            score: item.score,
            valueLabel: "XP",
            isCurrentUser: !anonymous && item.entry.id == currentId,
            isAnonymous: anonymous
        )
    }
}
