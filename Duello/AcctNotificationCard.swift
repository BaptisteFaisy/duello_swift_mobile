//
//  AcctNotificationCard.swift
//  Duello
//
//  Carte d’une notification du compte.
//
//  Fichier source Expo porté : `src/screens/AccountScreen.tsx:2258-2360`
//  (`notificationCard`, `notificationIcon`, `notificationCopy`, styles
//  `notificationCard` / `notificationCardUnread` / `notificationIcon` / …).
//
//  V1 (26/09/2026, écart 20#2) : extraite de `AcctIntNotificationsSheet` pour
//  rendre la liste réelle (carte non-lue, icône selon `kind`, pastille de
//  présence, texte par type, horodatage, chevron, tap → profil).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Une ligne de la liste des notifications.
struct AcctNotificationCard: View {
    let notification: AcctNotification
    /// Pastille de présence : vrai quand un profil vu est en ligne.
    let online: Bool
    let onOpenMember: (String) -> Void
    let onLeave: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 0) {
                icon
                copy
                    .padding(.leading, 11)
                    .padding(.trailing, 8)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(notification.read ? Theme.surface : Theme.likeLight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(notification.read ? Theme.border : Theme.like, lineWidth: 1)
            )
            .duelloShadow()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    /// `onPress` : ouvre le profil du membre (sauf correction prête), puis
    /// quitte la feuille (`openMember` + `leaveNotifications`).
    private func open() {
        if notification.kind != .annaleCorrectionReady {
            onOpenMember(notification.actorId)
        }
        onLeave()
    }

    /// `notificationIcon` : pastille 38 × 38 blanche, icône selon `kind`.
    private var icon: some View {
        Image(systemName: iconName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(iconColor)
            .frame(width: 38, height: 38)
            .background(Theme.white)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(alignment: .bottomTrailing) {
                SocOnlineDot(online: online)
            }
    }

    /// `copy` : titre (acteur en gras), texte de performance, horodatage.
    private var copy: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
            if showsPerformance {
                Text("\(notification.performanceLabel) · \(notification.performanceText)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(2)
                    .padding(.top, 3)
            }
            Text(AcctNotifications.formatTimeAgo(notification.createdAt))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `notificationTitle` : 12/600 encre, l’acteur en 900.
    private var title: Text {
        if notification.kind == .annaleCorrectionReady {
            return Text("Ta correction de ")
                + Text(notification.title).fontWeight(.black)
                + Text(" est prête · \(String(format: "%.1f", notification.score))/20")
        }
        return Text(notification.actorName).fontWeight(.black)
            + Text(suffix)
    }

    /// Fin de phrase selon `kind` (mot pour mot).
    private var suffix: String {
        switch notification.kind {
        case .newFollower: return " a commencé à te suivre"
        case .challengeUnavailable:
            return " t’a invité à un défi de \(notification.subject), mais tu étais déjà en défi"
        case .profileView: return " a vu ton profil"
        case .annaleCorrectionReady, .performanceLike: return " a aimé ta performance"
        }
    }

    /// Le texte de performance n’accompagne que le like reçu.
    private var showsPerformance: Bool {
        notification.kind == .performanceLike
    }

    /// `accessibilityLabel` : correction prête, sinon « Voir le profil de … ».
    private var accessibilityLabel: String {
        notification.kind == .annaleCorrectionReady
            ? "Correction prête pour \(notification.title)"
            : "Voir le profil de \(notification.actorName)"
    }

    /// Icône Ionicons → SF Symbol selon `kind`.
    private var iconName: String {
        switch notification.kind {
        case .newFollower: return "person.badge.plus"
        case .annaleCorrectionReady: return "checkmark.circle.fill"
        case .challengeUnavailable: return "bolt.fill"
        case .profileView: return "eye"
        case .performanceLike: return "heart.fill"
        }
    }

    /// Couleur de l’icône selon `kind` (couleurs `theme.ts`).
    private var iconColor: Color {
        switch notification.kind {
        case .newFollower, .profileView: return Theme.primary
        case .annaleCorrectionReady: return Theme.progress
        case .challengeUnavailable: return Theme.ink
        case .performanceLike: return Theme.like
        }
    }
}
