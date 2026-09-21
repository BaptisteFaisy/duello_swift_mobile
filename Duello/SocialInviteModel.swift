//
//  SocialInviteModel.swift
//  Duello
//
//  Lot « Social » — état de la fenêtre d'invitation à un défi : recherche dans
//  l'annuaire, sélection des amis et des chapitres, envoi et partage.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/ChallengeInviteModal.tsx   (état et effets du volet)
//    - src/utils/socialApi.ts                    (searchSocialProfiles,
//                                                 MAX_SEARCH_CANDIDATES,
//                                                 MAX_SEARCH_PROFILES)
//    - src/utils/challengeInvites.ts             (MAX_INVITE_RESULTS)
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI
import UIKit

// MARK: - Annuaire

/// Recherche d'adversaires dans l'annuaire (`searchSocialProfiles` de
/// `utils/socialApi.ts`).
///
/// `DuelloAPI` ne porte pas cet endpoint : le helper reste donc local à ce lot,
/// comme le prévoit le brief de portage.
enum SocInviteDirectory {
    /// Résultats montrés d'un coup (`MAX_INVITE_RESULTS`) : au-delà, on affine
    /// la recherche.
    static let maxInviteResults = 12

    /// Plafond de candidats ramenés du serveur avant tout filtrage local
    /// (`MAX_SEARCH_CANDIDATES`). Le serveur plafonne lui-même sa réponse à
    /// 20 profils : rester sous ce cap.
    static let searchCandidatePool = 12

    /// `GET /profiles?q=…` — le serveur classe par pertinence, on ne garde que
    /// les premiers. Un profil renvoyé par la recherche est toujours public.
    static func search(
        _ query: String,
        token: String?,
        limit: Int = SocInviteDirectory.searchCandidatePool
    ) async throws -> [SocSocialProfile] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Une seule lettre suffit pour chercher : elle est traitée comme une initiale.
        guard !normalized.isEmpty else { return [] }

        let data = try await DuelloAPI.request(
            "/profiles",
            method: "GET",
            token: token,
            query: [URLQueryItem(name: "q", value: normalized)]
        )
        let body = try DuelloAPI.decoder.decode(SocProfileSearchResponse.self, from: data)
        // Expo force `isPublic: true` sur chaque résultat de recherche : un
        // profil renvoyé par l'annuaire est publié, le cadenas ne s'affiche
        // donc jamais sur cette liste.
        let published = body.profiles.map { profile -> SocSocialProfile in
            var copy = profile
            copy.isPublic = true
            return copy
        }
        return Array(published.prefix(max(0, limit)))
    }
}

/// Enveloppe `{ "profiles": […] }` de la recherche d'annuaire.
private struct SocProfileSearchResponse: Decodable {
    let profiles: [SocSocialProfile]

    enum CodingKeys: String, CodingKey {
        case profiles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profiles = (try? container.decodeIfPresent([SocSocialProfile].self, forKey: .profiles)) ?? []
    }
}

// MARK: - État du volet

/// État de la fenêtre d'invitation (`ChallengeInviteModal.tsx`).
final class SocInviteModel: ObservableObject {
    // MARK: Recherche

    /// Frappe tapée dans le champ « Invite un ou plusieurs amis… ».
    @Published var query = ""
    /// Profils renvoyés par l'annuaire, avant filtrage de compatibilité.
    @Published private(set) var results: [SocSocialProfile] = []
    /// Vrai pendant l'interrogation de l'annuaire.
    @Published private(set) var searching = false
    /// Annuaire injoignable : ce n'est pas la même chose qu'un annuaire vide.
    @Published private(set) var errorMessage: String?
    /// Vrai dès qu'une recherche a été lancée, pour distinguer « rien tapé ».
    @Published private(set) var hasSearched = false
    /// Incrémenté par « Réessayer » : relance la même recherche.
    @Published var attempt = 0

    // MARK: Sélection

    /// Amis choisis pour ce défi, dans l'ordre d'ajout.
    @Published var selectedMembers: [SocSocialProfile] = []
    /// Clés `<année>:<matière>:<chapitre>` cochées dans le volet.
    @Published var selectedChapterKeys: Set<String> = []

    // MARK: Envoi et partage

    /// Vrai pendant l'envoi des invitations directes.
    @Published private(set) var sendingInvitation = false
    /// Menu des canaux de partage déplié.
    @Published var channelsOpen = false
    /// Canal en cours d'ouverture : les autres lignes patientent.
    @Published private(set) var openingChannel: SocShareChannel?
    /// Échec du partage : le message reste copié quand Instagram est visé.
    @Published private(set) var channelError: String?

    /// Frappe laissée au clavier avant d'interroger l'annuaire
    /// (`SEARCH_DEBOUNCE_MS` de `ChallengeInviteModal.tsx`).
    static let searchDebounceNanoseconds: UInt64 = 140_000_000

    // MARK: Ouverture

    /// `useEffect` d'ouverture : chaque ouverture repart d'un champ vide, les
    /// résultats de la fois d'avant ne concernent pas le défi préparé.
    func reset(initialMember: SocSocialProfile?) {
        query = ""
        results = []
        errorMessage = nil
        hasSearched = false
        attempt = 0
        searching = false
        selectedMembers = initialMember.map { [$0] } ?? []
        selectedChapterKeys = []
        sendingInvitation = false
        channelsOpen = false
        openingChannel = nil
        channelError = nil
    }

    // MARK: Recherche

    /// Interroge l'annuaire après la frappe laissée au clavier. Appelée par
    /// `.task(id:)` : une nouvelle frappe annule l'attente précédente.
    @MainActor
    func searchAfterDebounce(token: String?) async {
        let wanted = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else {
            results = []
            errorMessage = nil
            hasSearched = false
            searching = false
            return
        }

        searching = true
        errorMessage = nil
        do {
            try await Task.sleep(nanoseconds: Self.searchDebounceNanoseconds)
        } catch {
            return  // frappe suivante : l'attente est annulée
        }
        guard !Task.isCancelled else { return }

        do {
            let found = try await SocInviteDirectory.search(wanted, token: token)
            guard !Task.isCancelled else { return }
            results = found
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? SocInviteCopy.directoryUnreachable
        }
        hasSearched = true
        searching = false
    }

    // MARK: Sélection

    /// Sélectionne ou retire un ami, sans perdre les autres ni les chapitres.
    /// Les résultats restent affichés : on enchaîne plusieurs amis d'affilée,
    /// puis on efface la recherche pour revenir aux réglages du défi.
    func toggleMember(_ member: SocSocialProfile) {
        if let index = selectedMembers.firstIndex(where: { $0.id == member.id }) {
            selectedMembers.remove(at: index)
        } else {
            selectedMembers.append(member)
        }
    }

    /// Coche ou décoche un chapitre.
    func toggleChapter(_ chapterKey: String) {
        if selectedChapterKeys.contains(chapterKey) {
            selectedChapterKeys.remove(chapterKey)
        } else {
            selectedChapterKeys.insert(chapterKey)
        }
    }

    /// Coche (ou décoche) tous les chapitres communs au joueur et à l'ami.
    func toggleCommonChapters(_ playableKeys: Set<String>, allChecked: Bool) {
        if allChecked {
            selectedChapterKeys.subtract(playableKeys)
        } else {
            selectedChapterKeys.formUnion(playableKeys)
        }
    }

    /// L'ajout ou le retrait d'un ami restreint l'intersection : les chapitres
    /// choisis doivent rester jouables par chaque invité, quel que soit celui
    /// qui accepte.
    func pruneChapterSelection(playableKeys: Set<String>) {
        selectedChapterKeys = selectedChapterKeys.intersection(playableKeys)
    }

    // MARK: Envoi

    /// Envoie les invitations directes avec les réglages choisis.
    ///
    /// `allowed` est calculé par la vue (`canSendInvitation`), qui seule
    /// connaît le quota du compte et les amis déjà invités.
    @MainActor
    func sendInvitation(
        allowed: Bool,
        onInvite: ([SocSocialProfile], [String]) async -> Void
    ) async {
        guard allowed, !sendingInvitation else { return }
        let members = selectedMembers
        let chapterKeys = Array(selectedChapterKeys)
        sendingInvitation = true
        await onInvite(members, chapterKeys)
        sendingInvitation = false
    }

    // MARK: Partage

    /// Ouvre le canal choisi pour un ami qui n'a pas encore de compte : le
    /// message d'invitation est celui du volet dédié, Instagram le fait copier.
    @MainActor
    func openShareChannel(_ channel: SocShareChannel) async {
        guard openingChannel == nil else { return }
        openingChannel = channel
        channelError = nil

        let message = SocInviteCopy.inviteMessage()
        if channel != .whatsapp {
            // `sms:` ne peut pas préremplir le corps : le message est copié
            // avant l'ouverture, comme Instagram côté Expo.
            UIPasteboard.general.string = message
        }

        var opened = false
        if let url = channel.url(message: message) {
            opened = await withCheckedContinuation { continuation in
                UIApplication.shared.open(url, options: [:]) { success in
                    continuation.resume(returning: success)
                }
            }
        }

        openingChannel = nil
        if !opened { channelError = channel.failureMessage }
    }
}
