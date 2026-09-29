//
//  AcctIntNotificationsSheet.swift
//  Duello
//
//  Feuille « Notifications », ouverte par la cloche de la ligne de recherche de
//  l'onglet « Mon compte » (préfixe `AcctInt`).
//
//  Fichier source Expo porté : `src/screens/AccountScreen.tsx`, branche
//  `page === 'notifications'` (l. 2141-2385) :
//    - en-tête : retour 38 × 38 + onglets soulignés `Notifications` / `Amis` ;
//    - page `notifications` : la carte de réglages (`NotificationSettingsCard`)
//      puis la liste des notifications, ou son état vide ;
//    - page `amis` : segmented control `Followers` / `Followings` puis la liste
//      d'amis (`renderFriendList`) ou son message d'état vide ;
//    - balayage horizontal entre les trois pages, sans animation
//      (`InstalledNotificationsPager` + `OrderedTabPager`, `animated={false}`).
//
//  V1 (26/09/2026, écart 20#2) : la vraie liste des notifications
//  (`AcctNotificationsStore`) est rendue avant l'état vide ; le tap ouvre le
//  profil du membre puis referme la feuille (`leaveNotifications`).
//
//  V2 (28/09/2026, écarts 20 #3/#5/#6/#7 + A1/A2) : listes Followers /
//  Followings portées (`AcctNotificationsFriendList`), phrase « les visites de
//  ton profil » rétablie dans l'état vide, `isGuest` transmis à la carte de
//  réglages, pager enveloppé par `InstalledNotificationsPager`, retour et
//  balayage-arrière marquant tout lu (`leaveNotifications`), balayage sans
//  animation (comme `animated={false}`), retour d'appui `pressed` sur les
//  onglets, icônes `IonIcon`.
//
//  V3 (29/09/2026, écart 20#2) : la source de données des listes Amis est
//  alimentée au montage de la feuille — abonnements locaux
//  (`preapp-social-state`), abonnés du serveur (`fetchSocialGraph`,
//  `GET /follows`) et profils relus dans l'annuaire
//  (`fetchSocialProfilesByIds`), puis relance toutes les 30 s, comme
//  `syncSocialState` de `AccountScreen.tsx:1186-1247`. Les valeurs reçues du
//  modèle de recherche restent le repli tant que le graphe n'est pas chargé.
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
    /// Sous-section mémorisée de l'onglet « Amis » (`friendsSection`,
    /// `AccountScreen.tsx:725`) : revenir sur « Amis » rouvre la dernière
    /// section consultée au lieu de forcer Followers (écart #49).
    @State private var friendsSection: SwipeNotificationsPage = .followers
    /// Graphe social relu au montage puis toutes les 30 s (écart 20#2) :
    /// identifiants des abonnés/abonnements et profils de l'annuaire.
    @State private var socialDirectory: [AcctSearchMember] = []
    @State private var socialFollowerIds: [String] = []
    @State private var socialFollowedIds: [String] = []
    @State private var socialGraphLoaded = false
    /// `openMember` : ouvre la fiche du membre touché. La feuille se referme
    /// elle-même (`leaveNotifications`), puis le compte marque tout lu.
    var onOpenMember: (String) -> Void = { _ in }
    /// Graphe social publié par le lot « Social » : profils connus, identifiants
    /// des abonnés et des abonnements (`knownProfiles`, `followerIds`,
    /// `followedIds` de `AccountScreen.tsx`). **Repli** depuis l'écart 20#2 : la
    /// feuille relit désormais le graphe elle-même (`refreshSocialGraph`), ces
    /// valeurs ne servent que tant que la lecture n'a pas abouti.
    var knownProfiles: [AcctSearchMember] = []
    var followerIds: [String] = []
    var followedIds: [String] = []
    /// `toggleFollow` : bascule le suivi d'un membre depuis la liste d'amis.
    var onToggleFollow: (String) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            InstalledNotificationsPager {
                pager
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await refreshNotifications()
            await refreshSocialGraph()
            // Relance toutes les 30 s (`AccountScreen.tsx:1204-1211`), jusqu'à
            // la fermeture de la feuille (`.task` annulé au retrait).
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if Task.isCancelled { break }
                await refreshSocialGraph()
            }
        }
    }

    /// Le pager des trois pages (équivalent du `OrderedTabPager` de la source,
    /// posé sans animation — `animated={false}`).
    private var pager: some View {
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
                    page = friendsSection
                }
            }
            .padding(.leading, 10)
        }
        .padding(.bottom, 12)
    }

    /// Retour : chevron `chevron-back` 21 pt dans une boîte 38 × 38 blanche,
    /// sans bord (`BackButton` + `styles.settingsBackButton`) ; il quitte la
    /// feuille **et** marque tout lu (`leaveNotifications`).
    private var backButton: some View {
        Button { leaveNotifications() } label: {
            IonIcon(name: "chevron-back", size: 21, color: Theme.ink)
                .frame(width: 38, height: 38)
                .background(Theme.white)
                .contentShape(Rectangle())
        }
        .buttonStyle(AcctPressButtonStyle())
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
        .buttonStyle(AcctPressButtonStyle())
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: Contenu

    /// La page courante : réglages puis liste, ou onglets Amis.
    @ViewBuilder
    private var content: some View {
        switch page {
        case .notifications:
            NotificationSettingsCard(store: notificationStore, isGuest: !session.isSignedIn)
            if notifications.notifications.isEmpty {
                notificationsEmpty
            } else {
                notificationList
            }
        case .followers, .followings:
            friendsBlock
        }
    }

    /// `leaveNotifications` : referme la feuille et marque tout lu
    /// (`AccountScreen.tsx:729-732`).
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

    /// Page `Amis` : segmented control Followers / Followings puis la liste
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

            AcctNotificationsFriendList(
                members: page == .followings ? followings : followers,
                emptyMessage: page == .followings
                    ? "Tu ne suis encore personne."
                    : "Aucun follower pour le moment.",
                followedIds: effectiveFollowedIds,
                onOpenMember: onOpenMember,
                onToggleFollow: onToggleFollow
            )
        }
    }

    /// Abonnés : profils dont l'identifiant est dans `followerIds`
    /// (`myFollowers` = `followerProfiles(knownProfiles, followerIds)`).
    private var followers: [AcctSearchMember] {
        AcctNotificationsFriends.profiles(effectiveKnownProfiles, ids: effectiveFollowerIds)
    }

    /// Abonnements : même filtre sur `followedIds` (`myFollowings`).
    private var followings: [AcctSearchMember] {
        AcctNotificationsFriends.profiles(effectiveKnownProfiles, ids: effectiveFollowedIds)
    }

    /// Abonnés effectifs : le graphe relu au montage prime, sinon le repli reçu
    /// du modèle de recherche (jamais alimenté tant que le lot « Social » n'est
    /// pas câblé — cf. en-tête).
    private var effectiveFollowerIds: [String] {
        socialGraphLoaded ? socialFollowerIds : followerIds
    }

    /// Abonnements effectifs : idem, sur `followedIds`.
    private var effectiveFollowedIds: [String] {
        socialGraphLoaded ? socialFollowedIds : followedIds
    }

    /// Profils connus : l'annuaire du graphe prime, les ébauches de la recherche
    /// ne doivent jamais écraser une fiche complète (même fusion que
    /// `AcctSearchModel.knownProfiles`).
    private var effectiveKnownProfiles: [AcctSearchMember] {
        var merged: [String: AcctSearchMember] = [:]
        for member in socialDirectory { merged[member.id] = member }
        for member in knownProfiles where merged[member.id] == nil { merged[member.id] = member }
        return Array(merged.values)
    }

    /// Relit le graphe social du compte (`syncSocialState` +
    /// `fetchSocialProfilesByIds`, `AccountScreen.tsx:1186-1247`) : abonnements
    /// locaux, abonnés du serveur, puis profils de l'annuaire.
    private func refreshSocialGraph() async {
        let email = session.profile.email
        socialFollowedIds = AcctNotificationsSocialGraph.localFollowedIds(email: email)
        if let graph = await AcctNotificationsSocialGraph.remote(email: email, token: session.token) {
            socialFollowerIds = graph.followerIds ?? []
        }
        let ids = Array(Set(socialFollowerIds + socialFollowedIds))
        socialDirectory = ids.isEmpty
            ? []
            : ((try? await AcctSearchDirectory.profilesByIds(ids, token: session.token)) ?? [])
        socialGraphLoaded = true
    }

    /// Un onglet Amis (`friendTab` / `selectedFriendTab`) : flex 1, 30 pt de
    /// haut, rayon 10, fond d'encre quand il est choisi. Mémorise la
    /// sous-section (`setFriendsSection` + `setNotificationsTab('friends')`).
    private func friendTab(_ target: SwipeNotificationsPage, label: String) -> some View {
        let selected = page == target
        return Button {
            friendsSection = target
            page = target
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(selected ? Theme.white : Theme.mutedSurfaceText)
                .frame(maxWidth: .infinity, minHeight: 30)
                .padding(.horizontal, 4)
                .background(selected ? Theme.primary : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(AcctPressButtonStyle())
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// État vide de la liste des notifications (`notificationEmpty`) : cœur,
    /// titre et message selon la visibilité du profil.
    private var notificationsEmpty: some View {
        VStack(spacing: 0) {
            IonIcon(name: "heart-outline", size: 26, color: Theme.inkFaint)
            Text("Aucune notification")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.ink)
                .padding(.top, 12)
            Text(
                session.profile.isPublic
                    ? "Tu seras prévenu ici pour tes nouveaux abonnés, les visites de ton profil, tes likes et les défis reçus pendant que tu joues."
                    : "Tu seras prévenu ici pour tes nouveaux abonnés, les visites de ton profil et les défis reçus pendant que tu joues."
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
    /// première page. La transition est **instantanée** (`animated={false}` de
    /// `AccountScreen.tsx:2146`) ; le retour marque tout lu.
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
                    if next != .notifications { friendsSection = next }
                    page = next
                case .back:
                    leaveNotifications()
                }
            }
    }
}

// MARK: - Graphe social du compte

/// Sync du graphe social (`AccountScreen.tsx:977,1186-1247`) : abonnements
/// locaux (`preapp-social-state`), abonnés du serveur (`fetchSocialGraph`,
/// `GET /follows`) et profils relus dans l'annuaire.
enum AcctNotificationsSocialGraph {
    /// `SOCIAL_STATE_KEY` de `data/socialProfiles.ts`.
    static let stateKey = "prepapp-social-state"

    /// Réponse de `GET /follows?userId=…` (`SocialGraph` de `socialApi.ts`).
    struct RemoteGraph: Decodable {
        var followerIds: [String]?
        var followingIds: [String]?
    }

    /// État social local (`{ followedIds: […] }`).
    private struct LocalState: Decodable {
        var followedIds: [String]?
    }

    /// Abonnements locaux (`SOCIAL_STATE_KEY` → `followedIds`) : la source les
    /// relit dans le stockage du compte au montage (`AccountScreen.tsx:973`).
    static func localFollowedIds(email: String) -> [String] {
        let accountId = SessionStore.localAccountId(for: email)
        guard let key = try? RewStorageScope.accountStorageKey(
            accountId: accountId, logicalKey: stateKey),
              let raw = UserDefaults.standard.string(forKey: key),
              let data = raw.data(using: .utf8),
              let state = try? JSONDecoder().decode(LocalState.self, from: data)
        else { return [] }
        return state.followedIds ?? []
    }

    /// `fetchSocialGraph` : qui me suit, tel que le serveur l'a enregistré.
    static func remote(email: String, token: String?) async -> RemoteGraph? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let userId = DuelloAPI.publicProfileId(email: trimmed)
        guard let data = try? await DuelloAPI.request(
            "/follows",
            token: token,
            query: [URLQueryItem(name: "userId", value: userId)]
        ) else { return nil }
        return try? DuelloAPI.decoder.decode(RemoteGraph.self, from: data)
    }
}
