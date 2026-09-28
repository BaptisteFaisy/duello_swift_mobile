//
//  AcctNotificationsFriendsList.swift
//  Duello
//
//  Listes Followers / Followings de la page « Amis » de l'écran Notifications.
//
//  Fichiers source Expo portés :
//    - `src/screens/AccountScreen.tsx:2056-2139` (`renderFriendList` :
//      `peopleResults`, `personResult`, `personIdentity`, `personAvatar`,
//      `personCopy`, `personName`, `personMeta`, `miniSocialButton`) ;
//    - `src/utils/socialVisibility.ts:24-31` (`followerProfiles` : filtre par
//      identifiant puis tri par pseudo, réutilisé pour Followers **et**
//      Followings — `myFollowers` / `myFollowings`, `AccountScreen.tsx:1680-1686`).
//
//  Réutilise `AcctSearchMember` et l'avatar de l'annuaire (`SocInviteAvatar`)
//  sans les recréer : la ligne est la même que celle de la recherche du compte,
//  avec le style `personResult` de la page Amis.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Fonctions de `socialVisibility.ts` partagées par les deux listes.
enum AcctNotificationsFriends {
    /// `followerProfiles` : profils de `all` dont l'identifiant est dans `ids`,
    /// classés par pseudo comme le `localeCompare` de la source.
    static func profiles(_ all: [AcctSearchMember], ids: [String]) -> [AcctSearchMember] {
        let wanted = Set(ids)
        return all
            .filter { wanted.contains($0.id) }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }
}

/// Liste d'amis (`renderFriendList`) : message d'état vide, ou les lignes
/// `personResult` dans la carte `peopleResults`.
struct AcctNotificationsFriendList: View {
    let members: [AcctSearchMember]
    let emptyMessage: String
    let followedIds: [String]
    let onOpenMember: (String) -> Void
    let onToggleFollow: (String) -> Void

    @ObservedObject private var presence = SocPresenceStore.shared
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        if members.isEmpty {
            Text(emptyMessage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 18)
                .padding(.horizontal, 4)
        } else {
            VStack(spacing: 0) {
                ForEach(members) { member in
                    row(member)
                }
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .padding(.top, 8)
        }
    }

    /// Une ligne `personResult` : identité cliquable puis bouton de suivi.
    private func row(_ member: AcctSearchMember) -> some View {
        let followed = followedIds.contains(member.id)
        return HStack(spacing: 7) {
            Button {
                onOpenMember(member.id)
            } label: {
                HStack(spacing: 0) {
                    SocialAvatarPresence(online: presence.isOnline(member.id)) {
                        SocInviteAvatar(member: member.profile, size: 36)
                    }
                    copy(member)
                        .padding(.leading, 9)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voir le profil de \(member.displayName)")

            Button {
                onToggleFollow(member.id)
            } label: {
                IonIcon(
                    name: followed ? "checkmark" : "add",
                    size: 15,
                    color: followed ? Theme.white : Theme.ink
                )
                .frame(width: 34, height: 34)
                .background(followed ? Theme.primary : Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(followed ? Theme.primary : Theme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                followed
                    ? "Ne plus suivre \(member.displayName)"
                    : "Suivre \(member.displayName)"
            )
        }
        .padding(.horizontal, 10)
        .frame(height: AcctSearchConstants.resultHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1 / max(displayScale, 1))
        }
    }

    /// `personCopy` : pseudo (12/900), pastille d'abonné, méta de parcours (9).
    private func copy(_ member: AcctSearchMember) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Text(member.displayName)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if member.isPremium { PremPremiumBadge(size: 13) }
            }
            Text(metaLine(member))
                .font(.system(size: 9))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(2)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `[année, filière, spécialité, prépa]` joints par « · » (vides retirés).
    private func metaLine(_ member: AcctSearchMember) -> String {
        [member.year, member.track, member.specialty, member.prepName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
