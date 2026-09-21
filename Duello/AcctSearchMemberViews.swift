//
//  AcctSearchMemberViews.swift
//  Duello
//
//  Lot « AcctSearch » (10-D) — fiche publique du membre sélectionné : carte
//  d'attente et en-tête (identité publiée, blason, actions sociales).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx (lockedCard, showcase, socialActions,
//                                     directoryStatus)
//    - src/components/PremiumBadge.tsx (« Compte abonné »)
//
//  Découpé de `AcctSearchView.swift` (règle des 500 lignes) : aucun type ni
//  libellé renommé.
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
                Image(systemName: "icloud.slash")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                ProgressView().tint(Theme.ink)
            }
            Text(failed ? "Profil indisponible" : "Actualisation du profil…")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text(failed
                 ? "Les performances n’ont pas pu être relues pour le moment."
                 : "Les dernières métriques publiées sont en cours de chargement.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if failed {
                Button(action: onRetry) {
                    Text("Réessayer")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 18)
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

// MARK: - En-tête de la fiche ouverte

/// En-tête de la fiche publique ouverte (`showcase`, `socialActions`) : identité
/// publiée, blason de ligue, suivi, « Te suit », proposition de défi et menu de
/// sécurité.
struct AcctSearchMemberShowcase: View {
    let member: AcctSearchMember
    let followed: Bool
    let followsMe: Bool
    let canProposeChallenge: Bool
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
            actions
        }
        .duelloCard()
    }

    /// Pseudo, pastille d'abonné et parcours publié, plus le blason de ligue.
    private var identity: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.ink)
                    if member.isPremium {
                        Button(action: onTogglePremiumMessage) {
                            PremPremiumBadge(size: 16)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Afficher le statut Premium de \(member.displayName)")
                    }
                }
                ForEach(pathLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer(minLength: 0)
            if let badge = leagueBadgeURL {
                AsyncImage(url: badge) { image in
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
                    Image(systemName: followed ? "checkmark" : "plus")
                    Text(followed ? "Suivi" : "Suivre").lineLimit(1)
                }
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.surface)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(followed ? "Ne plus suivre \(member.displayName)" : "Suivre \(member.displayName)")

            if followsMe {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus")
                    Text("Te suit").lineLimit(1)
                }
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.surface)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(Theme.inkSoft)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                .accessibilityLabel("\(member.displayName) te suit")
            }

            if canProposeChallenge {
                Button(action: onProposeChallenge) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt")
                        Text("Proposer un défi").lineLimit(1)
                    }
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.surface)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 14)
                    .background(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Proposer un défi à \(member.displayName)")
            }

            Spacer(minLength: 0)

            ReportSafetyMenu(
                blocking: false,
                disabled: false,
                memberName: member.displayName,
                onBlock: onBlock,
                onReport: onReport
            )
        }
    }

    /// Filière, année et spécialité publiées, dans l'ordre d'Expo.
    private var pathLines: [String] {
        [member.track, member.year, member.specialty]
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
