//
//  AcctSearchView.swift
//  Duello
//
//  Lot « AcctSearch » (10-D) — annuaire de recherche du compte : champ de
//  saisie, menu des résultats et assemblage de la fiche ouverte.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx (peopleSearchBar, peopleResults,
//                                     personResult, directoryStatus)
//    - src/components/PremiumBadge.tsx (« Compte abonné »)
//
//  Découpé de `AcctSearchModel.swift` et `AcctSearchMemberViews.swift` (règle
//  des 500 lignes) : l'état reste dans le modèle, ces vues ne font que le lire.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Champ de recherche

/// Champ « Nom, filière, spécialité, Elo ou XP… » (`peopleSearchBar`) : la
/// loupe, la saisie, et la croix d'effacement.
struct AcctSearchBar: View {
    @Binding var query: String
    /// Appelé au premier focus : ouvre le menu et affiche la première page.
    let onFocus: () -> Void
    let onClear: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)

            TextField(AcctSearchSettings.placeholder, text: $query)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
                .onChange(of: focused) { isFocused in
                    if isFocused { onFocus() }
                }
                .accessibilityLabel("Rechercher par nom, filière, spécialité, Elo ou XP")

            if !query.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.inkFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Message d'état

/// Message du menu (`noPeopleResult`, `directoryErrorBox`) : recherche en cours,
/// annuaire injoignable, aucun profil.
struct AcctSearchMessage: View {
    let icon: String?
    let text: String
    let retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let retry {
                Button(action: retry) {
                    Text("Réessayer")
                        .font(.system(size: 12, weight: .heavy))
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
        HStack(spacing: 10) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    SocialAvatarPresence(online: online) {
                        SocInviteAvatar(member: member.profile, size: 38)
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
                .frame(width: 24, height: 24)
                .accessibilityLabel("Ligue \(league.label) de \(member.displayName)")
            }

            Button(action: onToggleFollow) {
                Image(systemName: followed ? "checkmark" : "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(followed ? Theme.surface : Theme.ink)
                    .frame(width: 30, height: 30)
                    .background(followed ? Theme.ink : Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(followed ? "Ne plus suivre \(member.displayName)" : "Suivre \(member.displayName)")
        }
        .padding(.horizontal, 6)
        .frame(minHeight: AcctSearchConstants.resultHeight)
    }

    /// Pseudo, pastille d'abonné et méta de programme.
    private var copy: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(member.displayName)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if member.isPremium { PremPremiumBadge(size: 13) }
            }
            Text(metaLine)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
        }
    }

    /// `[filière, spécialité, « N Elo », « N XP », classe, prépa]` joints par « · ».
    private var metaLine: String {
        [
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

// MARK: - Menu des résultats

/// Menu des résultats (`peopleResults`) : recherche en cours, annuaire
/// injoignable, aucun profil, ou la liste des candidats.
struct AcctSearchResultsMenu: View {
    let results: [AcctSearchMember]
    let searching: Bool
    let errorMessage: String?
    let loadingMore: Bool
    let hasSearchQuery: Bool
    let hasMore: Bool
    let followedIds: [String]
    let scrollHeight: CGFloat
    let onRetry: () -> Void
    let onSelect: (AcctSearchMember) -> Void
    let onToggleFollow: (AcctSearchMember) -> Void
    let onLoadMore: () -> Void

    @ObservedObject private var presence = SocPresenceStore.shared

    var body: some View {
        Group {
            if searching {
                AcctSearchMessage(icon: nil, text: "Recherche en cours…", retry: nil)
            } else if let errorMessage {
                AcctSearchMessage(icon: "icloud.slash", text: errorMessage, retry: onRetry)
            } else if results.isEmpty {
                AcctSearchMessage(
                    icon: nil,
                    text: "Aucun profil ne correspond à cette recherche. Ton amie n’apparaît qu’une fois qu’elle a ouvert Duello avec son compte, sur cette même version de l’application.",
                    retry: nil
                )
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.top, 6)
    }

    /// Liste bornée en hauteur : cinq lignes visibles, le reste défile.
    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(results) { member in
                    AcctSearchCandidateRow(
                        member: member,
                        online: presence.isOnline(member.id),
                        followed: followedIds.contains(member.id),
                        onSelect: { onSelect(member) },
                        onToggleFollow: { onToggleFollow(member) }
                    )
                    Divider().padding(.leading, 48)
                }

                if !hasSearchQuery && loadingMore {
                    HStack(spacing: 8) {
                        ProgressView().tint(Theme.inkSoft)
                        Text("Chargement des profils suivants…")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.vertical, 12)
                }

                // Sentinelle de bas de liste : demande la page suivante à
                // l'approche du bas, comme le `onScroll` d'Expo.
                if !hasSearchQuery && hasMore && !loadingMore {
                    Color.clear
                        .frame(height: 1)
                        .onAppear { onLoadMore() }
                }
            }
            .accessibilityLabel("Résultats de recherche")
        }
        .frame(maxHeight: scrollHeight)
    }
}

// MARK: - Annuaire de recherche

/// Annuaire de recherche de l'onglet « Mon compte » : champ, menu des résultats
/// et fiche publique du membre sélectionné. Le modèle est créé par l'appelant
/// (`AcctSearchModel`) et partagé ; le jeton vient de `SessionStore`.
struct AcctSearchView: View {
    @EnvironmentObject private var session: SessionStore
    @ObservedObject var model: AcctSearchModel

    /// Ouvre la préparation d'un défi depuis la fiche consultée.
    let canProposeChallenge: Bool
    let onProposeChallenge: (AcctSearchMember) -> Void
    let onBlock: (AcctSearchMember) -> Void
    let onReport: (AcctSearchMember) -> Void
    /// Accessoire de droite de la ligne de recherche. L'onglet « Mon compte »
    /// y place la cloche des notifications et la roue des réglages
    /// (`searchRow` de `AccountScreen.tsx`, l. 2404-2516) ; la feuille
    /// « Annuaire » n'en met aucun.
    var rowAccessory: AnyView? = nil

    @State private var premiumMessageVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                AcctSearchBar(
                    query: $model.query,
                    onFocus: { model.openSearchMenu() },
                    onClear: { model.query = "" }
                )
                if let rowAccessory {
                    rowAccessory
                }
            }

            if model.menuOpen {
                AcctSearchResultsMenu(
                    results: model.searchResults,
                    searching: model.searching,
                    errorMessage: model.errorMessage,
                    loadingMore: model.loadingMore,
                    hasSearchQuery: model.hasSearchQuery,
                    hasMore: AcctSearchBrowseCache.shared.hasMore,
                    followedIds: model.followedIds,
                    scrollHeight: model.resultsScrollHeight,
                    onRetry: { model.attempt += 1 },
                    onSelect: { model.openMember($0.id) },
                    onToggleFollow: { model.toggleFollow($0.id) },
                    onLoadMore: { Task { await model.loadMoreDirectory(token: session.token) } }
                )
            }

            if let selected = model.selectedMember {
                AcctSearchMemberShowcase(
                    member: selected,
                    followed: model.isFollowed(selected.id),
                    followsMe: model.selectedFollowsMe,
                    canProposeChallenge: canProposeChallenge,
                    premiumMessageVisible: premiumMessageVisible,
                    onToggleFollow: { model.toggleFollow(selected.id) },
                    onProposeChallenge: { onProposeChallenge(selected) },
                    onTogglePremiumMessage: { premiumMessageVisible.toggle() },
                    onBlock: { onBlock(selected) },
                    onReport: { onReport(selected) }
                )
            } else if model.selectedMemberId != nil {
                AcctSearchProfileStatus(
                    failed: model.selectedProfileState == .failed,
                    onRetry: { model.selectedProfileAttempt += 1 }
                )
            }
        }
        .onAppear { model.ownEmail = session.profile.email }
        .task(id: model.searchTaskId) {
            await model.runSearch(token: session.token)
        }
        .task(id: model.selectedProfileTaskId) {
            // `selectedMemberId` est isolé au fil principal (`@MainActor` sur
            // `AcctSearchModel`) : `.task` forme une fermeture `@Sendable`, qui
            // n'hérite pas de l'isolation du `body`. Sans `await`, la lecture
            // ne compile pas.
            let memberId = await model.selectedMemberId
            guard memberId != nil else { return }
            await model.refreshSelectedProfile(token: session.token)
            // La fiche reste resynchronisée tant qu'elle est ouverte.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: AcctSearchSettings.selectedProfileRefreshNanoseconds)
                guard !Task.isCancelled else { return }
                await model.refreshSelectedProfile(token: session.token)
            }
        }
        .onChange(of: model.selectedMemberId) { _ in premiumMessageVisible = false }
    }
}
