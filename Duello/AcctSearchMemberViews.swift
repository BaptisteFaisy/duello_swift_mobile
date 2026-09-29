//
//  AcctSearchMemberViews.swift
//  Duello
//
//  Lot « AcctSearch » (10-D) — vue du membre dans l'annuaire : carte d'attente,
//  bandeaux d'état, en-tête de la fiche publique (identité publiée, blason,
//  actions sociales) et ligne de résultat de la recherche.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx (lockedCard, showcase, socialActions,
//                                     directoryStatus, personResult)
//    - src/components/PremiumBadge.tsx (« Compte abonné »)
//    - src/components/ProfileSafetyMenu.tsx (menu de sécurité)
//    - src/components/BackButton.tsx (chevron de retour)
//
//  Découpé de `AcctSearchView.swift` (règle des 500 lignes) : aucun type ni
//  libellé renommé.
//
//  V5 (2026-09-29, parité RN dev) : le prof IA (`prof-ia`) affiche son rôle et
//  son périmètre au lieu de la filière et de l'année (`AccountScreen.tsx:2799-2801`
//  ligne de résultat, `:2964-2974` fiche ouverte) et masque ses boutons sociaux
//  — suivi de ligne (`:2823`), barre d'actions de la fiche (`:1702,3018`).
//
//  Hors périmètre : le détail des performances (XP, Elo, séries, graphiques)
//  appartient aux lots dédiés ; seule l'identité et les actions sociales sont
//  portées ici.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Fiche en attente

/// Carte d'attente de la fiche ouverte (`lockedCard`) : chargement ou échec, avec
/// « Réessayer ». L'identifiant seul ne doit jamais laisser apparaître, même
/// brièvement, les statistiques du compte connecté.
struct AcctSearchProfileStatus: View {
    let failed: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if failed {
                IonIcon(name: "cloud-offline-outline", size: 25, color: Theme.inkSoft)
            } else {
                ProgressView().tint(Theme.ink)
            }
            Text(failed ? "Profil indisponible" : "Actualisation du profil…")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.ink)
            Text(failed
                 ? "Les performances n’ont pas pu être relues pour le moment."
                 : "Les dernières métriques publiées sont en cours de chargement.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if failed {
                Button(action: onRetry) {
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
                .accessibilityLabel("Réessayer de charger le profil")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .duelloCard()
    }
}

// MARK: - Bandeaux d'état de l'annuaire

/// Bandeau d'état de la publication à l'annuaire (`directoryStatus` d'Expo) :
/// icône `warning-outline` et message, tant que le profil n'est pas publié.
struct AcctSearchDirectoryStatus: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            IonIcon(name: "warning-outline", size: 15, color: Theme.inkSoft)
            Text(message)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.top, 8)
    }
}

/// Bandeau « Actualisation impossible » (`directoryStatus` d'Expo, état
/// `failed`) : les dernières métriques restent affichées, avec « Réessayer ».
struct AcctSearchRefreshBanner: View {
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            IonIcon(name: "cloud-offline-outline", size: 15, color: Theme.inkSoft)
            Text("Actualisation impossible : les dernières métriques disponibles sont affichées.")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: onRetry) {
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
            .accessibilityLabel("Réessayer d’actualiser le profil")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.top, 8)
    }
}

// MARK: - En-tête de la fiche ouverte

/// En-tête de la fiche publique ouverte (`showcase`, `socialActions`) : identité
/// publiée, blason de ligue, suivi, « Te suit », proposition de défi et menu de
/// sécurité.
struct AcctSearchMemberShowcase: View {
    let member: AcctSearchMember
    let followed: Bool
    let followsMe: Bool
    let canProposeChallenge: Bool
    /// Blocage en cours pour ce membre (`blockingMemberId === id`).
    let blocking: Bool
    /// Un blocage est en cours quelque part : « Bloquer » reste désactivé.
    let blockDisabled: Bool
    let premiumMessageVisible: Bool
    let onToggleFollow: () -> Void
    let onProposeChallenge: () -> Void
    let onTogglePremiumMessage: () -> Void
    let onBlock: () -> Void
    let onReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            identity
            if premiumMessageVisible && member.isPremium {
                Text("\(member.displayName) est un membre Premium.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            // Le prof IA n'est ni suivi, ni défié, ni bloqué : toute la barre
            // d'actions sociales est masquée (`AccountScreen.tsx:3018`).
            if !isProfIaProfileId(member.id) {
                actions
            }
        }
        .duelloCard()
    }

    /// Pseudo, pastille d'abonné et parcours publié, plus le blason de ligue.
    private var identity: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Text(member.displayName)
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(Theme.ink)
                    if member.isPremium {
                        Button(action: onTogglePremiumMessage) {
                            PremPremiumBadge(size: 18)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Afficher le statut Premium de \(member.displayName)")
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(pathLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
            if let badge = leagueBadgeURL {
                CachedRemoteImage(url: badge) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.clear
                }
                .frame(width: 56, height: 56)
                .accessibilityLabel("Ligue \(league.label) de \(member.displayName)")
            }
        }
    }

    /// Suivre / Suivi, « Te suit », proposition de défi et menu de sécurité.
    private var actions: some View {
        HStack(spacing: 8) {
            Button(action: onToggleFollow) {
                HStack(spacing: 6) {
                    IonIcon(name: followed ? "checkmark" : "add", size: 17, color: Theme.white)
                    Text(followed ? "Suivi" : "Suivre").lineLimit(1)
                }
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Theme.white)
                .frame(minHeight: 40)
                .padding(.horizontal, 12)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(followed ? "Ne plus suivre \(member.displayName)" : "Suivre \(member.displayName)")

            if followsMe {
                HStack(spacing: 5) {
                    IonIcon(name: "person-add-outline", size: 17, color: Theme.white)
                    Text("Te suit").lineLimit(1)
                }
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Theme.white)
                .frame(minHeight: 40)
                .padding(.horizontal, 12)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                .accessibilityLabel("\(member.displayName) te suit")
            }

            if canProposeChallenge {
                Button(action: onProposeChallenge) {
                    HStack(spacing: 6) {
                        IonIcon(name: "flash-outline", size: 17, color: Theme.white)
                        Text("Proposer un défi").lineLimit(1)
                    }
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.white)
                    .frame(minHeight: 40)
                    .padding(.horizontal, 12)
                    .background(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Proposer un défi à \(member.displayName)")
            }

            Spacer(minLength: 0)

            ReportSafetyMenu(
                blocking: blocking,
                disabled: blockDisabled,
                memberName: member.displayName,
                onBlock: onBlock,
                onReport: onReport
            )
        }
    }

    /// Filière, année et spécialité publiées, dans l'ordre d'Expo — ou, pour le
    /// prof IA, son rôle et son périmètre (`AccountScreen.tsx:2964-2974`).
    private var pathLines: [String] {
        if isProfIaProfileId(member.id) {
            return [PROF_IA_ROLE_LABEL, PROF_IA_SCOPE_LABEL]
        }
        return [member.track, member.year, member.specialty]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Elo publié, ou la cote initiale (`INITIAL_SUBJECT_ELO`) quand il manque.
    private var elo: Int {
        Int(max(0, (member.elo ?? Double(SocChallengeInvites.initialSubjectElo)).rounded()))
    }

    private var league: EloLeague { eloLeague(for: elo, track: member.track) }

    private var leagueBadgeURL: URL? { LeagueBadges.badgeURL(forLeague: league.id) }
}

// MARK: - Ligne de résultat

/// Ligne d'un résultat (`personResult`) : avatar et présence, pseudo, pastille
/// d'abonné, méta de programme, blason de ligue et bouton de suivi.
struct AcctSearchCandidateRow: View {
    let member: AcctSearchMember
    let online: Bool
    let followed: Bool
    let onSelect: () -> Void
    let onToggleFollow: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Button(action: onSelect) {
                HStack(spacing: 9) {
                    SocialAvatarPresence(online: online || isProfIaProfileId(member.id)) {
                        SocInviteAvatar(member: member.profile, size: 36)
                    }
                    copy
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voir le profil de \(member.displayName)")

            if let badge = leagueBadgeURL {
                AsyncImage(url: badge) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.clear
                }
                .frame(width: 34, height: 34)
                .accessibilityLabel("Ligue \(league.label) de \(member.displayName)")
            }

            // Le prof IA n'est ni suivi ni défié : pas de bouton de suivi
            // (`AccountScreen.tsx:2823`).
            if !isProfIaProfileId(member.id) {
                followButton
            }
        }
        .padding(.horizontal, 10)
        .frame(height: AcctSearchConstants.resultHeight)
    }

    /// `miniSocialButton` : suivi à un tap ; encadré neutre à l'arrêt, plein
    /// `primary` une fois suivi (`miniSocialButtonActive`, rayon 11).
    private var followButton: some View {
        Button(action: onToggleFollow) {
            IonIcon(
                name: followed ? "checkmark" : "add",
                size: 15,
                color: followed ? Theme.white : Theme.ink
            )
            .frame(width: 34, height: 34)
            .background(followed ? Theme.primary : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(followed ? Theme.primary : Color.clear, lineWidth: followed ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(followed ? "Ne plus suivre \(member.displayName)" : "Suivre \(member.displayName)")
    }

    /// Pseudo, pastille d'abonné et méta de programme.
    private var copy: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(member.displayName)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if member.isPremium { PremPremiumBadge(size: 13) }
            }
            Text(metaLine)
                .font(.system(size: 9))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
        }
    }

    /// `[filière, spécialité, « N Elo », « N XP », classe, prépa]` joints par « · » —
    /// ou, pour le prof IA, `rôle · périmètre` (`AccountScreen.tsx:2799-2801`).
    private var metaLine: String {
        if isProfIaProfileId(member.id) {
            return "\(PROF_IA_ROLE_LABEL) · \(PROF_IA_SCOPE_LABEL)"
        }
        return [
            member.track,
            member.specialty.trimmingCharacters(in: .whitespacesAndNewlines),
            "\(elo) Elo",
            "\(groupedNumber(Int(member.xp.rounded()))) XP",
            member.className,
            member.prepName,
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    /// Elo publié, ou la cote initiale (`INITIAL_SUBJECT_ELO`) quand il manque.
    private var elo: Int {
        Int(max(0, (member.elo ?? Double(SocChallengeInvites.initialSubjectElo)).rounded()))
    }

    /// Même famille de blasons que la fiche : la filière publiée prime.
    private var league: EloLeague { eloLeague(for: elo, track: member.track) }

    private var leagueBadgeURL: URL? { LeagueBadges.badgeURL(forLeague: league.id) }
}
