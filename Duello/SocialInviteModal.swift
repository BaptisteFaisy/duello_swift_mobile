//
//  SocialInviteModal.swift
//  Duello
//
//  Lot « Social » — fenêtre d'invitation à un défi privé : structure du volet,
//  en-tête et envoi de l'invitation directe.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/ChallengeInviteModal.tsx   (ChallengeInviteModal)
//    - src/utils/challengeInvites.ts             (via SocialInviteCompatibility)
//
//  L'enveloppe (fond assombri, présentation en feuille, glisser-pour-fermer)
//  reste à la charge de l'appelant, comme `PremPaywallSheet` : cette vue est le
//  contenu du volet, présenté par `.sheet`. La présence vient de
//  `SocialPresenceProvider`, à monter à la racine de l'app.
//
//  Découpé en quatre modules à responsabilité claire (règle des 500 lignes) :
//  `SocialInviteSearchResults`, `SocialInviteChapterPicker`,
//  `SocialInviteActions` — aucun type ni libellé renommé.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Fenêtre d'invitation à un défi (`ChallengeInviteModal` de
/// `src/components/ChallengeInviteModal.tsx`).
///
/// Choisir son adversaire dans l'annuaire : le défi se lance contre un profil
/// inscrit, après le choix d'au moins un chapitre commun. Les canaux de partage
/// restent réservés aux personnes qui n'ont pas encore de compte.
struct SocialChallengeInviteModal: View {
    /// Identifiant public du joueur : son propre profil n'est pas invitable.
    var selfId: String
    var track: String
    var year: String
    var specialty: String
    var subject: String
    /// Réglages du défi transmis par l'appelant ; la fenêtre ne les affiche
    /// pas, comme le composant Expo.
    var durationMinutes: Int
    /// Chapitres du volet, déjà limités à la matière du défi.
    var chapters: [SocChallengeChapter]
    /// Faux quand le compte ne peut pas encore défier (quota, session expirée).
    var canInvite: Bool
    /// Personnes déjà invitées pour ce défi, pour ne pas les inviter deux fois.
    var invitedIds: [String]
    /// Profil déjà choisi lorsqu'on arrive depuis sa fiche publique.
    var initialMember: SocSocialProfile? = nil
    /// Origine du défi choisie depuis le classement.
    var challengeKind: SocChallengeKind = .exercise
    /// Crée les invitations directes pour les amis choisis.
    var onInvite: ([SocSocialProfile], [String]) async -> Void
    /// Présent = le carré noir d'invitation d'un ami sans compte s'affiche.
    /// Comme le composant Expo, la fenêtre ne l'appelle jamais elle-même : le
    /// volet « Inviter un ami sur Duello » est monté par l'appelant.
    var onInviteNewUser: (() -> Void)? = nil
    var onClose: () -> Void

    @EnvironmentObject private var session: SessionStore
    /// Source de vérité de la présence, posée par `SocialPresenceProvider` à la
    /// racine de l'app. À défaut, l'instance partagée : personne n'est alors
    /// signalé en ligne, comme le contexte React d'Expo qui a une valeur de
    /// repli (`isOnline: () => false`).
    @ObservedObject var presence: SocPresenceStore = SocPresenceStore.shared
    @StateObject private var model = SocInviteModel()
    @State private var chaptersOpen = false
    @State private var chapterQuery = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SocInviteSheetHandle()
            SocInviteSheetHeader(title: challengeKind.title)
            searchArea
            if model.channelsOpen && onInviteNewUser != nil {
                SocInviteChannelsMenu(
                    openingChannel: model.openingChannel,
                    errorMessage: model.channelError,
                    onOpen: { channel in Task { await model.openShareChannel(channel) } }
                )
            }
            if !model.selectedMembers.isEmpty {
                selectedArea
            }
            SocInviteSendButton(
                enabled: canSendInvitation,
                sending: model.sendingInvitation,
                label: sendAccessibilityLabel,
                action: send
            )
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(Theme.surface)
        .onAppear {
            model.reset(initialMember: initialMember)
            chaptersOpen = false
            chapterQuery = ""
        }
        .onChange(of: model.query) { _ in chaptersOpen = false }
        .onChange(of: playableChapterKeys) { keys in model.pruneChapterSelection(playableKeys: keys) }
        .task(id: "\(model.query)#\(model.attempt)") {
            await model.searchAfterDebounce(token: session.token)
        }
    }

    // MARK: Recherche

    /// Barre de recherche et menu des résultats.
    private var searchArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            SocInviteSearchBar(
                query: $model.query,
                showsInviteNewUser: onInviteNewUser != nil,
                channelsOpen: $model.channelsOpen
            )
            if hasQuery {
                SocInviteResultsMenu(
                    profiles: candidates,
                    searching: model.searching,
                    errorMessage: model.errorMessage,
                    invitedIds: invitedIds,
                    selectedIds: Set(model.selectedMembers.map(\.id)),
                    onlineIds: presence.onlineIds,
                    context: compatibilityContext,
                    onRetry: { model.attempt += 1 },
                    onToggle: { member in model.toggleMember(member) }
                )
            }
        }
    }

    /// Vrai dès qu'une lettre est tapée : le menu ne s'affiche qu'à ce moment.
    private var hasQuery: Bool {
        !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Contexte de compatibilité du défi préparé.
    private var compatibilityContext: SocChallengeInvites.Context {
        SocChallengeInvites.Context(
            track: track,
            year: year,
            specialty: specialty,
            subject: subject,
            chapters: chapters,
            requiresCommonChapter: challengeKind.requiresCommonChapter
        )
    }

    /// Profils réellement invitables, les plus proches de la recherche d'abord.
    private var candidates: [SocSocialProfile] {
        SocChallengeInvites.compatibleCandidates(
            model.results,
            query: model.query,
            selfId: selfId,
            context: compatibilityContext
        )
    }

    // MARK: Sélection

    /// Bandeau des amis choisis, déclencheur et menu des chapitres.
    private var selectedArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            SocInviteSelectedStrip(
                members: model.selectedMembers,
                summary: selectedMemberNames,
                isOnline: { presence.isOnline($0) },
                onRemove: { member in model.toggleMember(member) }
            )
            SocInviteChapterTrigger(
                summary: chapterTriggerSummary,
                hasSelection: !model.selectedChapterKeys.isEmpty,
                isOpen: chaptersOpen,
                enabled: !chapters.isEmpty,
                action: { chaptersOpen.toggle() }
            )
            if chaptersOpen {
                SocInviteChaptersMenu(
                    chapters: chapters,
                    playableKeys: playableChapterKeys,
                    selectedKeys: model.selectedChapterKeys,
                    allChecked: commonAllChecked,
                    viewerYear: year,
                    query: $chapterQuery,
                    onToggleAll: { model.toggleCommonChapters(playableChapterKeys, allChecked: commonAllChecked) },
                    onToggle: { chapter in model.toggleChapter(chapter.key) }
                )
            }
        }
    }

    /// Récapitulatif des personnes invitées (`invitedNamesSummary`).
    private var selectedMemberNames: String {
        SocInviteCopy.invitedNamesSummary(model.selectedMembers.map(\.displayName))
    }

    /// Libellé du déclencheur de chapitres, mot pour mot du composant Expo.
    private var chapterTriggerSummary: String {
        let count = model.selectedChapterKeys.count
        guard count > 0 else { return "Sélectionne des chapitres…" }
        let plural = count > 1 ? "s" : ""
        return "\(count) chapitre\(plural) sélectionné\(plural)"
    }

    /// Chapitres que tout le monde partage : le défi doit rester jouable par
    /// chaque invité, quel que soit celui qui accepte.
    private var commonSelectedChapters: [SocChallengeChapter] {
        let perMember = model.selectedMembers.map { member in
            SocChallengeInvites.commonChapters(
                member,
                challengerTrack: track,
                subject: subject,
                challengerChapters: chapters
            )
        }
        guard let first = perMember.first else { return [] }
        return first.filter { chapter in
            perMember.allSatisfy { list in list.contains(where: { $0.key == chapter.key }) }
        }
    }

    /// Défi-Cours : tout chapitre choisi reste jouable par l'invité si son
    /// programme le contient, même sans être « en commun » au sens strict.
    private var playableChapterKeys: Set<String> {
        if challengeKind.requiresCommonChapter {
            return Set(commonSelectedChapters.map(\.key))
        }
        let all = model.selectedMembers.flatMap { member in
            SocChallengeInvites.commonChapters(
                member,
                challengerTrack: track,
                subject: subject,
                challengerChapters: chapters
            )
        }
        return Set(all.map(\.key))
    }

    /// « Tout cocher » est actif dès que tous les chapitres partagés le sont,
    /// même si d'autres chapitres sont cochés en plus.
    private var commonAllChecked: Bool {
        !playableChapterKeys.isEmpty
            && playableChapterKeys.allSatisfy { model.selectedChapterKeys.contains($0) }
    }

    // MARK: Envoi

    /// Vrai quand au moins un ami et un chapitre sont choisis, que le compte
    /// peut inviter et qu'aucun ami n'a déjà reçu ce défi.
    private var canSendInvitation: Bool {
        guard canInvite, !model.selectedMembers.isEmpty, !model.selectedChapterKeys.isEmpty else {
            return false
        }
        return model.selectedMembers.allSatisfy { member in !invitedIds.contains(member.id) }
    }

    /// Étiquette du bouton d'envoi, mot pour mot du composant Expo.
    private var sendAccessibilityLabel: String {
        if model.selectedMembers.isEmpty {
            return "Sélectionner au moins un joueur avant d’envoyer le défi"
        }
        if model.selectedMembers.count == 1 {
            return "Défier \(model.selectedMembers[0].displayName) dans Duello"
        }
        return "Défier \(selectedMemberNames) dans Duello"
    }

    /// Envoie les invitations directes pour les amis choisis.
    private func send() {
        Task {
            await model.sendInvitation(allowed: canSendInvitation, onInvite: onInvite)
        }
    }
}

// MARK: - En-tête du volet

/// Poignée du volet (`handleArea` / `handle`), avec l'étiquette d'accessibilité
/// « Faire descendre pour fermer » reprise d'Expo.
struct SocInviteSheetHandle: View {
    var body: some View {
        Capsule()
            .fill(Theme.border)
            .frame(width: 42, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
            .accessibilityLabel("Faire descendre pour fermer")
    }
}

/// Titre du volet : « Défi-Cours » ou « Défi-Exercice ».
struct SocInviteSheetHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 19, weight: .black))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }
}
