//
//  AcctSearchModel.swift
//  Duello
//
//  Lot « AcctSearch » (10-D) — état de la recherche d'annuaire du compte et
//  **modèle de sélection d'un membre** (`selectedMemberId`, `publicProfileId`),
//  absents du portage Swift avant ce lot.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx    (searchQuery, searchMenuOpen,
//                                        directoryProfiles,
//                                        isSearchingDirectory, directoryError,
//                                        searchAttempt, selectedMemberId,
//                                        selectedProfileState,
//                                        selectedProfileAttempt, knownProfiles,
//                                        openMember, showOwnProfile,
//                                        refreshSelectedProfile, toggleFollow)
//    - src/utils/knownSocialProfiles.ts (mergeKnownSocialProfiles)
//    - src/utils/socialVisibility.ts    (canViewFullProfile, viewedPremium)
//    - src/utils/socialApi.ts           (publicProfileId)
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// État de la recherche d'annuaire et de la fiche ouverte de l'onglet
/// « Mon compte ». Réutilisable : la vue `AcctSearchView` ne fait que le lire.
///
/// Limite assumée : le graphe social (qui me suit, qui je suis) est publié par
/// le lot « Social » ; il arrive ici par `socialDirectory`, `followerIds` et
/// `followedIds`, et `toggleFollow` ne fait que basculer l'état local — la
/// publication distante (`PUT /follows`) appartient à ce lot-là.
@MainActor
final class AcctSearchModel: ObservableObject {

    // MARK: Identité du compte

    /// Adresse du compte connecté : sert à dériver l'identifiant public.
    @Published var ownEmail = ""

    /// Identifiant public du compte connecté (`publicProfileId` de
    /// `socialApi.ts`, FNV-1a de l'e-mail normalisé). C'est l'ancre de la fiche
    /// « mon profil » : `selectedMemberId == nil` revient toujours à ce compte.
    var ownPublicProfileId: String { DuelloAPI.publicProfileId(email: ownEmail) }

    // MARK: Recherche d'annuaire

    /// Frappe tapée dans le champ de recherche.
    @Published var query = ""
    /// Menu des résultats déplié (ouvert au focus du champ).
    @Published var menuOpen = false
    /// Profils renvoyés par l'annuaire : page alphabétique ou résultats de
    /// recherche, selon que le champ est vide ou non.
    @Published private(set) var directoryProfiles: [AcctSearchMember] = []
    /// Vrai pendant l'interrogation de l'annuaire.
    @Published private(set) var searching = false
    /// Vrai pendant le chargement de la page alphabétique suivante.
    @Published private(set) var loadingMore = false
    /// Annuaire injoignable : ce n'est pas la même chose qu'un annuaire vide.
    @Published private(set) var errorMessage: String?
    /// Incrémenté par « Réessayer » : relance la même recherche.
    @Published var attempt = 0

    // MARK: Sélection d'un membre

    /// Membre dont la fiche publique est ouverte, `nil` sur son propre profil.
    /// **Trou comblé par ce lot** : aucune surface Swift ne le portait avant.
    @Published private(set) var selectedMemberId: String?
    /// État de la fiche ouverte (`idle` / `loading` / `refreshing` / `failed`).
    @Published private(set) var selectedProfileState: AcctSearchProfileState = .idle
    /// Incrémenté par « Réessayer » : force la relecture de la fiche ouverte.
    @Published var selectedProfileAttempt = 0

    // MARK: Graphe social (alimenté par le lot « Social »)

    /// Profils des abonnements et abonnés, relus dans l'annuaire.
    @Published var socialDirectory: [AcctSearchMember] = []
    /// Comptes qui me suivent.
    @Published var followerIds: [String] = []
    /// Comptes que je suis.
    @Published var followedIds: [String] = []

    // MARK: Lecture

    /// Vrai dès qu'une lettre est tapée : une seule suffit à lancer la recherche.
    var hasSearchQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Résultats classés (`searchResults`) : pertinence quand une recherche est
    /// en cours, puis ordre alphabétique stable, puis identifiant.
    ///
    /// L'annuaire a déjà retenu les profils qui correspondent : on les classe
    /// seulement, jamais on ne les refiltre avec la saisie en cours.
    var searchResults: [AcctSearchMember] {
        let typed = query
        let ranks = hasSearchQuery
        return directoryProfiles.sorted { first, second in
            if ranks {
                let firstRank = AcctSearchRanking.rank(primary: first.displayName, query: typed)
                let secondRank = AcctSearchRanking.rank(primary: second.displayName, query: typed)
                if firstRank != secondRank { return firstRank < secondRank }
            }
            let label = AcctSearchRanking.compareLabels(first.displayName, second.displayName)
            if label != .orderedSame { return label == .orderedAscending }
            return first.id < second.id
        }
    }

    /// Profils connus (`knownProfiles`) : l'annuaire des abonnés prime, ses
    /// ébauches ne doivent jamais écraser une fiche complète déjà connue.
    var knownProfiles: [AcctSearchMember] {
        var merged: [String: AcctSearchMember] = [:]
        for member in socialDirectory { merged[member.id] = member }
        for member in directoryProfiles where merged[member.id] == nil { merged[member.id] = member }
        return Array(merged.values)
    }

    /// Membre dont la fiche est ouverte. Dernière barrière côté rendu : même une
    /// réponse mise en cache par un ancien serveur ne peut plus réintroduire un
    /// compte privé (`published` force `isPublic`).
    var selectedMember: AcctSearchMember? {
        guard let selectedMemberId,
              let member = knownProfiles.first(where: { $0.id == selectedMemberId }) else {
            return nil
        }
        return member.published
    }

    /// Tous les comptes élèves sont publics (`canViewFullProfile` renvoie
    /// toujours vrai) : le cadenas « Compte privé » reste donc inatteignable,
    /// branche morte conservée pour la parité avec `AccountScreen`.
    var isMemberLocked: Bool { false }

    /// Le membre ouvert est un de mes abonnés (`selectedFollowsMe`).
    var selectedFollowsMe: Bool {
        guard let member = selectedMember else { return false }
        return followerIds.contains(member.id)
    }

    /// Vrai si le profil affiché est Premium (`viewedPremium`) : sur celui d'un
    /// autre, seul l'annuaire sait ; une absence vaut « non abonné ».
    var selectedIsPremium: Bool { selectedMember?.isPremium ?? false }

    /// Identifiant de tâche de recherche : une nouvelle frappe, une ouverture ou
    /// un « Réessayer » annulent l'attente précédente (`.task(id:)`).
    var searchTaskId: String { "\(menuOpen)|\(attempt)|\(query)" }

    /// Identifiant de tâche de la fiche ouverte : changer de membre ou
    /// « Réessayer » relance la relecture.
    var selectedProfileTaskId: String { "\(selectedMemberId ?? "")|\(selectedProfileAttempt)" }

    /// Hauteur du menu de résultats : cinq lignes visibles, le reste défile
    /// (`maxHeight: SEARCH_RESULT_HEIGHT * SEARCH_VISIBLE_RESULT_COUNT`).
    var resultsScrollHeight: CGFloat { AcctSearchConstants.resultsMaxHeight }

    // MARK: Actions

    /// Ouvre le menu au focus (`onFocus`) : une copie en cache s'affiche tout de
    /// suite, sinon une roue d'attente jusqu'à la réponse.
    func openSearchMenu() {
        menuOpen = true
        guard !hasSearchQuery else { return }
        if let cached = AcctSearchBrowseCache.shared.cached {
            directoryProfiles = cached
            errorMessage = nil
            searching = false
        } else {
            searching = true
        }
    }

    /// Interroge l'annuaire après la frappe laissée au clavier. Appelée par
    /// `.task(id: searchTaskId)` : une nouvelle frappe annule l'attente.
    func runSearch(token: String?) async {
        guard menuOpen else {
            errorMessage = nil
            searching = false
            return
        }

        let wanted = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let browsing = wanted.isEmpty
        if browsing, let cached = AcctSearchBrowseCache.shared.cached {
            directoryProfiles = cached
            errorMessage = nil
        }
        searching = true
        errorMessage = nil

        do {
            if !browsing {
                try await Task.sleep(nanoseconds: AcctSearchSettings.debounceNanoseconds)
                guard !Task.isCancelled else { return }
            }
            let found = browsing
                ? try await AcctSearchBrowseCache.shared.browse(token: token)
                : try await AcctSearchDirectory.search(wanted, token: token)
            guard !Task.isCancelled else { return }
            directoryProfiles = found
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            directoryProfiles = []
            // Un annuaire injoignable n'est pas un annuaire vide : le dire évite
            // de chercher indéfiniment quelqu'un qui est pourtant inscrit.
            errorMessage = (error as? LocalizedError)?.errorDescription ?? AcctSearchSettings.unreachable
        }
        searching = false
    }

    /// Ajoute la page alphabétique suivante, jamais pendant une recherche
    /// (`loadMoreDirectoryProfiles`).
    func loadMoreDirectory(token: String?) async {
        guard !hasSearchQuery, menuOpen, AcctSearchBrowseCache.shared.hasMore, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            let profiles = try await AcctSearchBrowseCache.shared.browseMore(token: token)
            guard !Task.isCancelled, !hasSearchQuery, menuOpen else { return }
            directoryProfiles = profiles
            errorMessage = nil
        } catch {
            // Page suivante indisponible : la liste déjà affichée reste en place.
        }
    }

    /// Ouvre la fiche d'un membre et referme le menu (`openMember`).
    func openMember(_ memberId: String) {
        menuOpen = false
        selectedProfileState = .loading
        selectedMemberId = memberId
    }

    /// Revient à son propre profil (`showOwnProfile`).
    func showOwnProfile() {
        selectedProfileState = .idle
        selectedMemberId = nil
    }

    /// Relit la fiche ouverte dans l'annuaire (`refreshSelectedProfile`) : la
    /// première lecture montre un chargement, les suivantes un rafraîchissement
    /// discret. Une fiche introuvable passe en échec, sans jamais retomber sur
    /// les statistiques du compte connecté.
    func refreshSelectedProfile(token: String?) async {
        guard let memberId = selectedMemberId else {
            selectedProfileState = .idle
            return
        }
        let initial = selectedMember == nil
        selectedProfileState = initial ? .loading : .refreshing

        do {
            let members = try await AcctSearchDirectory.profilesByIds([memberId], token: token)
            guard !Task.isCancelled else { return }
            if let member = members.first {
                directoryProfiles = [member] + directoryProfiles.filter { $0.id != member.id }
                selectedProfileState = .idle
            } else {
                selectedProfileState = .failed
            }
        } catch {
            guard !Task.isCancelled else { return }
            selectedProfileState = .failed
        }
    }

    /// Suit ou ne suit plus un membre (`toggleFollow`). L'état local est
    /// retourné tout de suite ; la publication distante appartient au lot
    /// « Social ».
    func toggleFollow(_ memberId: String) {
        if let index = followedIds.firstIndex(of: memberId) {
            followedIds.remove(at: index)
        } else {
            followedIds.append(memberId)
        }
    }

    /// Vrai si le membre est déjà suivi (`followedIds.includes`).
    func isFollowed(_ memberId: String) -> Bool {
        followedIds.contains(memberId)
    }
}
