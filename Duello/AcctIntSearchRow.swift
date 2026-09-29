//
//  AcctIntSearchRow.swift
//  Duello
//
//  Ligne de recherche de l'onglet « Mon compte » (préfixe `AcctInt`).
//
//  Fichier source Expo porté : `src/screens/AccountScreen.tsx`, `searchRow`
//  — le champ « Nom, filière, spécialité, Elo ou XP… », la cloche des
//  notifications (`notifications` / `notifications-outline`, pastille du nombre
//  non lu, `:2628-2663`) et la roue des réglages (`settings-outline`).
//
//  Réutilise sans le recréer : `AcctSearchView` (champ, menu de résultats,
//  fiche publique) et lui ajoute l'accessoire de droite. La cloche et la roue
//  sont des `settingsIconButton` de la source : 40 × 40, bord 1, rayon 12.
//
//  V2 (28/09/2026, écarts 20 #4/B2 + A2) : la cloche bascule
//  `notifications` (plein) / `notifications-outline` selon
//  `AcctNotificationsStore.unreadCount` et porte la pastille du nombre non lu
//  (`notificationBadge`, « 9+ » au-delà de 9) ; retour d'appui `pressed`
//  (opacité 0,75) ; icônes rendues par `IonIcon` (noms exacts du RN).
//
//  V3 (29/09/2026, parité RN dev) : la cloche et la roue prennent le noir
//  absolu `#000000` en fond et en bord, et des symboles blancs
//  (`settingsIconButton`, `AccountScreen.tsx:4556-4564`) — `Theme.surface`,
//  `Theme.border` et `Theme.ink` y étaient erronés.
//
//  V3b (29/09/2026, parité RN dev) : `canProposeChallenge` n'est plus figé à
//  faux — il est calculé pour le membre ouvert, même formule
//  qu'`AcctIntDirectorySheet` (`canProposeChallengeToMember`,
//  `AccountScreen.tsx:1781-1784`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// `#000000` des styles `peopleSearchBar` / `settingsIconButton`
/// (`AccountScreen.tsx:4546-4564`) : noir absolu, distinct de `Theme.ink`.
private let acctSearchAbsoluteBlack = Color(hex: 0x000000)

/// Ligne de recherche du profil : champ, cloche des notifications, réglages.
@MainActor
struct AcctIntSearchRow: View {
    @EnvironmentObject private var session: SessionStore
    @ObservedObject var model: AcctSearchModel
    @ObservedObject private var notifications = AcctNotificationsStore.shared
    /// État de publication du profil à l'annuaire (`publication` d'Expo),
    /// transmis tel quel au bandeau d'état de la recherche.
    var publication: ReportDirectoryPublication? = nil
    let onOpenNotifications: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        AcctSearchView(
            model: model,
            canProposeChallenge: canProposeChallenge,
            onProposeChallenge: { _ in },
            publication: publication,
            rowAccessory: AnyView(accessories)
        )
    }

    /// `canProposeChallenge` (`AccountScreen.tsx:1781-1784`) : le membre ouvert
    /// partage le programme du compte (`!isMemberLocked` reste toujours vrai côté
    /// natif, cf. `AcctSearchModel.isMemberLocked`). Recalculé à chaque
    /// changement de membre ouvert — même formule qu'`AcctIntDirectorySheet`.
    private var canProposeChallenge: Bool {
        guard let member = model.selectedMember else { return false }
        return SocChallengeInvites.canProposeChallenge(
            to: member.profile,
            challengerTrack: session.profile.track,
            challengerSpecialty: ownSpecialty
        )
    }

    /// `ownSpecialty` (`AccountScreen.tsx:1773-1780`) :
    /// `accountAcademicOptionLabel(track, academicProgramSelection(...).specialty,
    /// specialty)`. L'option de l'année affichée vient de `academicPath`
    /// (`firstYearOption` en 1re année, `currentOption` sinon), avec repli sur la
    /// spécialité du profil pour les comptes anciens sans parcours détaillé.
    private var ownSpecialty: String {
        let profile = session.profile
        let option = profile.academicPath.map {
            profile.year == "1re année" ? $0.firstYearOption : $0.currentOption
        } ?? profile.specialty
        return LoginScrProviderReuse.accountAcademicOptionLabel(
            track: profile.track,
            currentOption: option,
            legacySpecialty: profile.specialty
        )
    }

    /// Les deux boutons carrés de droite (`searchRow` de la source).
    private var accessories: some View {
        HStack(spacing: 9) {
            notificationButton
            iconButton(icon: "settings-outline", label: "Ouvrir les paramètres", action: onOpenSettings)
        }
    }

    /// Cloche des notifications (`settingsIconButton` + `notificationBadge`).
    private var notificationButton: some View {
        Button(action: onOpenNotifications) {
            IonIcon(
                name: unread > 0 ? "notifications" : "notifications-outline",
                size: 20,
                color: Theme.white
            )
            .frame(width: 40, height: 40)
            .background(acctSearchAbsoluteBlack)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(acctSearchAbsoluteBlack, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if unread > 0 { badge }
            }
        }
        .buttonStyle(AcctPressButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    /// `notificationBadge` : fond `like`, min 17 × 17, rayon pilule, texte
    /// blanc 9/900, « 9+ » au-delà de neuf non-lues.
    private var badge: some View {
        Text(unread > 9 ? "9+" : "\(unread)")
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(Theme.white)
            .padding(.horizontal, 4)
            .frame(minWidth: 17, minHeight: 17)
            .background(Theme.like)
            .clipShape(Capsule())
            .padding(.top, 6)
            .padding(.trailing, 6)
    }

    /// Libellé a11y de la cloche (`AccountScreen.tsx:2630-2634`).
    private var accessibilityLabel: String {
        unread > 0
            ? "Ouvrir les notifications, \(unread) non lue\(unread > 1 ? "s" : "")"
            : "Ouvrir les notifications"
    }

    /// Nombre de notifications non lues, lu sur le magasin partagé.
    private var unread: Int { notifications.unreadCount }

    private func iconButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            IonIcon(name: icon, size: 20, color: Theme.white)
                .frame(width: 40, height: 40)
                .background(acctSearchAbsoluteBlack)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(acctSearchAbsoluteBlack, lineWidth: 1)
                )
        }
        .buttonStyle(AcctPressButtonStyle())
        .accessibilityLabel(label)
    }
}
