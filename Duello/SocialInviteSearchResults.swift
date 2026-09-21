//
//  SocialInviteSearchResults.swift
//  Duello
//
//  Lot « Social » — recherche d'adversaire du volet d'invitation : champ,
//  menu des résultats, états d'erreur et lignes de candidats.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/ChallengeInviteModal.tsx   (searchBar, searchMenu,
//                                                 stateBox, placeholderText,
//                                                 candidate, avatar)
//    - src/components/PremiumBadge.tsx           (« Compte abonné »)
//    - src/utils/challengeInvites.ts             (inviteSubtitle)
//
//  Découpé de `SocialInviteModal.swift` (règle des 500 lignes) : contenu repris
//  à l'identique, aucun type ni libellé renommé.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Barre de recherche

/// Champ « Invite un ou plusieurs amis… » et carré noir d'invitation d'un ami
/// qui n'a pas encore de compte.
struct SocInviteSearchBar: View {
    @Binding var query: String
    let showsInviteNewUser: Bool
    @Binding var channelsOpen: Bool

    var body: some View {
        HStack(spacing: 8) {
            searchField
            if showsInviteNewUser {
                Button { channelsOpen.toggle() } label: {
                    Image(systemName: channelsOpen ? "chevron.up" : "person.badge.plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.surface)
                        .frame(width: 48, height: 48)
                        .background(Theme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Inviter un ami qui n’a pas encore de compte Duello")
                .accessibilityHint("Ouvre le menu Message, WhatsApp ou Instagram")
                .accessibilityValue(channelsOpen ? "Déplié" : "Replié")
            }
        }
        .padding(.top, 16)
    }

    /// Le champ et sa croix d'effacement.
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            TextField("Invite un ou plusieurs amis…", text: $query)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.inkFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMedium).stroke(Theme.border, lineWidth: 1))
    }
}

// MARK: - Résultats

/// Menu des résultats (`searchMenu`) : chargement, annuaire injoignable,
/// aucun joueur compatible, ou la liste des candidats retenus.
struct SocInviteResultsMenu: View {
    let profiles: [SocSocialProfile]
    let searching: Bool
    let errorMessage: String?
    let invitedIds: [String]
    let selectedIds: Set<String>
    let onlineIds: Set<String>
    let context: SocChallengeInvites.Context
    let onRetry: () -> Void
    let onToggle: (SocSocialProfile) -> Void

    var body: some View {
        Group {
            if searching {
                SocInviteMessage(icon: nil, text: "Recherche en cours…", showsSpinner: true, retry: nil)
            } else if let errorMessage {
                SocInviteMessage(icon: "icloud.slash", text: errorMessage, showsSpinner: false, retry: onRetry)
            } else if profiles.isEmpty {
                SocInviteMessage(
                    icon: nil,
                    text: "Aucun joueur compatible ne correspond à cette recherche.",
                    showsSpinner: false,
                    retry: nil
                )
            } else {
                results
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMedium).stroke(Theme.border, lineWidth: 1))
        .padding(.top, 6)
    }

    /// Liste bornée en hauteur : elle défile sans jamais pousser le champ hors
    /// de l'écran.
    private var results: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(profiles) { member in
                    SocInviteCandidateRow(
                        member: member,
                        subtitle: SocInviteCopy.subtitle(
                            member,
                            commonChapterCount: commonChapterCount(for: member)
                        ),
                        online: onlineIds.contains(member.id),
                        invited: invitedIds.contains(member.id),
                        selected: selectedIds.contains(member.id),
                        onTap: { onToggle(member) }
                    )
                }
            }
            .padding(.bottom, 8)
        }
        .frame(maxHeight: 310)
    }

    /// Nombre de chapitres partagés avec cet ami, affiché dans sa ligne.
    private func commonChapterCount(for member: SocSocialProfile) -> Int {
        SocChallengeInvites.commonChapters(
            member,
            challengerTrack: context.track,
            subject: context.subject,
            challengerChapters: context.chapters ?? []
        ).count
    }
}

/// Message d'état du menu (`stateBox` / `placeholderText` d'Expo) : chargement,
/// annuaire injoignable, aucun joueur compatible.
struct SocInviteMessage: View {
    let icon: String?
    let text: String
    let showsSpinner: Bool
    let retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            if showsSpinner {
                ProgressView().tint(Theme.ink)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let retry {
                Button(action: retry) {
                    Text("Réessayer")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 16)
                        .background(Theme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Réessayer la recherche")
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
    }
}

// MARK: - Ligne de candidat

/// Ligne d'un candidat (`candidate`) : avatar avec pastille de présence, pseudo
/// et sous-titre de programme.
struct SocInviteCandidateRow: View {
    let member: SocSocialProfile
    let subtitle: String
    let online: Bool
    let invited: Bool
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 9) {
                SocialAvatarPresence(online: online) {
                    SocInviteAvatar(member: member, size: 36)
                }
                copy
                Spacer(minLength: 0)
                if invited {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.ink)
                        .accessibilityLabel("Invitation déjà envoyée")
                }
            }
            .padding(.horizontal, 4)
            .frame(minHeight: 62)
            .background(selected ? Theme.progressLight : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sélectionner \(member.displayName)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// Pseudo, coche de compte abonné, cadenas du profil privé et sous-titre.
    private var copy: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(member.displayName)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if member.isPremium {
                    SocInvitePremiumBadge()
                }
                if !member.isPublic {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkFaint)
                        .accessibilityLabel("Profil privé")
                }
            }
            Text(subtitle)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}

/// Coche noire signalant un compte abonné (`PremiumBadge.tsx`) : elle ne dit
/// qu'une chose — ce compte paie l'abonnement — et ne remplace jamais le
/// cadenas d'un compte privé, qui répond à une autre question.
struct SocInvitePremiumBadge: View {
    /// `PremiumBadge size={13}` dans la fenêtre d'invitation.
    var size: CGFloat = 13

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.85, weight: .bold))
            .foregroundStyle(Theme.ink)
            .accessibilityLabel("Compte abonné")
    }
}

/// Avatar de l'annuaire : photo publiée, sinon l'initiale du pseudo
/// (`avatarPhoto` / `avatarText` d'Expo).
struct SocInviteAvatar: View {
    let member: SocSocialProfile
    var size: CGFloat = 36

    var body: some View {
        if let url = photoURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                DuelloAvatar(initial: initial, size: size)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            DuelloAvatar(initial: initial, size: size)
        }
    }

    /// `avatarText` : la première lettre du pseudo, en capitale.
    private var initial: String {
        String(member.displayName.prefix(1)).uppercased()
    }

    /// `photoUri` publiée, quand elle est une adresse valide.
    private var photoURL: URL? {
        guard let photo = member.photoUri, !photo.isEmpty else { return nil }
        return URL(string: photo)
    }
}
