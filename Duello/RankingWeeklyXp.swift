import Foundation
import SwiftUI

// MARK: - Classement XP de la semaine

/// Classement des XP de la semaine pour une matière, en **liste à plat**.
///
/// Reprend `WeeklyXpRankingScreen.tsx` : chargement de `/weekly-xp`, semaine
/// calculée par `WeeklyXP.weekKey()`, états chargement/erreur (avec la notice
/// locale d'erreur portée par la carte), top 3 mis en avant puis le reste, et
/// dock « Moi · rang » du joueur connecté.
///
/// Le RN ne rend **ni** groupement par ligues, **ni** carte « Ma semaine »,
/// **ni** état vide, **ni** en-tête de section ou de ligue : ces éléments
/// (portés par une version antérieure) ont été retirés.
///
/// Les valeurs de cet écran (`leaderRow`, `stateCard`, `currentUserDock`) lui
/// sont **propres** : elles diffèrent du classement Elo (`RankingsScreen.tsx`).
/// Les lignes, les cartes d'état et le dock sont donc rendus ici localement,
/// plutôt que par les composants partagés `LeaderboardRowView` /
/// `RankingStatusCard` (qui portent les valeurs unifiées Elo+XP, signalées au
/// rapport de fidélité). Le chrome des lignes (`leaderboardRowCard` : bord fin
/// + ombre) et l'écart entre lignes (`LEADERBOARD_ROW_GAP = 8`) sont repris
/// tels quels.
///
/// Dépend de `RankingRowBuilder` (`rankedWeeklyRows`, `groupedNumber`,
/// `leaderboardRankLabel`, `weeklyXpCurrentTracks`) et de `RankingRowViews`
/// (`RankedLeaderboardRow`, `LeaderboardAvatar`).
struct WeeklyXpRankingView: View {
    @EnvironmentObject private var session: SessionStore

    /// Matière classée.
    let subject: String
    /// Lundi de la semaine classée, au format AAAA-MM-JJ.
    var week: String = WeeklyXP.weekKey()
    /// XP gagnés localement cette semaine dans cette matière (prop `weeklyXp`
    /// de `WeeklyXpRankingScreen.tsx`), pour la notice locale d'erreur.
    var weeklyXp: Int = 0

    @State private var entries: [LeaderboardEntry] = []
    @State private var currentTracks: [String: String] = [:]
    @State private var phase: RankingLoadPhase = .loading
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stateContent
        }
        .overlay(alignment: .bottom) { currentUserDock }
        .onAppear { load() }
    }

    /// Contenu selon l'état de chargement : attente, panne ou classement.
    ///
    /// Aucun état vide global : le RN n'affiche rien quand la liste est vide.
    @ViewBuilder
    private var stateContent: some View {
        switch phase {
        case .loading:
            loadingCard
        case .error:
            errorCard
        case .ready:
            VStack(alignment: .leading, spacing: 0) {
                if !leadingRows.isEmpty {
                    rowsList(leadingRows, featured: true)
                }
                if !remainingRows.isEmpty {
                    // `remainingList` : second groupe décalé de 12 pt
                    // (`WeeklyXpRankingScreen.tsx:360`).
                    rowsList(remainingRows, featured: false)
                        .padding(.top, 12)
                }
            }
        }
    }

    /// Lignes classées : rang, XP et surlignage du joueur connecté.
    private var rows: [RankedLeaderboardRow] {
        rankedWeeklyRows(
            entries,
            currentId: DuelloAPI.publicProfileId(email: session.profile.email),
            currentTracks: currentTracks
        )
    }

    /// Top 3 mis en avant, puis le reste de la liste (`slice(0, 3)` / `slice(3)`).
    private var leadingRows: [RankedLeaderboardRow] { Array(rows.prefix(3)) }
    private var remainingRows: [RankedLeaderboardRow] { Array(rows.dropFirst(3)) }

    /// XP de la semaine du joueur connecté, pour la notice locale d'erreur :
    /// le total local quand il est fourni, sinon la ligne déjà chargée.
    private var localWeeklyXp: Int {
        weeklyXp > 0 ? weeklyXp : (rows.first(where: { $0.isCurrentUser })?.score ?? 0)
    }

    // MARK: États (C10, C11)

    /// Carte d'attente (`stateCard` + `ActivityIndicator`,
    /// `WeeklyXpRankingScreen.tsx:313-323`) : l'indicateur est posé
    /// directement dans la carte, **sans** cadre d'icône, et il prend la
    /// couleur primaire (l'encre).
    private var loadingCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ProgressView()
                .tint(Theme.ink)

            VStack(alignment: .leading, spacing: 0) {
                Text("Chargement du classement…")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("Les XP de la semaine sont en cours de récupération.")
                    .font(.system(size: 10, weight: .semibold))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .weeklyXpCardShadow()
        .padding(.top, 18)
    }

    /// Carte de panne (`stateCard`, `WeeklyXpRankingScreen.tsx:325-351`) :
    /// icône « cloud-offline-outline » dans un carré gris, titre, message
    /// d'erreur, notice locale et bouton de réessai.
    private var errorCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.surfaceMuted)
                    .frame(width: 34, height: 34)
                Image(systemName: "cloud.offline")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.ink)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Classement indisponible")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text(errorMessage.isEmpty
                    ? "Le classement est momentanément indisponible."
                    : errorMessage)
                    .font(.system(size: 10, weight: .semibold))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
                Text(localNotice)
                    .font(.system(size: 10, weight: .heavy))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { load() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Réessayer de charger le classement")
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .weeklyXpCardShadow()
        .padding(.top, 18)
    }

    /// Notice locale d'erreur (`localNotice`,
    /// `WeeklyXpRankingScreen.tsx:333-337`) : les XP locaux restent comptés
    /// malgré la panne du classement.
    private var localNotice: String {
        "Tes \(groupedNumber(localWeeklyXp)) XP de la semaine restent comptés."
    }

    // MARK: Lignes

    /// Un groupe de lignes : cartes séparées par `LEADERBOARD_ROW_GAP` (8 pt),
    /// chacune portant son propre chrome (`leaderboardRowCard`).
    private func rowsList(_ rows: [RankedLeaderboardRow], featured: Bool) -> some View {
        VStack(spacing: 8) {
            ForEach(rows) { row in
                WeeklyXpRankingRow(row: row, featured: featured)
            }
        }
    }

    // MARK: Dock du joueur connecté

    /// Dock « Moi · rang » du joueur connecté (`currentUserDock`,
    /// `WeeklyXpRankingScreen.tsx:366-389`).
    @ViewBuilder
    private var currentUserDock: some View {
        if phase == .ready, let row = rows.first(where: { $0.isCurrentUser }) {
            HStack(spacing: 0) {
                SocialAvatarPresence(online: SocPresenceStore.shared.isOnline(row.id)) {
                    LeaderboardAvatar(
                        initial: row.initial,
                        photoUri: row.photoUri,
                        size: 28,
                        background: Theme.primary,
                        foreground: Theme.surface
                    )
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("Moi · \(leaderboardRankLabel(row.rank))")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Theme.primary)
                    Text(row.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .padding(.top, 3)
                    Text(row.meta)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                        .padding(.top, 1)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(groupedNumber(row.score))
                        .font(.system(size: 13, weight: .black).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                    Text("XP")
                        .font(.system(size: 7, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.primary, lineWidth: 1)
            )
            .weeklyXpCardShadow()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Moi, \(leaderboardRankLabel(row.rank)), \(groupedNumber(row.score)) XP"
            )
        }
    }

    // MARK: Chargement

    /// Charge le classement XP de la semaine pour la session ouverte.
    private func load() {
        guard let token = session.token else {
            errorMessage = "Ta session a expiré, reconnecte-toi."
            phase = .error
            return
        }
        phase = .loading
        errorMessage = ""
        let subject = self.subject
        let week = self.week
        Task {
            do {
                let data = try await DuelloAPI.request(
                    "weekly-xp",
                    token: token,
                    query: [
                        URLQueryItem(name: "subject", value: subject),
                        URLQueryItem(name: "week", value: week),
                    ]
                )
                let response = try DuelloAPI.decoder.decode(
                    DuelloAPI.LeaderboardResponse.self,
                    from: data
                )
                let tracks = weeklyXpCurrentTracks(from: data)
                await MainActor.run {
                    entries = response.entries ?? []
                    currentTracks = tracks
                    phase = .ready
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    errorMessage = message
                    phase = .error
                }
            }
        }
    }
}

// MARK: - Ligne du classement XP

/// Ligne du classement XP de la semaine (`leaderRow` +
/// `WeeklyXpRankingScreen.tsx:206-293`) : carte blanche à bord fin et ombre
/// (`leaderboardRowCard`), rang, avatar, nom + pastille « MOI », contexte
/// académique et total d'XP.
///
/// Les valeurs diffèrent de la ligne Elo (`RankingsScreen.tsx`) : rang en
/// **encre pleine** (l'Elo le grise), avatar 28 (Elo 30), nom 11/900 (Elo
/// 12/900), contexte 8/700 (Elo 9/600), valeur 13/900 en encre (Elo 11/800
/// grisée), hauteur minimale 40 (Elo 44).
private struct WeeklyXpRankingRow: View {
    let row: RankedLeaderboardRow
    /// Top 3 mis en avant : avatar sur fond blanc, initiale primaire et total
    /// d'XP primaire.
    var featured: Bool = false

    @ObservedObject private var presence: SocPresenceStore = SocPresenceStore.shared

    var body: some View {
        HStack(spacing: 0) {
            Text("\(row.rank)")
                .font(.system(size: 12, weight: .black).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(width: 24, alignment: .center)

            avatar
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(row.displayName)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if row.isCurrentUser {
                        Text(row.isPrepRow ? "MA PRÉPA" : "MOI")
                            .font(.system(size: 7, weight: .black))
                            .tracking(0.6)
                            .foregroundStyle(Theme.surface)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.primary)
                            .clipShape(Capsule())
                    }
                }
                if !row.meta.isEmpty {
                    Text(row.meta)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                        .padding(.top, 1)
                }
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(groupedNumber(row.score))
                    .font(.system(size: 13, weight: .black).monospacedDigit())
                    .foregroundStyle(featured ? Theme.primary : Theme.ink)
                Text("XP")
                    .font(.system(size: 7, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .weeklyXpCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
    }

    /// Avatar du joueur : photo ou initiale, pastille de présence, cadenas des
    /// comptes privés. Ligne anonyme : cercle gris (blanc dans le top 3) et
    /// cadenas `lock-closed-outline` en encre douce.
    @ViewBuilder
    private var avatar: some View {
        if row.isAnonymous {
            LeaderboardAvatar(
                initial: "",
                photoUri: nil,
                size: 28,
                background: featured ? Theme.surface : Theme.surfaceMuted,
                foreground: Theme.inkSoft,
                placeholderIcon: "lock"
            )
        } else {
            SocialAvatarPresence(online: presence.isOnline(row.id)) {
                LeaderboardAvatar(
                    initial: row.initial,
                    photoUri: row.photoUri,
                    size: 28,
                    background: avatarBackground,
                    foreground: avatarForeground
                )
            }
        }
    }

    /// Fond de l'avatar : primaire du joueur connecté, blanc du top 3, gris
    /// clair sinon (`currentAvatar` / `featuredAvatar` / `avatar`).
    private var avatarBackground: Color {
        if row.isCurrentUser { return Theme.primary }
        if featured { return Theme.surface }
        return Theme.surfaceMuted
    }

    /// Teinte de l'initiale : blanc du joueur connecté, primaire du top 3,
    /// encre douce sinon (`currentAvatarText` / `featuredAvatarText` /
    /// `avatarText`).
    private var avatarForeground: Color {
        if row.isCurrentUser { return Theme.surface }
        if featured { return Theme.primary }
        return Theme.inkSoft
    }
}

// MARK: - Ombre des cartes

private extension View {
    /// Ombre des cartes de cet écran (`cardShadow` de `theme.ts`) : encre à
    /// 4 %, décalée de 2 pt vers le bas, rayon 8 — absente de `duelloCard()`,
    /// qui ne pose qu'un bord fin.
    func weeklyXpCardShadow() -> some View {
        shadow(color: Color(hex: 0x0A0D0C).opacity(0.04), radius: 8, x: 0, y: 2)
    }
}
