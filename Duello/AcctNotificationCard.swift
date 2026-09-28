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
//  V2 (28/09/2026, écarts 20 A2/B1 + typographie) : retour d'appui
//  (`pressed`, opacité 0,75), chevron Ionicons `chevron-forward` 17 (au lieu
//  d'un SF Symbol 15), icônes de type rendues par `IonIcon` (noms exacts du
//  RN), et titre `notificationTitle` 12/600 (l'acteur en 900) au lieu du rendu
//  par défaut 17.
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
                IonIcon(name: "chevron-forward", size: 17, color: Theme.inkFaint)
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
        .buttonStyle(AcctPressButtonStyle())
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
        IonIcon(name: iconName, size: 17, color: iconColor)
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

    /// `notificationTitle` : 12/600 encre, l’acteur en 900
    /// (`notificationActor`).
    private var title: Text {
        let base = Font.system(size: 12, weight: .semibold)
        if notification.kind == .annaleCorrectionReady {
            return Text("Ta correction de ").font(base)
                + Text(notification.title).font(.system(size: 12, weight: .black))
                + Text(" est prête · \(String(format: "%.1f", notification.score))/20").font(base)
        }
        return Text(notification.actorName).font(.system(size: 12, weight: .black))
            + Text(suffix).font(base)
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

    /// Nom Ionicons du type (`AccountScreen.tsx:2282-2305`), rendu par `IonIcon`.
    private var iconName: String {
        switch notification.kind {
        case .newFollower: return "person-add"
        case .annaleCorrectionReady: return "checkmark-circle"
        case .challengeUnavailable: return "flash"
        case .profileView: return "eye"
        case .performanceLike: return "heart"
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
