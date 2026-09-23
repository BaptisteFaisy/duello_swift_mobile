import Foundation
import SwiftUI

// MARK: - Lignes de classement

/// Ligne prête à afficher, calculée après fusion et tri côté client.
///
/// Extrait de l'ancien `RankingsView.swift`. Champs repris de la source Expo
/// (`RankingsScreen.tsx:617-676`) : rang, avatar (initiale ou photo), nom,
/// année, contexte, valeur et mise en avant du joueur connecté.
struct RankedLeaderboardRow: Identifiable {
    let id: String
    let rank: Int
    let displayName: String
    let initial: String
    let meta: String
    let score: Int
    let valueLabel: String
    let isCurrentUser: Bool
    let isAnonymous: Bool
    /// Photo publiée (miniature `data:` ou adresse distante), quand le profil
    /// en porte une (`photoUri`). Absente pour une ligne anonyme.
    var photoUri: String? = nil
    /// Année d'études affichée à côté du nom (`entry.year`, hors portée prépas).
    var year: String = ""
    /// Ligne de prépa agrégée (portée « Prépas ») : la pastille devient
    /// `MA PRÉPA` et l'année n'est pas affichée.
    var isPrepRow: Bool = false

    /// Libellé d'accessibilité : rang, nom, contexte puis valeur.
    var accessibilityLabel: String {
        let rankText = leaderboardRankLabel(rank)
        let valueText = "\(groupedNumber(score)) \(valueLabel)"
        return [rankText, displayName, meta, valueText]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

/// Ligne de classement : rang, avatar à photo ou initiale, nom, année, pastille
/// du joueur connecté et valeur.
///
/// Extrait de l'ancien `RankingsView.swift`, complété d'après
/// `RankingsScreen.tsx:603-676` et `WeeklyXpRankingScreen.tsx:224-296` :
/// l'avatar porte la photo publiée quand elle existe (sinon l'initiale), il est
/// enveloppé d'une pastille de présence, l'année suit le nom, et les lignes du
/// top 3 (`featured`) comme celles d'un compte privé (`showsPrivateIcon`) sont
/// servies par le même composant.
struct LeaderboardRowView: View {
    let row: RankedLeaderboardRow
    /// Top 3 mis en avant (XP hebdo) : avatar sur fond blanc, texte primaire.
    var featured: Bool = false
    /// Icône cadenas dans l'avatar d'un compte privé (`lock-closed-outline`).
    var showsPrivateIcon: Bool = false

    /// Source de présence partagée : l'anneau en ligne est le même que partout
    /// (`SocPresenceStore`, port de `usePresence`).
    @ObservedObject private var presence: SocPresenceStore = SocPresenceStore.shared

    var body: some View {
        HStack(spacing: 10) {
            Text("\(row.rank)")
                .font(.system(size: 13, weight: .black).monospacedDigit())
                .foregroundStyle(row.rank <= 3 ? Theme.ink : Theme.inkFaint)
                .frame(width: 26, alignment: .center)

            avatar

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.displayName)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if !row.year.isEmpty && !row.isPrepRow {
                        Text(row.year)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    if row.isCurrentUser {
                        DuelloPill(text: row.isPrepRow ? "MA PRÉPA" : "MOI", tone: .ink)
                    }
                }
                if !row.meta.isEmpty {
                    Text(row.meta)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(groupedNumber(row.score))
                    .font(.system(size: 14, weight: .black).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                Text(row.valueLabel)
                    .font(.system(size: 9, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(row.isCurrentUser ? Theme.primaryLight : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
    }

    /// Avatar du joueur : photo ou initiale, pastille de présence, cadenas des
    /// comptes privés. La ligne anonyme d'un classement sans cadenas n'a pas
    /// d'avatar, comme `RankingsScreen.tsx`.
    @ViewBuilder
    private var avatar: some View {
        if row.isAnonymous {
            if showsPrivateIcon {
                LeaderboardAvatar(
                    initial: "",
                    photoUri: nil,
                    size: 32,
                    background: row.isCurrentUser ? Theme.ink : Theme.surfaceMuted,
                    foreground: row.isCurrentUser ? Theme.surface : Theme.inkSoft,
                    placeholderIcon: "lock"
                )
            }
        } else {
            SocialAvatarPresence(online: presence.isOnline(row.id)) {
                LeaderboardAvatar(
                    initial: row.initial,
                    photoUri: row.photoUri,
                    size: 32,
                    background: avatarBackground,
                    foreground: avatarForeground
                )
            }
        }
    }

    /// Fond de l'avatar : encre du joueur connecté, blanc du top 3, pastille
    /// claire sinon.
    private var avatarBackground: Color {
        if row.isCurrentUser { return Theme.ink }
        if featured { return Theme.surface }
        return Theme.primaryLight
    }

    /// Teinte de l'initiale : surface du joueur connecté, primaire du top 3,
    /// encre douce sinon.
    private var avatarForeground: Color {
        if row.isCurrentUser { return Theme.surface }
        if featured { return Theme.ink }
        return Theme.inkSoft
    }
}

/// Avatar rond de classement : photo publiée (miniature `data:` ou adresse
/// distante) découpée en cercle, sinon l'initiale du nom (`avatarPhoto` /
/// `avatarInitial` de `RankingsScreen.tsx`), ou l'icône de repli (cadenas d'un
/// compte privé).
///
/// Reprend la lecture d'URI de `AcctBadgeRoundPhoto` : `PhotoPickUri` normalise
/// la miniature, `CachedImage` la décode hors main thread, `CachedRemoteImage`
/// charge l'adresse distante.
struct LeaderboardAvatar: View {
    let initial: String
    let photoUri: String?
    let size: CGFloat
    var background: Color = Theme.primaryLight
    var foreground: Color = Theme.inkSoft
    /// Symbole affiché quand il n'y a ni photo ni initiale.
    var placeholderIcon: String = "person.fill"

    var body: some View {
        ZStack {
            Circle().fill(background).frame(width: size, height: size)
            content
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var content: some View {
        if let source = localPhotoSource {
            CachedImage(source) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            } placeholder: {
                initialLabel
            }
        } else if let url = remoteURL {
            CachedRemoteImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            initialLabel
        }
    }

    /// Initiale, ou icône de repli quand le nom est vide.
    @ViewBuilder
    private var initialLabel: some View {
        if initial.isEmpty {
            Image(systemName: placeholderIcon)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(foreground)
        } else {
            Text(initial)
                .font(.system(size: size * 0.4, weight: .black))
                .foregroundStyle(foreground)
        }
    }

    /// Miniature `data:` décodée localement (`publicProfilePhotoUri`).
    private var localPhotoSource: CachedImageSource? {
        guard let uri = PhotoPickUri.publicProfilePhotoUri(photoUri),
              let comma = uri.firstIndex(of: ","),
              let data = Data(base64Encoded: String(uri[uri.index(after: comma)...]))
        else { return nil }
        return .data(data, key: ImageCache.key(for: uri))
    }

    /// Adresse distante, quand l'URI n'est pas une miniature `data:`.
    private var remoteURL: URL? {
        guard let uri = photoUri, !uri.isEmpty, !uri.hasPrefix("data:") else { return nil }
        return URL(string: uri)
    }
}

/// Séparateur fin entre deux lignes, à la couleur de bordure du thème.
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car posé par les deux classements — corps inchangé.
struct LeaderboardRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }
}
