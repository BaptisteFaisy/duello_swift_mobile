//
//  AcctSearchView.swift
//  Duello
//
//  Lot « AcctSearch » (10-D) — annuaire de recherche du compte : champ de
//  saisie, menu des résultats et assemblage de la fiche ouverte.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx (peopleSearchBar, peopleResults,
//                                     directoryStatus, backToMineButton
//                                     « Mon profil », requestBlockMember,
//                                     reportMember)
//    - src/components/PremiumBadge.tsx (« Compte abonné »)
//    - src/components/UserReportModal.tsx (feuille de signalement)
//    - src/components/ProfileSafetyMenu.tsx (menu de sécurité)
//
//  La ligne de résultat (`personResult`) vit dans `AcctSearchMemberViews.swift`
//  depuis le lot V2 (règle des 500 lignes).
//
//  Découpé de `AcctSearchModel.swift` et `AcctSearchMemberViews.swift` (règle
//  des 500 lignes) : l'état reste dans le modèle, ces vues ne font que le lire.
//
//  Écarts assumés (2026-09-29)
//  ---------------------------
//  - Invite du champ : le libellé d'accessibilité est aligné sur la source
//    (« Rechercher par Elo ou XP », `AccountScreen.tsx:2617`) ; la **chaîne
//    affichée** vient de `AcctSearchSettings.placeholder`
//    (`AcctSearchDirectory.swift`, fichier d'un autre lot) — à raccorder.
//  - Barre en noir absolu : la cloche et la roue de la ligne de recherche
//    (`AcctIntSearchRow.swift`, autre lot) restent à passer en noir ; ici seule
//    la barre (`AcctSearchBar`) l'est.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Champ de recherche

/// Champ « Elo ou XP… » (`peopleSearchBar`) : la loupe, la saisie, et la croix
/// d'effacement. Barre en noir absolu à symboles blancs (`423b1039c` côté dev,
/// `AccountScreen.tsx:4552-4564,2587,2637`) : fond et bord `#000000`, loupe et
/// croix `colors.white`, saisie blanche, invite `rgba(255,255,255,0.55)`.
struct AcctSearchBar: View {
    @Binding var query: String
    /// Appelé au premier focus : ouvre le menu et affiche la première page.
    let onFocus: () -> Void
    let onClear: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            IonIcon(name: "search", size: 19, color: Theme.white)

            ZStack(alignment: .leading) {
                if query.isEmpty {
                    Text(AcctSearchSettings.placeholder)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.white.opacity(0.55))
                        .allowsHitTesting(false)
                }
                TextField("", text: $query)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                    .onChange(of: focused) { isFocused in
                        if isFocused { onFocus() }
                    }
                    .accessibilityLabel("Rechercher par Elo ou XP")
            }

            if !query.isEmpty {
                Button(action: onClear) {
                    IonIcon(name: "close-circle", size: 19, color: Theme.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Color.black, lineWidth: 1)
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
                IonIcon(name: icon, size: 19, color: Theme.inkSoft)
            }
            Text(text)
                .font(.system(size: 11))
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
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
    }
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
                AcctSearchMessage(icon: "cloud-offline-outline", text: errorMessage, retry: onRetry)
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
        .padding(.top, 8)
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

/// Alerte en cours de l'annuaire : confirmation de blocage, retour de blocage
/// ou accusé de signalement (`Alert.alert` d'`AccountScreen.tsx`).
private enum AcctSearchAlert: Identifiable {
    case confirmBlock(AcctSearchMember)
    case blocked(String)
    case blockFailed(String)
    case reportSent

    var id: String {
        switch self {
        case .confirmBlock(let member): return "confirm-\(member.id)"
        case .blocked(let name): return "blocked-\(name)"
        case .blockFailed: return "block-failed"
        case .reportSent: return "report-sent"
        }
    }
}

/// Annuaire de recherche de l'onglet « Mon compte » : champ, menu des résultats
/// et fiche publique du membre sélectionné. Le modèle est créé par l'appelant
/// (`AcctSearchModel`) et partagé ; le jeton vient de `SessionStore`.
struct AcctSearchView: View {
    @EnvironmentObject private var session: SessionStore
    @ObservedObject var model: AcctSearchModel

    /// Ouvre la préparation d'un défi depuis la fiche consultée.
    let canProposeChallenge: Bool
    let onProposeChallenge: (AcctSearchMember) -> Void
    /// État de publication du profil à l'annuaire (`publication` d'Expo) : `nil`
    /// tant qu'aucune publication n'a été tentée. Le bandeau d'état s'affiche
    /// dès que le profil n'est pas publié.
    var publication: ReportDirectoryPublication? = nil
    /// Accessoire de droite de la ligne de recherche. L'onglet « Mon compte »
    /// y place la cloche des notifications et la roue des réglages
    /// (`searchRow` de `AccountScreen.tsx`, l. 2404-2516) ; la feuille
    /// « Annuaire » n'en met aucun.
    var rowAccessory: AnyView? = nil

    @State private var premiumMessageVisible = false
    /// Membre visé par le signalement en cours (`reportedMember`).
    @State private var reportTarget: AcctSearchMember?
    /// Vrai quand le signalement vient d'aboutir : l'accusé s'affiche à la
    /// fermeture de la feuille (`reportMember` d'Expo).
    @State private var reportSucceeded = false
    /// Alerte en cours (confirmation de blocage, retour de blocage, accusé).
    @State private var alert: AcctSearchAlert?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchBar

            if model.menuOpen { resultsMenu }

            if let publication, let message = Self.publicationMessage(publication) {
                AcctSearchDirectoryStatus(message: message)
            }

            if model.selectedMemberId != nil { monProfilButton }

            if model.selectedMember != nil && model.selectedProfileState == .failed {
                AcctSearchRefreshBanner(onRetry: { model.selectedProfileAttempt += 1 })
            }

            if let selected = model.selectedMember {
                showcase(selected)
            } else if model.selectedMemberId != nil {
                AcctSearchProfileStatus(
                    failed: model.selectedProfileState == .failed,
                    onRetry: { model.selectedProfileAttempt += 1 }
                )
            }
        }
        .onAppear {
            model.ownEmail = session.profile.email
            model.authToken = session.token
        }
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
        .sheet(item: $reportTarget, onDismiss: presentReportConfirmation) { member in
            reportSheet(member)
        }
        .alert(
            alertTitle,
            isPresented: Binding(
                get: { alert != nil },
                set: { if !$0 { alert = nil } }
            ),
            presenting: alert
        ) { current in
            alertActions(current)
        } message: { current in
            Text(alertMessage(current))
        }
    }

    /// Champ de recherche et son accessoire de droite (`searchRow`).
    private var searchBar: some View {
        HStack(spacing: 9) {
            AcctSearchBar(
                query: $model.query,
                onFocus: { model.openSearchMenu() },
                onClear: { model.query = "" }
            )
            if let rowAccessory { rowAccessory }
        }
    }

    /// Menu des résultats (`peopleResults`).
    private var resultsMenu: some View {
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

    /// Bouton « Mon profil » (`backToMineButton`) : revient à son propre profil
    /// depuis la fiche d'un membre (`showOwnProfile`).
    private var monProfilButton: some View {
        Button(action: { model.showOwnProfile() }) {
            HStack(spacing: 4) {
                IonIcon(name: "chevron-back", size: 17, color: Theme.ink)
                Text("Mon profil")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            .frame(minHeight: 40)
            .padding(.horizontal, 13)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Revenir à mon profil")
        .padding(.top, 12)
    }

    /// Fiche publique du membre ouvert (`showcase`, `socialActions`).
    private func showcase(_ selected: AcctSearchMember) -> some View {
        AcctSearchMemberShowcase(
            member: selected,
            followed: model.isFollowed(selected.id),
            followsMe: model.selectedFollowsMe,
            canProposeChallenge: canProposeChallenge,
            blocking: model.blockingMemberId == selected.id,
            blockDisabled: model.blockingMemberId != nil,
            premiumMessageVisible: premiumMessageVisible,
            onToggleFollow: { model.toggleFollow(selected.id) },
            onProposeChallenge: { onProposeChallenge(selected) },
            onTogglePremiumMessage: { premiumMessageVisible.toggle() },
            onBlock: { alert = .confirmBlock(selected) },
            onReport: { reportTarget = selected }
        )
    }

    /// Feuille de signalement (`UserReportModal`) : le dépôt réussi referme la
    /// feuille, l'accusé suit à la fermeture.
    private func reportSheet(_ member: AcctSearchMember) -> some View {
        ReportUserSheet(
            memberName: member.displayName,
            onSubmit: { reason, details in
                try await ReportSafetyAPI.submitReport(
                    targetId: member.id,
                    reason: reason,
                    details: details,
                    token: session.token
                )
                reportSucceeded = true
                reportTarget = nil
            },
            onClose: { reportTarget = nil }
        )
    }

    /// Accusé de signalement (`Signalement envoyé`), présenté à la fermeture.
    private func presentReportConfirmation() {
        guard reportSucceeded else { return }
        reportSucceeded = false
        alert = .reportSent
    }

    /// Blocage confirmé (`requestBlockMember`) : bloque puis rend le compte rendu.
    @MainActor
    private func runBlock(_ member: AcctSearchMember) async {
        do {
            try await model.block(member.id, token: session.token)
            alert = .blocked(member.displayName)
        } catch {
            alert = .blockFailed(
                (error as? LocalizedError)?.errorDescription ?? "Réessaie dans un instant."
            )
        }
    }

    /// Boutons de l'alerte en cours.
    @ViewBuilder
    private func alertActions(_ current: AcctSearchAlert) -> some View {
        switch current {
        case .confirmBlock(let member):
            Button("Annuler", role: .cancel) { alert = nil }
            Button("Bloquer", role: .destructive) {
                Task { await runBlock(member) }
            }
        case .blocked, .blockFailed, .reportSent:
            Button("OK", role: .cancel) { alert = nil }
        }
    }

    private var alertTitle: String {
        switch alert {
        case .confirmBlock(let member): return "Bloquer \(member.displayName) ?"
        case .blocked: return "Compte bloqué"
        case .blockFailed: return "Blocage impossible"
        case .reportSent: return "Signalement envoyé"
        case .none: return ""
        }
    }

    private func alertMessage(_ current: AcctSearchAlert) -> String {
        switch current {
        case .confirmBlock:
            return "Ce compte et le tien ne pourront plus se trouver, se suivre, recevoir de notifications l’un de l’autre ni s’inviter à un défi. Tu pourras annuler ce choix dans Mes informations."
        case .blocked(let name):
            return "\(name) a été retiré de tes interactions sociales."
        case .blockFailed(let message):
            return message
        case .reportSent:
            return "Merci. L’équipe Duello pourra examiner ce compte sans avertir la personne concernée."
        }
    }

    /// Texte du bandeau d'état de l'annuaire (`directoryStatus` d'Expo) : `nil`
    /// quand le profil est publié, sinon le message exact de la source.
    private static func publicationMessage(
        _ publication: ReportDirectoryPublication
    ) -> String? {
        switch publication {
        case .published:
            return nil
        case .incomplete:
            return "Complète ton nom pour apparaître dans l'annuaire."
        case .rejected(let message, _):
            return "Ton profil n'est pas dans l'annuaire : \(message)"
        case .unreachable(let message):
            return "Ton profil n'est pas dans l'annuaire : \(message)"
        }
    }
}
