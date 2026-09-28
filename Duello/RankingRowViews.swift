import Foundation
import SwiftUI

// MARK: - Lignes de classement

/// Ligne prête à afficher, calculée après fusion et tri côté client.
///
/// Extrait de l'ancien `RankingsView.swift`. Champs repris de la source Expo
/// (`RankingsScreen.tsx:617-676`, `WeeklyXpRankingScreen.tsx:224-296`) : rang,
/// avatar (initiale ou photo), nom, année, contexte, valeur et mise en avant du
/// joueur connecté.
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

/// Variante d'une ligne de classement : l'Elo et les XP n'ont pas les mêmes
/// tailles ni les mêmes teintes (`RankingsScreen.tsx` / `WeeklyXpRankingScreen.tsx`).
enum LeaderboardRowKind {
    case elo
    case xp
}

/// Ombre des cartes de ligne (`cardShadow` de `theme.ts`, variante iOS).
private let leaderboardRowShadowColor = Color(hex: 0x0A0D0C).opacity(0.04)

/// Ligne de classement : rang, avatar à photo ou initiale, nom, année, pastille
/// du joueur connecté et valeur.
///
/// Extrait de l'ancien `RankingsView.swift`, complété d'après
/// `RankingsScreen.tsx:603-676` et `WeeklyXpRankingScreen.tsx:224-296` :
/// l'avatar porte la photo publiée quand elle existe (sinon l'initiale), il est
/// enveloppé d'une pastille de présence, l'année suit le nom, et les lignes du
/// top 3 (`featured`) comme celles d'un compte privé (`showsPrivateIcon`) sont
/// servies par le même composant.
///
/// Chaque ligne est **sa propre carte** (`leaderboardRowCard`) : fond blanc,
/// liseré et ombre portée, espacées de `LEADERBOARD_ROW_GAP` (8) par l'appelant
/// — il n'y a plus de bloc à filets.
struct LeaderboardRowView: View {
    let row: RankedLeaderboardRow
    /// Classement servi : teintes et tailles de l'Elo ou des XP.
    var kind: LeaderboardRowKind = .elo
    /// Top 3 mis en avant (XP hebdo) : avatar sur fond blanc, valeur primaire.
    var featured: Bool = false
    /// Icône cadenas dans l'avatar d'un compte privé (`lock-closed-outline`).
    var showsPrivateIcon: Bool = false
    /// Ouvre la fiche du joueur (`onOpenProfile`) ; `nil` laisse la ligne
    /// inerte (comptes privés et portée « Prépas »).
    var onOpenProfile: ((String) -> Void)? = nil

    /// Source de présence partagée : l'anneau en ligne est le même que partout
    /// (`SocPresenceStore`, port de `usePresence`).
    @ObservedObject private var presence: SocPresenceStore = SocPresenceStore.shared

    /// La ligne ouvre-t-elle une fiche ? (portée non « Prépas », compte public).
    private var isTappable: Bool {
        onOpenProfile != nil && !row.isPrepRow && !row.isAnonymous
    }

    var body: some View {
        if isTappable, let onOpenProfile {
            Button { onOpenProfile(row.id) } label: { content }
                .buttonStyle(.plain)
                .accessibilityLabel("Voir le profil de \(row.displayName), \(leaderboardRankLabel(row.rank)), \(groupedNumber(row.score)) \(row.valueLabel)")
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    /// Libellé d'accessibilité d'une ligne inerte (compte privé, prépas) :
    /// `1er, X[, compte privé], 1234 ELO`.
    private var accessibilityLabel: String {
        var parts = [leaderboardRankLabel(row.rank), row.displayName]
        if row.isAnonymous { parts.append("compte privé") }
        parts.append("\(groupedNumber(row.score)) \(row.valueLabel)")
        return parts.joined(separator: ", ")
    }

    /// Corps de la ligne, commun aux deux états (bouton ou ligne inerte).
    private var content: some View {
        HStack(spacing: 0) {
            Text("\(row.rank)")
                .font(.system(size: 12, weight: .heavy).monospacedDigit())
                .foregroundStyle(kind == .xp ? Theme.ink : Theme.inkSoft)
                .frame(width: 24, alignment: .center)

            avatar
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: kind == .xp ? 1 : 4) {
                HStack(spacing: 6) {
                    Text(row.displayName)
                        .font(.system(size: kind == .xp ? 11 : 12, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if !row.year.isEmpty && !row.isPrepRow {
                        Text(row.year)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    if row.isCurrentUser {
                        meBadge
                    }
                }
                if !row.meta.isEmpty {
                    Text(row.meta)
                        .font(.system(size: kind == .xp ? 8 : 9, weight: kind == .xp ? .bold : .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(groupedNumber(row.score))
                    .font(.system(size: kind == .xp ? 13 : 11, weight: .heavy).monospacedDigit())
                    .foregroundStyle(valueColor)
                Text(row.valueLabel)
                    .font(.system(size: 7, weight: .heavy))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, kind == .xp ? 3 : 4)
        .frame(minHeight: kind == .xp ? 40 : 44)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: leaderboardRowShadowColor, radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
    }

    /// Pastille « MOI » / « MA PRÉPA » (`meBadge`) : fond primaire, texte blanc.
    private var meBadge: some View {
        Text(row.isPrepRow ? "MA PRÉPA" : "MOI")
            .font(.system(size: 7, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(Theme.surface)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.primary)
            .clipShape(Capsule())
    }

    /// Teinte de la valeur : primaire pour le top 3 des XP, encre sinon
    /// (`xpValue` / `featuredXpValue` ; `eloValue` reste en encre douce).
    private var valueColor: Color {
        if kind == .xp { return featured ? Theme.primary : Theme.ink }
        return Theme.inkSoft
    }

    /// Avatar du joueur : photo ou initiale, pastille de présence, cadenas des
    /// comptes privés. La ligne anonyme d'un classement sans cadenas n'a pas
    /// d'avatar, comme `RankingsScreen.tsx`.
    @ViewBuilder
    private var avatar: some View {
        if row.isAnonymous {
            if showsPrivateIcon {
                privateAvatar
            }
        } else {
            SocialAvatarPresence(online: presence.isOnline(row.id)) {
                LeaderboardAvatar(
                    initial: row.initial,
                    photoUri: row.photoUri,
                    size: avatarSize,
                    background: avatarBackground,
                    foreground: avatarForeground,
                    initialFontSize: 12
                )
            }
        }
    }

    /// Avatar d'un compte privé (XP) : cercle et cadenas Ionicons
    /// (`lock-closed-outline`, taille 17).
    private var privateAvatar: some View {
        ZStack {
            Circle().fill(avatarBackground).frame(width: avatarSize, height: avatarSize)
            IonIcon(name: "lock-closed-outline", size: 17, color: Theme.inkSoft)
        }
        .frame(width: avatarSize, height: avatarSize)
    }

    /// Côté de l'avatar (`avatar` 30 en Elo, 28 en XP).
    private var avatarSize: CGFloat { kind == .xp ? 28 : 30 }

    /// Fond de l'avatar : encre du joueur connecté, blanc du top 3, pastille
    /// claire sinon (`currentAvatar` > `featuredAvatar` > `avatar`).
    private var avatarBackground: Color {
        if row.isCurrentUser { return Theme.primary }
        if featured { return Theme.surface }
        return Theme.surfaceMuted
    }

    /// Teinte de l'initiale : surface du joueur connecté, primaire du top 3,
    /// encre douce sinon.
    private var avatarForeground: Color {
        if row.isCurrentUser { return Theme.surface }
        if featured { return Theme.primary }
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
    /// Taille de l'initiale ; `nil` la déduit du côté de l'avatar.
    var initialFontSize: CGFloat? = nil

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
                .font(.system(size: initialFontSize ?? size * 0.4, weight: .black))
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
/// Extrait de l'ancien `RankingsView.swift`. **Plus posé** par les deux
/// classements : la source Expo espace des cartes (`LEADERBOARD_ROW_GAP`), sans
/// filet. Le type reste pour les écrans qui l'utilisent encore.
struct LeaderboardRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }
}
