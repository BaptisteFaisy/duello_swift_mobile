//
//  AcctIntNotificationsSheet.swift
//  Duello
//
//  Feuille « Notifications », ouverte par la cloche de la ligne de recherche de
//  l'onglet « Mon compte » (préfixe `AcctInt`).
//
//  Fichier source Expo porté : `src/screens/AccountScreen.tsx`, branche
//  `page === 'notifications'` (l. 2047-2277) :
//    - en-tête : retour 38 × 38 + onglets soulignés `Notifications` / `Amis` ;
//    - page `notifications` : la carte de réglages (`NotificationSettingsCard`)
//      puis la liste des notifications, ou son état vide ;
//    - page `amis` : segmented control `Followers` / `Followings` et état vide ;
//    - balayage horizontal entre les trois pages
//      (`InstalledNotificationsPager` + `NOTIFICATIONS_SWIPE_PAGES`).
//
//  Repli documenté : les listes Followers / Followings ne sont pas exposées
//  localement (aucun store de graphe social côté iOS) ; l’onglet `Amis`
//  affiche donc l’état vide.
//
//  V1 (26/09/2026, écart 20#2) : la vraie liste des notifications
//  (`AcctNotificationsStore`) est rendue avant l’état vide
//  (`AccountScreen.tsx:2258-2360`) : carte non-lue, icône selon `kind`,
//  pastille de présence, texte par type, `formatTimeAgo`, chevron ; le tap
//  ouvre le profil du membre puis referme la feuille (`openMember` +
//  `leaveNotifications`, qui marque tout lu).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Feuille « Notifications » : réglages, notifications et onglets Amis, sur
/// trois pages balayables (`notifications`, `followers`, `followings`).
///
/// `@MainActor` : la vue possède le magasin partagé, isolé au fil principal —
/// même motif que `AccountView` / `AcctIntDirectorySheet`.
@MainActor
struct AcctIntNotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @StateObject private var notificationStore = NotificationPreferencesStore()
    @ObservedObject private var notifications = AcctNotificationsStore.shared
    @ObservedObject private var presence = SocPresenceStore.shared
    @State private var page: SwipeNotificationsPage = .notifications
    /// `openMember` : ouvre la fiche du membre touché. La feuille se referme
    /// elle-même (`leaveNotifications`), puis le compte marque tout lu.
    var onOpenMember: (String) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    content
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .simultaneousGesture(swipeGesture)
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await refreshNotifications() }
    }

    // MARK: En-tête

    /// En-tête : retour 38 × 38 puis les deux onglets soulignés
    /// (`settingsHeader` / `settingsTabs` de la source).
    private var header: some View {
        HStack(spacing: 0) {
            backButton
            HStack(spacing: 8) {
                headerTab("Notifications", selected: page == .notifications) {
                    page = .notifications
                }
                headerTab("Amis", selected: page != .notifications) {
                    page = .followers
                }
            }
            .padding(.leading, 10)
        }
        .padding(.bottom, 12)
    }

    /// Retour : chevron 21 pt dans une boîte 38 × 38 blanche, sans bord
    /// (`BackButton` + `styles.settingsBackButton`).
    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
                .background(Theme.white)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Retour au profil")
    }

    /// Un onglet de tête : libellé 13/800, encre si choisi, trait bas de 2 pt
    /// (`settingsTab` / `selectedSettingsTab`).
    private func headerTab(
        _ label: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(selected ? Theme.ink : Theme.inkFaint)
                .frame(maxWidth: .infinity, minHeight: 38)
                .contentShape(Rectangle())
                .overlay(
                    Rectangle()
                        .fill(selected ? Theme.ink : Color.clear)
                        .frame(height: 2),
                    alignment: .bottom
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: Contenu

    /// La page courante : réglages puis liste, ou onglets Amis.
    @ViewBuilder
    private var content: some View {
        switch page {
        case .notifications:
            NotificationSettingsCard(store: notificationStore)
            if notifications.notifications.isEmpty {
                notificationsEmpty
            } else {
                notificationList
            }
        case .followers, .followings:
            friendsBlock
        }
    }

    /// `leaveNotifications` : referme la feuille et marque tout lu.
    private func leaveNotifications() {
        notifications.markAllRead()
        dismiss()
    }

    /// Au montage : aligne le magasin sur le compte, relit le stockage puis le
    /// serveur (`loadNotifications` + `mergeRemoteNotifications`).
    private func refreshNotifications() async {
        await notifications.configure(accountId: AcctNotifications.accountId(email: session.profile.email))
        await notifications.reload()
        await notifications.syncRemote(email: session.profile.email, token: session.token)
    }

    /// La liste des notifications (`AccountScreen.tsx:2258-2360`) : cartes
    /// presse-papier, `gap: 9`.
    private var notificationList: some View {
        VStack(spacing: 9) {
            ForEach(notifications.notifications) { notification in
                AcctNotificationCard(
                    notification: notification,
                    online: notification.kind == .profileView
                        && presence.isOnline(notification.actorId),
                    onOpenMember: onOpenMember,
                    onLeave: leaveNotifications
                )
            }
        }
        .padding(.top, 12)
    }

    /// Page `Amis` : segmented control Followers / Followings puis état vide
    /// (`friendsTabs` / `renderFriendList` de la source).
    private var friendsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                friendTab(.followers, label: "Followers")
                friendTab(.followings, label: "Followings")
            }
            .padding(2)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(page == .followings ? "Tu ne suis encore personne." : "Aucun follower pour le moment.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 18)
                .padding(.horizontal, 4)
        }
    }

    /// Un onglet Amis (`friendTab` / `selectedFriendTab`) : flex 1, 30 pt de
    /// haut, rayon 10, fond d'encre quand il est choisi.
    private func friendTab(_ target: SwipeNotificationsPage, label: String) -> some View {
        let selected = page == target
        return Button { page = target } label: {
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(selected ? Theme.surface : Theme.mutedSurfaceText)
                .frame(maxWidth: .infinity, minHeight: 30)
                .padding(.horizontal, 4)
                .background(selected ? Theme.ink : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// État vide de la liste des notifications (`notificationEmpty`) : cœur,
    /// titre et message selon la visibilité du profil.
    private var notificationsEmpty: some View {
        VStack(spacing: 0) {
            Image(systemName: "heart")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Text("Aucune notification")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.ink)
                .padding(.top, 12)
            Text(
                session.profile.isPublic
                    ? "Tu seras prévenu ici pour tes nouveaux abonnés, tes likes et les défis reçus pendant que tu joues."
                    : "Tu seras prévenu ici pour tes nouveaux abonnés et les défis reçus pendant que tu joues."
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 22)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .duelloShadow()
        .padding(.top, 12)
    }

    // MARK: Balayage

    /// Navigation par balayage horizontal entre les trois pages, dans l'ordre
    /// `notifications`, `followers`, `followings` (`resolveNotificationsTabSwipe`) :
    /// glisser vers la gauche avance, vers la droite recule et ferme depuis la
    /// première page.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                guard let target = SwipeNotificationsTabs.resolve(
                    currentPage: page,
                    translationX: value.translation.width,
                    velocityX: value.predictedEndTranslation.width
                ) else { return }
                switch target {
                case .page(let next):
                    withAnimation(.easeInOut(duration: 0.2)) { page = next }
                case .back:
                    dismiss()
                }
            }
    }
}
