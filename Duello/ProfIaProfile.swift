//
//  ProfIaProfile.swift
//  Duello
//
//  Port de `src/utils/profIaProfile.ts` (RN) — fiche locale du « Prof IA » dans
//  l'annuaire du compte.
//
//  L'identifiant `prof-ia` n'existe jamais côté serveur : les membres réels
//  portent tous un `member-<hash>`. La fiche est donc servie en local (mêmes
//  champs qu'un membre, performances à zéro) et fusionnée aux résultats de
//  l'annuaire quand la saisie la désigne, sans jamais la proposer comme
//  adversaire de défi (l'invitation partage la même recherche).
//
//  Le type porté est `AcctSearchMember` (lot « annuaire »), l'équivalent Swift
//  du `SocialProfile` de la source : identité (`SocSocialProfile`) + classe,
//  prépa et XP publiés.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

// MARK: - Identité

/// `PROF_IA_PROFILE_ID` : identifiant local du prof IA, inconnu de l'annuaire.
let PROF_IA_PROFILE_ID = "prof-ia"

/// `PROF_IA_DISPLAY_NAME` : nom affiché partout où un pseudo est attendu.
let PROF_IA_DISPLAY_NAME = "Prof IA"

/// `PROF_IA_ROLE_LABEL` : rôle affiché à la place de la filière et de l'année.
let PROF_IA_ROLE_LABEL = "Professeur IA"

/// `PROF_IA_SCOPE_LABEL` : périmètre affiché sous le rôle.
let PROF_IA_SCOPE_LABEL = "Maths · Toutes filières"

/// `isProfIaProfileId` : vrai pour l'identifiant local du prof IA seulement.
func isProfIaProfileId(_ id: String?) -> Bool {
    id == PROF_IA_PROFILE_ID
}

// MARK: - Fiche locale

/// `PROF_IA_SOCIAL_PROFILE` : fiche publique du prof IA, servie en local.
///
/// Mêmes champs qu'un membre, sans `details` (Elo et XP à zéro, comme un compte
/// tout juste créé). La filière et l'année ne sont que des bouche-trous exigés
/// par le type — la fiche affiche le rôle à leur place.
let PROF_IA_SOCIAL_PROFILE = AcctSearchMember(
    profile: SocSocialProfile(
        id: PROF_IA_PROFILE_ID,
        displayName: PROF_IA_DISPLAY_NAME,
        track: "ECG",
        year: "1re année",
        photoUri: nil,
        isPublic: true,
        isPremium: false,
        specialty: "",
        elo: nil
    ),
    className: "",
    prepName: "",
    xp: 0
)

// MARK: - Recherche

/// `searchMatchesProfIa` : vrai quand la saisie désigne le prof IA — préfixe de
/// « prof ia » (espaces ignorés, casse et accents indifférents) ou « ia » seul.
/// Une seule lettre suffit, comme pour les initiales des membres.
func searchMatchesProfIa(_ query: String) -> Bool {
    let compact = query
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        .filter { $0.isASCII && $0.isLetter }
    guard !compact.isEmpty else { return false }
    return "profia".hasPrefix(compact) || compact == "ia"
}

/// `withProfIaSearchResults` : ajoute la fiche du prof IA en tête des résultats
/// serveur quand la saisie le désigne, sans dépasser `maxResults` et sans
/// doublon si l'annuaire le renvoyait un jour lui-même.
func withProfIaSearchResults(
    _ query: String,
    serverProfiles: [AcctSearchMember],
    maxResults: Int
) -> [AcctSearchMember] {
    guard searchMatchesProfIa(query) else {
        return Array(serverProfiles.prefix(maxResults))
    }
    let deduped = serverProfiles.filter { !isProfIaProfileId($0.id) }
    return Array(([PROF_IA_SOCIAL_PROFILE] + deduped).prefix(maxResults))
}

/// `mergeProfIaByIds` : recompose les profils demandés dans l'ordre des
/// identifiants — le prof IA est servi en local, les autres sont repris tels
/// que l'annuaire les a renvoyés, les identifiants inconnus sont ignorés.
func mergeProfIaByIds(
    _ requestedIds: [String],
    serverProfiles: [AcctSearchMember]
) -> [AcctSearchMember] {
    guard requestedIds.contains(where: { isProfIaProfileId($0) }) else {
        return serverProfiles
    }
    var byId: [String: AcctSearchMember] = [:]
    for profile in serverProfiles { byId[profile.id] = profile }
    var merged: [AcctSearchMember] = []
    for id in requestedIds {
        if isProfIaProfileId(id) {
            if !merged.contains(where: { isProfIaProfileId($0.id) }) {
                merged.append(PROF_IA_SOCIAL_PROFILE)
            }
            continue
        }
        if let found = byId[id] { merged.append(found) }
    }
    return merged
}

/// `withProfIaKnownProfile` : ajoute la fiche du prof IA aux profils connus si
/// elle n'y figure pas déjà — la fiche reste ouvrable même sans passage
/// préalable par la recherche.
func withProfIaKnownProfile(_ profiles: [AcctSearchMember]) -> [AcctSearchMember] {
    if profiles.contains(where: { isProfIaProfileId($0.id) }) {
        return profiles
    }
    return profiles + [PROF_IA_SOCIAL_PROFILE]
}
